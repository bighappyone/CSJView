import SwiftUI

public struct CSJView {
    
    /// 框架版本
    public static let version = "1.0.1"
    
    /// 框架名称
    public static let name = "CSJView"
    
    /// 框架描述
    public static let description = "穿山甲广告快速接入"
        
    /// 获取框架信息
    /// - Returns: 框架信息字典
    public static func getFrameworkInfo() -> [String: Any] {
        return [
            "name": name,
            "version": version,
            "description": description,
            "platform": "iOS",
            "minimumVersion": "14.0"
        ]
    }
}
