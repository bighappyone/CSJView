import Foundation
import UIKit
import BUAdSDK
// MARK: - 广告类型枚举
enum AdType: String {
    case reward = "激励视频"
    case interstitial = "插屏"
    case splash = "开屏"
}

// MARK: - 缓存的广告项
class CachedAd {
    let type: AdType
    let slotId: String
    var ad: Any?
    let loadTime: Date
    
    init(type: AdType, slotId: String, ad: Any) {
        self.type = type
        self.slotId = slotId
        self.ad = ad
        self.loadTime = Date()
    }
}

// MARK: - 广告管理器
@MainActor
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    @Published var isSDKInitialized = false
    @Published var isLoadingAds = false
    @Published var cachePool: [CachedAd] = []
    
    private var isInitializing = false  // 防止并发初始化
    private var configManager = AdConfigManager.shared
    
    // 当前加载状态
    private var currentAdType: AdType = .reward
    private var currentTypeIndex: Int = 0
    private var failureCount: Int = 0
    
    // 广告代理保持引用
    private var rewardDelegates: [String: RewardAdDelegate] = [:]
    private var interstitialDelegates: [String: InterstitialAdDelegate] = [:]
    private var splashDelegates: [String: SplashAdDelegate] = [:]
    
    // 广告对象保持引用（加载中的）
    private var loadingRewardAds: [String: BUNativeExpressRewardedVideoAd] = [:]
    private var loadingInterstitialAds: [String: BUNativeExpressFullscreenVideoAd] = [:]
    private var loadingSplashAds: [String: BUSplashAd] = [:]
    
    private override init() {
        super.init()
    }
    
    // MARK: - 初始化SDK
    func initializeSDK() {
        // 检查是否已经初始化
        if isSDKInitialized {
            debugPrint("⚠️ [SDK初始化] SDK已经初始化，跳过重复初始化")
            return
        }
        
        // 检查是否正在初始化中
        if isInitializing {
            debugPrint("⚠️ [SDK初始化] SDK正在初始化中，跳过重复调用")
            return
        }
        
        isInitializing = true
        debugPrint("🔧 [SDK初始化] 开始初始化穿山甲SDK")
        guard let config = configManager.config else {
            debugPrint("❌ [SDK初始化] 配置未加载")
            return
        }
        
        guard config.isEnable else {
            debugPrint("⚠️ [SDK初始化] 广告未启用，跳过初始化")
            return
        }
        
        // 详细的初始化参数日志
        debugPrint("📋 [SDK初始化] 配置参数:")
        debugPrint("   App ID: \(config.appId) \(Bundle.main.bundleIdentifier)")
        debugPrint("   Use Mediation: false")
        debugPrint("   Debug Log: true")
        
        // 检查SDK当前状态（如果可用）
        debugPrint("📦 [SDK初始化] SDK版本: \(BUAdSDKManager.sdkVersion)")
        
        let configuration = BUAdSDKConfiguration()
        configuration.appID = config.appId
        configuration.useMediation = false
        configuration.debugLog = true
        
        // 记录初始化开始时间
        let startTime = Date()
        debugPrint("⏱️ [SDK初始化] 开始时间: \(startTime)")
        
        // 注意：SDK初始化是异步的，回调会在后台线程执行
        // 如果调试器在SDK内部停止，这是正常的（SDK是二进制框架，没有源代码）
        // 建议：在回调的第一行设置断点，而不是在SDK内部
        BUAdSDKManager.start(asyncCompletionHandler: { [weak self] success, error in
            // 🔍 调试提示：在这里设置断点可以检查初始化结果
            // 不要尝试在SDK内部设置断点，因为SDK是二进制框架
            let elapsedTime = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async {
                self?.isInitializing = false  // 重置初始化标志
                
                if success {
                    debugPrint("✅ [SDK初始化] 初始化成功 (耗时: \(String(format: "%.2f", elapsedTime))秒)")
                    self?.isSDKInitialized = true
                    
                    // 记录SDK状态
                    debugPrint("📊 [SDK初始化] SDK状态检查:")
                    debugPrint("   isSDKInitialized: \(self?.isSDKInitialized ?? false)")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        // 开始加载广告到缓存池（并行）
                        self?.startLoadingAdsToCache()
                    }
                } else {
                    debugPrint("❌ [SDK初始化] 初始化失败 (耗时: \(String(format: "%.2f", elapsedTime))秒)")
                    if let error = error {
                        let nsError = error as NSError
                        debugPrint("   Error Domain: \(nsError.domain)")
                        debugPrint("   Error Code: \(nsError.code)")
                        debugPrint("   Error Description: \(nsError.localizedDescription)")
                        if !nsError.userInfo.isEmpty {
                            debugPrint("   User Info: \(nsError.userInfo)")
                        }
                        
                        // 如果是BUAdError，打印更多信息
                        if let buError = error as? BUAdError {
                            debugPrint("   BUAdError Code: \(buError.errorCode.rawValue)")
                        }
                    } else {
                        debugPrint("   未知错误")
                    }
                }
            }
        })
    }
    
    // MARK: - 开始加载广告到缓存池
    func startLoadingAdsToCache() {
        guard let config = configManager.config else { return }
        guard isSDKInitialized else { return }
        
        isLoadingAds = true
        currentAdType = .reward
        currentTypeIndex = 0
        failureCount = 0
        
        debugPrint("🚀 开始填充广告缓存池，目标数量: \(config.cacheLength)")
        loadNextAd()
    }
    
    // MARK: - 补充缓存池（保持加载顺序）
    func refillCache() {
        guard let config = configManager.config else { return }
        
        if cachePool.count < config.cacheLength && !isLoadingAds {
            debugPrint("🔄 缓存池不足，继续加载广告")
            loadNextAd()
        }
    }
    
    // MARK: - 加载下一个广告
    private func loadNextAd() {
        guard let config = configManager.config else { return }
        
        // 检查缓存池是否已满
        if cachePool.count >= config.cacheLength {
            debugPrint("✅ 广告缓存池已满，当前数量: \(cachePool.count)")
            isLoadingAds = false
            printCacheStatus()
            return
        }
        
        // 根据当前类型加载广告
        switch currentAdType {
        case .reward:
            loadRewardAd()
        case .interstitial:
            loadInterstitialAd()
        case .splash:
            loadSplashAd()
        }
    }
    
    // MARK: - 加载激励视频广告
    private func loadRewardAd() {
        guard let config = configManager.config else { return }
        guard currentTypeIndex < config.rewardSlotId.count else {
            switchToNextAdType()
            return
        }
        
        let slotId = config.rewardSlotId[currentTypeIndex]
        debugPrint("📱 开始加载激励视频广告 [\(currentTypeIndex + 1)/\(config.rewardSlotId.count)]: \(slotId)")
        
        let rewardedVideoModel = BURewardedVideoModel()
        let rewardedVideoAd = BUNativeExpressRewardedVideoAd(
            slotID: slotId,
            rewardedVideoModel: rewardedVideoModel
        )
        
        let delegate = RewardAdDelegate(
            onAdDidLoad: { [weak self] ad in
                self?.handleRewardAdLoadSuccess(ad: ad, slotId: slotId)
            },
            onAdDidFail: { [weak self] error in
                self?.handleAdLoadFailure(type: .reward, slotId: slotId, error: error)
            },
            onAdDidClick: {},
            onAdDidClose: {},
            onAdDidShow: {},
            onRewardVerify: { _ in }
        )
        
        rewardDelegates[slotId] = delegate
        loadingRewardAds[slotId] = rewardedVideoAd
        rewardedVideoAd.delegate = delegate
        rewardedVideoAd.loadData()
    }
    
    private func handleRewardAdLoadSuccess(ad: BUNativeExpressRewardedVideoAd, slotId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            debugPrint("✅ 激励视频广告加载成功: \(slotId)")
            
            // 添加到缓存池
            let cachedAd = CachedAd(type: .reward, slotId: slotId, ad: ad)
            self.cachePool.append(cachedAd)
            self.logCacheSnapshot(context: "激励广告成功 \(slotId)")
            
            // 清空失败次数
            self.failureCount = 0
            
            // 移动到下一个广告位
            self.moveToNextSlot()
            
            // 继续加载
            self.loadNextAd()
        }
    }
    
    // MARK: - 加载插屏广告
    private func loadInterstitialAd() {
        guard let config = configManager.config else { return }
        guard currentTypeIndex < config.interstitialSlotId.count else {
            switchToNextAdType()
            return
        }
        
        let slotId = config.interstitialSlotId[currentTypeIndex]
        debugPrint("📱 开始加载插屏广告 [\(currentTypeIndex + 1)/\(config.interstitialSlotId.count)]: \(slotId)")
        
        let interstitialVideoAd = BUNativeExpressFullscreenVideoAd(slotID: slotId)
        
        let delegate = InterstitialAdDelegate(
            onAdDidLoad: { [weak self] ad in
                self?.handleInterstitialAdLoadSuccess(ad: ad, slotId: slotId)
            },
            onAdDidFail: { [weak self] error in
                self?.handleAdLoadFailure(type: .interstitial, slotId: slotId, error: error)
            },
            onAdDidClick: {},
            onAdDidClose: {},
            onAdDidShow: {},
            onVideoDidPlayFinish: {}
        )
        
        interstitialDelegates[slotId] = delegate
        loadingInterstitialAds[slotId] = interstitialVideoAd
        interstitialVideoAd.delegate = delegate
        interstitialVideoAd.loadData()
    }
    
    private func handleInterstitialAdLoadSuccess(ad: BUNativeExpressFullscreenVideoAd, slotId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            debugPrint("✅ 插屏广告加载成功: \(slotId)")
            
            // 添加到缓存池
            let cachedAd = CachedAd(type: .interstitial, slotId: slotId, ad: ad)
            self.cachePool.append(cachedAd)
            self.logCacheSnapshot(context: "插屏广告成功 \(slotId)")
            
            // 清空失败次数
            self.failureCount = 0
            
            // 移动到下一个广告位
            self.moveToNextSlot()
            
            // 继续加载
            self.loadNextAd()
        }
    }
    
    // MARK: - 加载开屏广告
    private func loadSplashAd() {
        guard let config = configManager.config else { return }
        guard currentTypeIndex < config.splashSlotId.count else {
            switchToNextAdType()
            return
        }
        
        let slotId = config.splashSlotId[currentTypeIndex]
        debugPrint("📱 开始加载开屏广告 [\(currentTypeIndex + 1)/\(config.splashSlotId.count)]: \(slotId)")
        
        let screenSize = UIScreen.main.bounds.size
        let splashAd = BUSplashAd(slotID: slotId, adSize: screenSize)
        
        let delegate = SplashAdDelegate(
            onLoadSuccess: { [weak self] ad in
                self?.handleSplashAdLoadSuccess(ad: ad, slotId: slotId)
            },
            onLoadFail: { [weak self] error in
                self?.handleAdLoadFailure(type: .splash, slotId: slotId, error: error)
            },
            onDidClick: {},
            onDidClose: { _ in },
            onDidShow: {}
        )
        
        splashDelegates[slotId] = delegate
        loadingSplashAds[slotId] = splashAd
        splashAd.delegate = delegate
        splashAd.loadData()
    }
    
    private func handleSplashAdLoadSuccess(ad: BUSplashAd, slotId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            debugPrint("✅ 开屏广告加载成功: \(slotId)")
            
            // 添加到缓存池
            let cachedAd = CachedAd(type: .splash, slotId: slotId, ad: ad)
            self.cachePool.append(cachedAd)
            self.logCacheSnapshot(context: "开屏广告成功 \(slotId)")
            
            // 清空失败次数
            self.failureCount = 0
            
            // 移动到下一个广告位
            self.moveToNextSlot()
            
            // 继续加载
            self.loadNextAd()
        }
    }
    
    // MARK: - 处理广告加载失败
    private func handleAdLoadFailure(type: AdType, slotId: String, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            debugPrint("❌ \(type.rawValue)广告加载失败 [\(self.currentTypeIndex + 1)]: \(slotId), 错误: \(error?.localizedDescription ?? "未知")")
            self.logAdFailureDetail(type: type, slotId: slotId, error: error)
            
            // 增加失败次数
            self.failureCount += 1
            
            // 获取当前类型的广告位数组长度
            let currentArrayLength = self.getCurrentTypeArrayLength()
            
            if self.failureCount >= currentArrayLength {
                // 失败次数达到数组长度，清空失败次数并切换到下一个类型
                debugPrint("⚠️ \(type.rawValue)所有广告位都失败了，切换到下一个广告类型")
                self.failureCount = 0
                self.switchToNextAdType()
            } else {
                // 继续尝试下一个广告位
                self.currentTypeIndex += 1
            }
            
            // 继续加载
            self.loadNextAd()
        }
    }
    
    // MARK: - 移动到下一个广告位
    private func moveToNextSlot() {
        let currentArrayLength = getCurrentTypeArrayLength()
        currentTypeIndex += 1
        
        // 如果当前类型的广告位已经全部遍历完，切换到下一个类型
        if currentTypeIndex >= currentArrayLength {
            if currentAdType == .reward {
                currentTypeIndex = 0
            } else {
                switchToNextAdType()
            }
        }
    }
    
    // MARK: - 切换到下一个广告类型
    private func switchToNextAdType() {
        currentTypeIndex = 0
        failureCount = 0
        
        switch currentAdType {
        case .reward:
            currentAdType = .interstitial
            debugPrint("🔄 切换到插屏广告")
        case .interstitial:
            currentAdType = .splash
            debugPrint("🔄 切换到开屏广告")
        case .splash:
            currentAdType = .reward
            debugPrint("🔄 切换到激励视频广告")
        }
    }
    
    // MARK: - 获取当前类型的广告位数组长度
    private func getCurrentTypeArrayLength() -> Int {
        guard let config = configManager.config else { return 0 }
        
        switch currentAdType {
        case .reward:
            return config.rewardSlotId.count
        case .interstitial:
            return config.interstitialSlotId.count
        case .splash:
            return config.splashSlotId.count
        }
    }
    
    // MARK: - 打印缓存状态
    func printCacheStatus() {
        debugPrint("📊 广告缓存池状态:")
        debugPrint("   总数: \(cachePool.count)")
        
        let rewardCount = cachePool.filter { $0.type == .reward }.count
        let interstitialCount = cachePool.filter { $0.type == .interstitial }.count
        let splashCount = cachePool.filter { $0.type == .splash }.count
        
        debugPrint("   激励视频: \(rewardCount)")
        debugPrint("   插屏广告: \(interstitialCount)")
        debugPrint("   开屏广告: \(splashCount)")
        
        for (index, cachedAd) in cachePool.enumerated() {
            debugPrint("   [\(index + 1)] \(cachedAd.type.rawValue) - \(cachedAd.slotId)")
        }
    }
    
    // MARK: - 从缓存池获取广告
    func getAdFromCache() -> CachedAd? {
        guard !cachePool.isEmpty else {
            debugPrint("⚠️ 缓存池为空")
            return nil
        }
        
        let ad = cachePool.removeFirst()
        debugPrint("📤 从缓存池取出广告: \(ad.type.rawValue) - \(ad.slotId)")
        
        Task { @MainActor in
            ThirdAnalytics.event("GetAd.\(String(describing: ad.type))")
        }
        // 取出一个后，继续加载补充缓存池（保持原有的加载顺序）
        refillCache()
        
        return ad
    }
    
    // MARK: - 清理缓存池
    func clearCache() {
        cachePool.removeAll()
        rewardDelegates.removeAll()
        interstitialDelegates.removeAll()
        splashDelegates.removeAll()
        loadingRewardAds.removeAll()
        loadingInterstitialAds.removeAll()
        loadingSplashAds.removeAll()
        debugPrint("🗑️ 广告缓存池已清空")
    }
    
    private func logCacheSnapshot(context: String) {
        let rewardCount = cachePool.filter { $0.type == .reward }.count
        let interstitialCount = cachePool.filter { $0.type == .interstitial }.count
        let splashCount = cachePool.filter { $0.type == .splash }.count
        debugPrint("📦 缓存快照 [\(context)]: 总数 \(cachePool.count) | 激励 \(rewardCount) | 插屏 \(interstitialCount) | 开屏 \(splashCount)")
    }
    
    // MARK: - 失败详情日志
    private func logAdFailureDetail(type: AdType, slotId: String, error: Error?) {
        guard let error = error else {
            debugPrint("ℹ️ \(type.rawValue)广告 \(slotId) 无额外错误信息")
            return
        }
        
        let nsError = error as NSError
        var components: [String] = []
        components.append("domain=\(nsError.domain)")
        components.append("code=\(nsError.code)")
        
        if let buError = error as? BUAdError {
            components.append("buErrorCode=\(buError.errorCode.rawValue)")
        }
        
        if !nsError.userInfo.isEmpty {
            let userInfoDesc = nsError.userInfo.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            components.append("userInfo={\(userInfoDesc)}")
        }
        
        debugPrint("📄 \(type.rawValue)广告失败详情 [\(slotId)]: " + components.joined(separator: " | "))
    }
}

// MARK: - 激励广告代理类
class RewardAdDelegate: NSObject, BUNativeExpressRewardedVideoAdDelegate {
    private let onAdDidLoad: (BUNativeExpressRewardedVideoAd) -> Void
    private let onAdDidFail: (Error?) -> Void
    private let onAdDidClick: () -> Void
    private let onAdDidClose: () -> Void
    private let onAdDidShow: () -> Void
    private let onRewardVerify: (BUNativeExpressRewardedVideoAd) -> Void
    
    init(
        onAdDidLoad: @escaping (BUNativeExpressRewardedVideoAd) -> Void,
        onAdDidFail: @escaping (Error?) -> Void,
        onAdDidClick: @escaping () -> Void,
        onAdDidClose: @escaping () -> Void,
        onAdDidShow: @escaping () -> Void,
        onRewardVerify: @escaping (BUNativeExpressRewardedVideoAd) -> Void
    ) {
        self.onAdDidLoad = onAdDidLoad
        self.onAdDidFail = onAdDidFail
        self.onAdDidClick = onAdDidClick
        self.onAdDidClose = onAdDidClose
        self.onAdDidShow = onAdDidShow
        self.onRewardVerify = onRewardVerify
        super.init()
    }
    
    func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Reward.LoadSucceed")
        }
        onAdDidLoad(rewardedVideoAd)
    }
    
    func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        Task { @MainActor in
            ThirdAnalytics.event("Reward.LoadFail")
        }
        onAdDidFail(error)
    }
    func nativeExpressRewardedVideoAdDidClick(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Reward.Click")
        }
        onAdDidClick()
    }
    
    func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Reward.Close")
        }
        onAdDidClose()
    }
    
    func nativeExpressRewardedVideoAdWillVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Reward.Show")
        }
        onAdDidShow()
    }
    func nativeExpressRewardedVideoAdDidVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("激励广告已展示")
        Task { @MainActor in
            ThirdAnalytics.event("Reward.Show")
        }
        onAdDidShow()
    }
    
    func nativeExpressRewardedVideoAdDidPlayFinish(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        debugPrint("激励广告播放完成，错误：\(error?.localizedDescription ?? "无")")
        Task { @MainActor in
            ThirdAnalytics.event("Reward.PlayFinish")
        }
    }
    
    func nativeExpressRewardedVideoAdServerRewardDidSucceed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, verify: Bool) {
        Task { @MainActor in
            ThirdAnalytics.event("Reward.Server.Succeed")
        }
        debugPrint("🎉 激励广告服务器验证成功！")
        onRewardVerify(rewardedVideoAd)
    }
    
    func nativeExpressRewardedVideoAdServerRewardDidFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Reward.Server.Fail")
        }
        debugPrint("❌ 激励广告服务器验证失败")
    }
}

// MARK: - 插屏广告代理类
class InterstitialAdDelegate: NSObject, BUNativeExpressFullscreenVideoAdDelegate {
    private let onAdDidLoad: (BUNativeExpressFullscreenVideoAd) -> Void
    private let onAdDidFail: (Error?) -> Void
    private let onAdDidClick: () -> Void
    private let onAdDidClose: () -> Void
    private let onAdDidShow: () -> Void
    private let onVideoDidPlayFinish: () -> Void
    
    init(
        onAdDidLoad: @escaping (BUNativeExpressFullscreenVideoAd) -> Void,
        onAdDidFail: @escaping (Error?) -> Void,
        onAdDidClick: @escaping () -> Void,
        onAdDidClose: @escaping () -> Void,
        onAdDidShow: @escaping () -> Void,
        onVideoDidPlayFinish: @escaping () -> Void
    ) {
        self.onAdDidLoad = onAdDidLoad
        self.onAdDidFail = onAdDidFail
        self.onAdDidClick = onAdDidClick
        self.onAdDidClose = onAdDidClose
        self.onAdDidShow = onAdDidShow
        self.onVideoDidPlayFinish = onVideoDidPlayFinish
        super.init()
    }
    
    func nativeExpressFullscreenVideoAdDidLoad(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.LoadSucceed")
        }
        onAdDidLoad(fullscreenVideoAd)
    }
    
    func nativeExpressFullscreenVideoAd(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, didFailWithError error: Error?) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.LoadFail")
        }
        onAdDidFail(error)
    }
    
    func nativeExpressFullscreenVideoAdDidClick(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Click")
        }
        onAdDidClick()
    }
    
    func nativeExpressFullscreenVideoAdDidClose(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Close")
        }
        onAdDidClose()
    }
    
    func nativeExpressFullscreenVideoAdWillVisible(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Show")
        }
        onAdDidShow()
    }
    
    func nativeExpressFullscreenVideoAdDidPlayFinish(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, didFailWithError error: Error?) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.PlayFinish")
        }
        onVideoDidPlayFinish()
    }
}

// MARK: - 开屏广告代理类
class SplashAdDelegate: NSObject, BUSplashAdDelegate {
    private let onLoadSuccess: (BUSplashAd) -> Void
    private let onLoadFail: (Error?) -> Void
    private let onDidClick: () -> Void
    private let onDidClose: (BUSplashAdCloseType) -> Void
    private let onDidShow: () -> Void
    
    init(
        onLoadSuccess: @escaping (BUSplashAd) -> Void,
        onLoadFail: @escaping (Error?) -> Void,
        onDidClick: @escaping () -> Void,
        onDidClose: @escaping (BUSplashAdCloseType) -> Void,
        onDidShow: @escaping () -> Void
    ) {
        self.onLoadSuccess = onLoadSuccess
        self.onLoadFail = onLoadFail
        self.onDidClick = onDidClick
        self.onDidClose = onDidClose
        self.onDidShow = onDidShow
        super.init()
    }
    
    func splashAdLoadSuccess(_ splashAd: BUSplashAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.LoadSucceed")
        }
        onLoadSuccess(splashAd)
    }
    
    func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.LoadFail")
        }
        onLoadFail(error)
    }
    
    func splashAdRenderSuccess(_ splashAd: BUSplashAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Success")
        }
        debugPrint("开屏广告渲染成功")
    }
    
    func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Fail")
        }
        debugPrint("开屏广告渲染失败: \(error?.localizedDescription ?? "未知错误")")
        onLoadFail(error)
    }
    
    func splashAdWillShow(_ splashAd: BUSplashAd) {
        debugPrint("开屏广告即将显示")
    }
    
    func splashAdDidShow(_ splashAd: BUSplashAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Show")
        }
        onDidShow()
    }
    
    func splashAdDidClick(_ splashAd: BUSplashAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Click")
        }
        onDidClick()
    }
    
    func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Close")
        }
        onDidClose(closeType)
    }
    
    func splashAdViewControllerDidClose(_ splashAd: BUSplashAd) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Close.2")
        }
        debugPrint("开屏广告视图控制器关闭")
    }
    
    func splashDidCloseOtherController(_ splashAd: BUSplashAd, interactionType: BUInteractionType) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Close.3")
        }
        debugPrint("开屏广告关闭其他控制器:\(interactionType.rawValue)")
    }
    
    func splashVideoAdDidPlayFinish(_ splashAd: BUSplashAd, didFailWithError error: Error?) {
        Task { @MainActor in
            ThirdAnalytics.event("Interstitial.Finish")
        }
        debugPrint("开屏广告视频播放完成")
    }
}

