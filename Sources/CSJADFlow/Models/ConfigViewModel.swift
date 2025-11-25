import SwiftUI

// 定义网络请求类／数据源
@MainActor
class ConfigViewModel: ObservableObject {
    @Published var config: AdConfig?
    @Published var loadingError: Error?

    func fetchConfig(configUrl: String, onComplete: @escaping @Sendable (Bool) -> Void) {
        // 这里用你真实的 URL
        guard let url = URL(string: configUrl) else {
            debugPrint("URL 无效")
            DispatchQueue.main.async {
                onComplete(false)
            }
            return
        }

        let request = URLRequest(url: url)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // 在后台线程
            if let error = error {
                DispatchQueue.main.async {
                    debugPrint(error)
                    self.loadingError = error
                    onComplete(false)
                }
                return
            }

            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode), let data = data else {
                DispatchQueue.main.async {
                    self.loadingError = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "响应错误或无数据"])
                    debugPrint("响应错误或无数据")
                    onComplete(false)
                }
                return
            }
            debugPrint("data: \(data)")

            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode(AdConfig.self, from: data)
                DispatchQueue.main.async {
                    self.config = decoded
                    onComplete(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingError = error
                    onComplete(false)
                }
            }
        }

        task.resume()
    }
}
