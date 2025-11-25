import Foundation
// MARK: - 流程项
public struct FlowItem: Codable {
    public let type: String
    public let data: String
    
    // 解析后的数据
    public var parsedData: FlowData? {
        debugPrint("FlowItem.Data: \(data)")
        guard let jsonData = data.data(using: .utf8) else { return nil }
        
        switch type {
        case "E":
            return try? JSONDecoder().decode(EvaluateData.self, from: jsonData)
        case "M":
            return try? JSONDecoder().decode(MessageData.self, from: jsonData)
        case "A":
            return try? JSONDecoder().decode(AdData.self, from: jsonData)
        case "T":
            return try? JSONDecoder().decode(DemoData.self, from: jsonData)
        case "J":
            return try? JSONDecoder().decode(JumpData.self, from: jsonData)
        default:
            return nil
        }
    }
    
    public var flowType: FlowType {
        return FlowType(rawValue: type) ?? .unknown
    }
}
