import Foundation
// MARK: - 配置管理器
@MainActor
class AdConfigManager: ObservableObject {
    static let shared = AdConfigManager()
    
    @Published var config: AdConfig?
    @Published var errorMessage: String?
    @Published var isInit = false
    
    private init() {}
    
    /// 从JSON文件加载配置
    func initConfig(_ config: AdConfig) {
        errorMessage = nil
        
        self.config = config
        
        debugPrint("✅ 配置加载成功")
        printConfigInfo()
        
        // 配置加载成功后，检查广告配置并初始化SDK
        if config.isEnable {
            debugPrint("🚀 广告已启用，开始初始化SDK")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                AdManager.shared.initializeSDK()
            }
        } else {
            debugPrint("⚠️ 广告未启用，跳过SDK初始化")
        }
    }
    
    /// 打印配置信息
    private func printConfigInfo() {
        guard let config = config else { return }
        debugPrint("📱 App ID: \(config.appId)")
        debugPrint("✅ 是否启用: \(config.isEnable)")
        debugPrint("📋 流程数量: \(config.flows.count)")
        for (index, flow) in config.flows.enumerated() {
            debugPrint("  流程\(index + 1): \(flow.flowType) (\(flow.type))")
            if let parsedData = flow.parsedData {
                debugPrint("    ✓ 数据解析成功")
                if flow.type == "E", let evaluateData = parsedData as? EvaluateData {
                    debugPrint("    ✓ 评价URL: \(evaluateData.url)")
                }
            } else {
                debugPrint("    ✗ 数据解析失败")
            }
        }
    }
    
    /// 获取当前激活的广告位ID
    func getActiveRewardSlotId() -> String? {
        return config?.rewardSlotId.first
    }
    
    func getActiveSplashSlotId() -> String? {
        return config?.splashSlotId.first
    }
    
    func getActiveInterstitialSlotId() -> String? {
        return config?.interstitialSlotId.first
    }
    
    /// 检查配置是否启用
    var isConfigEnabled: Bool {
        return config?.isEnable ?? false
    }
    
    /// 获取流程列表
    var flowItems: [FlowItem] {
        return config?.flows ?? []
    }
}
