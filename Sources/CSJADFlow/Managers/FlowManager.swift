import Foundation
import SwiftUI
import BUAdSDK

// MARK: - 流程状态
enum FlowState {
  case idle
  case running
  case completed
}

// MARK: - 流程管理器
@MainActor
class FlowManager: ObservableObject {
    static let shared = FlowManager()
    
    @Published var currentFlowIndex: Int = 0
    @Published var flowState: FlowState = .idle
    @Published var showEvaluateResult: Bool = false
    @Published var evaluateResultImage: String = ""
    @Published var evaluateResultLink: String?
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var alertCancelButton: String = ""
    @Published var alertConfirmButton: String = ""
    @Published var currentAdCount: Int = 0
    @Published var isWaitingForAd: Bool = false
    
    private var configManager = AdConfigManager.shared
    private var adManager = AdManager.shared
    private var flows: [FlowItem] = []
    
    // E流程相关
    private var isEvaluateFlow: Bool = false
    private var evaluateBackgroundIdentifier: String = ""
    
    // A流程相关
    private var currentAdTimes: Int = 0
    private var currentAdData: AdData?
    private var displayingAd: Any?
    private var adDelegate: Any?
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - 设置通知监听
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        if isEvaluateFlow {
            evaluateBackgroundIdentifier = UUID().uuidString
            debugPrint("📱 应用进入后台，设置评价标识符: \(evaluateBackgroundIdentifier)")
            // 显示评价结果图片
            if let flow = getCurrentFlow() {
                if let data = flow.parsedData as? EvaluateData,
                   let image = data.image {
                    evaluateResultImage = image
                    evaluateResultLink = data.link
                    showEvaluateResult = true
                    
                    ThirdAnalytics.event("EvaluateResult：\(data.result)")
                }
        }
        }
    }
    
    @objc private func appWillEnterForeground() {
        if isEvaluateFlow && !evaluateBackgroundIdentifier.isEmpty {
            debugPrint("📱 应用回到前台，检测到评价标识符，显示结果图片")
            // 立即进入下一个流程（用户可以点击图片跳转）
            evaluateBackgroundIdentifier = ""
            isEvaluateFlow = false
            moveToNextFlow()
        }
    }
    
    // MARK: - 处理评价结果图片点击
    func handleEvaluateResultTap() {
        guard let link = evaluateResultLink else {
            debugPrint("⚠️ 评价结果链接为空")
            return
        }
        if link == "" {
            debugPrint("⚠️ 评价结果链接为空")
            return
        }
        if let url = URL(string: link) {
            UIApplication.shared.open(url)
            debugPrint("🔗 点击评价结果图片，打开链接: \(link)")
        } else {
            debugPrint("❌ 评价结果链接无效: \(link)")
        }
    }
    
    // MARK: - 开始流程
    func startFlows() {
        guard let config = configManager.config else {
            debugPrint("❌ 配置未加载，无法开始流程")
            return
        }
        
        flows = config.flows
        currentFlowIndex = 0
        flowState = .running
        
        debugPrint("🎬 开始执行流程，共 \(flows.count) 个流程")
        executeCurrentFlow()
    }
    
    // MARK: - 执行当前流程
    private func executeCurrentFlow() {
        guard currentFlowIndex < flows.count else {
            debugPrint("✅ 所有流程执行完成")
            flowState = .completed
            return
        }
        
        let flow = flows[currentFlowIndex]
        debugPrint("▶️ 执行流程 \(currentFlowIndex + 1)/\(flows.count): \(flow.flowType)")
        
        switch flow.flowType {
        case .evaluate:
            executeEvaluateFlow(flow)
        case .message:
            executeMessageFlow(flow)
        case .ad:
            executeAdFlow(flow)
        case .task:
            debugPrint("⏭️ 任务流程暂未实现，跳过")
            moveToNextFlow()
        case .jump:
            debugPrint("⏭️ 跳转流程暂未实现，跳过")
            moveToNextFlow()
        case .unknown:
            debugPrint("⚠️ 未知流程类型，跳过")
            moveToNextFlow()
        }
    }
    
    // MARK: - E流程：评价
    private func executeEvaluateFlow(_ flow: FlowItem) {
        guard let data = flow.parsedData as? EvaluateData else {
            debugPrint("❌ 评价流程数据解析失败")
            moveToNextFlow()
            return
        }
        
        debugPrint("⭐️ 执行评价流程")
        isEvaluateFlow = true
        
        DispatchQueue.main.async { [weak self] in
            self?.alertTitle = ""
            self?.alertMessage = data.message
            self?.alertCancelButton = ""
            self?.alertConfirmButton = data.button
            self?.showAlert = true
            debugPrint("executeEvaluateFlow")
        }
    }
    
    func handleEvaluateConfirm() {
        guard let flow = getCurrentFlow(),
              let data = flow.parsedData as? EvaluateData
        else {
            return
        }
        debugPrint("handleEvaluateConfirm")
        showAlert = false
        
        // 打开URL
        if let url = URL(string: data.url) {
            UIApplication.shared.open(url)
            debugPrint("🔗 打开评价链接: \(data.url)")
        }
    }
    
    // MARK: - M流程：消息弹窗
    private func executeMessageFlow(_ flow: FlowItem) {
        guard let data = flow.parsedData as? MessageData else {
            debugPrint("❌ 消息流程数据解析失败")
            moveToNextFlow()
            return
        }
        
        debugPrint("💬 执行消息流程")
        
        DispatchQueue.main.async { [weak self] in
            self?.alertTitle = data.title
            self?.alertMessage = data.message
            self?.alertCancelButton = data.cancel
            self?.alertConfirmButton = data.confirm
            self?.showAlert = true
            debugPrint("executeMessageFlow")
        }
    }
    
    func handleMessageResponse() {
        debugPrint("handleMessageResponse")
        showAlert = false
        moveToNextFlow()
    }
    
    // MARK: - A流程：广告
    private func executeAdFlow(_ flow: FlowItem) {
        guard let data = flow.parsedData as? AdData else {
            debugPrint("❌ 广告流程数据解析失败")
            moveToNextFlow()
            return
        }
        
        debugPrint("📺 执行广告流程，需要展示 \(data.times) 次广告")
        currentAdTimes = data.times
        currentAdCount = 0
        currentAdData = data
        
        showNextAd()
    }
    
    private func showNextAd() {
        guard currentAdData != nil else { return }
        
        currentAdCount += 1
        debugPrint("📺 准备展示第 \(currentAdCount)/\(currentAdTimes) 个广告")
        
        // 从缓存池获取广告
        if let cachedAd = adManager.getAdFromCache() {
            displayAd(cachedAd)
        } else {
            // 缓存池为空，等待广告加载
            debugPrint("⏳ 缓存池为空，等待广告加载...")
            isWaitingForAd = true
            
            // 每0.5秒检查一次缓存池
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showNextAd()
            }
        }
    }
    
    private func displayAd(_ cachedAd: CachedAd) {
        isWaitingForAd = false
        
        guard let rootVC = getRootViewController() else {
            debugPrint("❌ 无法获取根视图控制器")
            handleAdClosed()
            return
        }
        
        switch cachedAd.type {
        case .reward:
            displayRewardAd(cachedAd.ad as! BUNativeExpressRewardedVideoAd, rootVC: rootVC)
        case .interstitial:
            displayInterstitialAd(cachedAd.ad as! BUNativeExpressFullscreenVideoAd, rootVC: rootVC)
        case .splash:
            displaySplashAd(cachedAd.ad as! BUSplashAd, rootVC: rootVC)
        }
    }
    
    // MARK: - 展示激励视频
    private func displayRewardAd(_ ad: BUNativeExpressRewardedVideoAd, rootVC: UIViewController) {
        debugPrint("📺 展示激励视频广告")
        
        let delegate = RewardAdDelegate(
            onAdDidLoad: { _ in },
            onAdDidFail: { [weak self] _ in
                self?.handleAdClosed()
            },
            onAdDidClick: {},
            onAdDidClose: { [weak self] in
                self?.handleAdClosed()
            },
            onAdDidShow: {},
            onRewardVerify: { _ in }
        )
        
        adDelegate = delegate
        displayingAd = ad
        ad.delegate = delegate
        ad.show(fromRootViewController: rootVC)
    }
    
    // MARK: - 展示插屏广告
    private func displayInterstitialAd(
        _ ad: BUNativeExpressFullscreenVideoAd, rootVC: UIViewController
    ) {
        debugPrint("📺 展示插屏广告")
        
        let delegate = InterstitialAdDelegate(
            onAdDidLoad: { _ in },
            onAdDidFail: { [weak self] _ in
                self?.handleAdClosed()
            },
            onAdDidClick: {},
            onAdDidClose: { [weak self] in
                self?.handleAdClosed()
            },
            onAdDidShow: {},
            onVideoDidPlayFinish: {}
        )
        
        adDelegate = delegate
        displayingAd = ad
        ad.delegate = delegate
        ad.show(fromRootViewController: rootVC)
    }
    
    // MARK: - 展示开屏广告
    private func displaySplashAd(_ ad: BUSplashAd, rootVC: UIViewController) {
        debugPrint("📺 展示开屏广告")
        
        let delegate = SplashAdDelegate(
            onLoadSuccess: { _ in },
            onLoadFail: { [weak self] _ in
                self?.handleAdClosed()
            },
            onDidClick: {},
            onDidClose: { [weak self] _ in
                self?.handleAdClosed()
            },
            onDidShow: {}
        )
        
        adDelegate = delegate
        displayingAd = ad
        ad.delegate = delegate
        ad.showSplashView(inRootViewController: rootVC)
    }
    
    // MARK: - 广告关闭处理
    private func handleAdClosed() {
        debugPrint("🚪 广告关闭")
        
        displayingAd = nil
        adDelegate = nil
        
        guard let currentAdData = currentAdData else { return }
        
        // 从message数组中随机选择一组提示
        guard !currentAdData.message.isEmpty else {
            debugPrint("❌ 广告提示消息数组为空")
            moveToNextFlow()
            return
        }
        
        let randomMessage = currentAdData.message.randomElement()!
        debugPrint("📝 随机选择提示: \(randomMessage.title)")
        
        // 显示提示弹窗
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.alertTitle = randomMessage.title
            self.alertMessage = randomMessage.message
            self.alertCancelButton = randomMessage.cancel
            self.alertConfirmButton = randomMessage.confirm
            self.showAlert = true
            debugPrint("handleAdClosed")
        }
    }
    
    func handleAdAlertResponse() {
        debugPrint("handleAdAlertResponse")
        showAlert = false
        
        // 判断是否还需要继续展示广告
        if currentAdCount < currentAdTimes {
            // 继续展示下一个广告
            showNextAd()
        } else {
            // 广告流程完成，进入下一个流程
            debugPrint("✅ 广告流程完成，共展示 \(currentAdCount) 次")
            currentAdData = nil
            currentAdTimes = 0
            currentAdCount = 0
            moveToNextFlow()
        }
    }
    
    // MARK: - 移动到下一个流程
    private func moveToNextFlow() {
        currentFlowIndex += 1
        executeCurrentFlow()
    }
    
    // MARK: - 获取当前流程
    private func getCurrentFlow() -> FlowItem? {
        guard currentFlowIndex < flows.count else { return nil }
        return flows[currentFlowIndex]
    }
    
    // MARK: - 获取根视图控制器
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController
        else {
            return nil
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        return topVC
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
