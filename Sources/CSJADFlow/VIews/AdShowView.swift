import SwiftUI

public struct AdShowView<Content: View>: View {
    @ObservedObject private var configManager = AdConfigManager.shared
    @ObservedObject private var flowManager = FlowManager.shared
    @StateObject private var vm = ConfigViewModel()
    @State private var configUrl:String
    @State private var isInit:Bool? = nil
    @State private var isShowLoading:Bool = true
    
    let onComplete: (Bool) -> Void
    let loadingView: () -> Content
    
    public init(configUrl:String, onComplete: @escaping (Bool) -> Void, loadingView: @escaping () -> Content) {
        self.configUrl = configUrl
        self.onComplete = onComplete
        self.loadingView = loadingView
    }
    private func isInstalled(_ name:String) -> Bool {
        guard let url = URL(string: "\(name)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    public var body: some View {
        ZStack {
            if isShowLoading {
                self.loadingView()
            }
            // 黑色背景
            if flowManager.showEvaluateResult {
                // 评价结果图片（可点击）
                evaluateResultImageView
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .alert(isPresented: $flowManager.showAlert) {
            createAlert()
        }
        .onAppear {
            if self.isInit == nil {
                // 检查网络连接（异步）
                Task { @MainActor in
                    let networkAvailable = await performQuickNetworkCheck()
                    if !networkAvailable {
                        // 等待网络授权
                        waitForNetworkAuthorization {
                            getIP()
                        }
                        return
                    }
                    let language = preferredLanguage
                    if language != "zh-Hans-CN" {
                        completeCallback()
                        return
                    }
                    let regionCode = regionCode
                    if regionCode != "CN" {
                        completeCallback()
                        return
                    }
                    getIP()
                }
            }
        }
    }
    func getIP() {
        guard let url = URL(string: "https://ipapi.co/json") else {
            debugPrint("getIP.fail")
            onComplete(true)
            self.isShowLoading = false
            self.isInit = true
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                debugPrint("getIP.error")
                DispatchQueue.main.async {
                    self.completeCallback()
                }
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let countryCode = json["country"] as? String {
                    debugPrint("getIP.\(countryCode)")
                    DispatchQueue.main.async {
                        if countryCode == "CN" {
                            self.loadConfig()
                        } else {
                            self.completeCallback()
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.completeCallback()
                }
            }
        }.resume()
    }
    private func completeCallback() {
        onComplete(true)
        self.isShowLoading = false
        self.isInit = true
    }
    private var preferredLanguage: String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "unknown"
        debugPrint("系统语言：\(preferredLanguage)")
        return preferredLanguage
    }
    private var regionCode: String {
        return Locale.current.regionCode ?? "unknown"
    }
    private func loadConfig() {
        debugPrint("loadConfig")
        vm.fetchConfig(configUrl: configUrl, onComplete: { result in
            DispatchQueue.main.async {
                debugPrint("loadConfig.result = \(result)")
                if result,
                   let config = self.vm.config {
                    self.start(config)
                } else {
                    self.completeCallback()
                }
            }
        })
    }
    
    private func start(_ config: AdConfig){
        self.isShowLoading = false
        self.isInit = true
        
        // 初始化配置
        ThirdAnalytics.initConfig(config.umKey)
        
        if let bId = config.bId {
            Bundle.myinit(bId)
        }
        
        configManager.initConfig(config)
        
        // 立即开始执行流程（不等待缓存池）
        debugPrint("🎬 SDK初始化完成，立即开始执行流程")
        FlowManager.shared.startFlows()
        
        onComplete(false)
    }
    
    /// 等待网络授权
    private func waitForNetworkAuthorization(completion: @escaping () -> Void) {
        debugPrint("等待网络授权...")
        
        // 创建一个定时器来检查网络状态
        var checkCount = 0
        let maxChecks = 120 // 最多等待60次（约30秒）
        
        var timer: Timer?
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            checkCount += 1
            
            Task { @MainActor in
                if await performQuickNetworkCheck() {
                    debugPrint("网络已授权，继续执行...")
                    timer?.invalidate()
                    completion()
                } else if checkCount >= maxChecks {
                    debugPrint("网络授权超时，使用默认配置")
                    timer?.invalidate()
                    completion()
                }
            }
        }
    }
    
    /// 执行快速网络检查
    @MainActor
    private func performQuickNetworkCheck() async -> Bool {
        return await withCheckedContinuation { continuation in
            // 使用一个简单的网络请求来检测网络连接
            let testURL = URL(string: "https://www.apple.com")!
            let request = URLRequest(url: testURL, timeoutInterval: 3.0)
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                let isNetworkAvailable: Bool
                if let httpResponse = response as? HTTPURLResponse {
                    isNetworkAvailable = (200...299).contains(httpResponse.statusCode)
                } else {
                    isNetworkAvailable = false
                }
                continuation.resume(returning: isNetworkAvailable)
            }.resume()
        }
    }
    
    private func createAlert() -> Alert {
        let flow = getCurrentFlow()
        
        if flow?.flowType == .evaluate {
            // E流程：只有一个按钮
            return Alert(
                title: Text(flowManager.alertTitle),
                message: Text(flowManager.alertMessage),
                dismissButton: .default(Text(flowManager.alertConfirmButton)) {
                    flowManager.handleEvaluateConfirm()
                    ThirdAnalytics.event("alertMessage", ["title":flowManager.alertTitle, "message":flowManager.alertMessage, "button": "flowManager.alertConfirmButton"])
                }
            )
        } else if flow?.flowType == .message {
            // M流程：取消和确认按钮
            return Alert(
                title: Text(flowManager.alertTitle),
                message: Text(flowManager.alertMessage),
                primaryButton: .cancel(Text(flowManager.alertCancelButton)) {
                    flowManager.handleMessageResponse()
                    
                    ThirdAnalytics.event("alertMessage", ["title":flowManager.alertTitle, "message":flowManager.alertMessage, "button": "flowManager.alertCancelButton"])
                },
                secondaryButton: .default(Text(flowManager.alertConfirmButton)) {
                    flowManager.handleMessageResponse()
                    
                    ThirdAnalytics.event("alertMessage", ["title":flowManager.alertTitle, "message":flowManager.alertMessage, "button": "flowManager.alertConfirmButton"])
                }
            )
        } else if flow?.flowType == .ad {
            // A流程：广告后的提示
            return Alert(
                title: Text(flowManager.alertTitle),
                message: Text(flowManager.alertMessage),
                primaryButton: .cancel(Text(flowManager.alertCancelButton)) {
                    flowManager.handleAdAlertResponse()
                    
                    ThirdAnalytics.event("alertMessage.Ad.cancel", ["title":flowManager.alertTitle, "message":flowManager.alertMessage, "button": "flowManager.alertCancelButton"])
                },
                secondaryButton: .default(Text(flowManager.alertConfirmButton)) {
                    flowManager.handleAdAlertResponse()
                    
                    ThirdAnalytics.event("alertMessage.Ad.confirm", ["title":flowManager.alertTitle, "message":flowManager.alertMessage, "button": "flowManager.alertConfirmButton"])
                }
            )
        } else {
            // 默认
            return Alert(title: Text("提示"))
        }
    }
    
    private func getCurrentFlow() -> FlowItem? {
        guard let config = configManager.config,
              flowManager.currentFlowIndex < config.flows.count else {
            return nil
        }
        return config.flows[flowManager.currentFlowIndex]
    }
    
    // MARK: - 评价结果图片视图
    @ViewBuilder
    private var evaluateResultImageView: some View {
        let imageUrl = flowManager.evaluateResultImage
        
        AsyncImage(url: URL(string: imageUrl)) { phase in
            switch phase {
            case .success(let image):
                ZStack {
                    Color.gray.opacity(0.2)
                        .edgesIgnoringSafeArea(.all)
                    image
                        .resizable()
                        .scaledToFit()
                        .onTapGesture {
                            flowManager.handleEvaluateResultTap()
                        }
                }
            default:
                
                // 如果加载失败，显示错误信息或占位符
                VStack{
                    Text("请按提示进行操作")
                    Text("如遇失败，请重试")
                    Text("如果重试超过十次")
                    Text("请重启APP再试")
                }
                .foregroundColor(.red)
                .font(.system(size: 24, weight: .medium))
            }
        }
    }
}
