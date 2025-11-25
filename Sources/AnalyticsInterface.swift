public protocol AnalyticsInterface {
    func initConfig (_ key:String?)
    func event(_ event: String)
    func event(_ event: String, _ params:[String: Any])
}

public class ThirdAnalytics {
    @MainActor
    public static var provider: AnalyticsInterface?
    
    @MainActor
    public static func initConfig(_ key:String?) {
        provider?.initConfig(key)
    }
    
    @MainActor
    public static func event(_ event: String) {
        provider?.event(event)
    }
    
    @MainActor
    public static func event(_ event: String, _ params:[String: Any]) {
        provider?.event(event, params)
    }
}
