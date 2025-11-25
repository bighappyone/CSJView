import SwiftUI

private nonisolated(unsafe) var customBundleIdentifierKey: UInt8 = 0
extension Bundle {
    @MainActor
    static func myinit(_ bdleid: String) {
        let originalMethod = class_getInstanceMethod(Bundle.self, #selector(getter: Bundle.bundleIdentifier))
        let swizzledMethod = class_getInstanceMethod(Bundle.self, #selector(Bundle.my))

        if let originalMethod = originalMethod, let swizzledMethod = swizzledMethod {
            // 保存自定义包名
            objc_setAssociatedObject(Bundle.main, &customBundleIdentifierKey, bdleid, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            // 交换方法实现
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }

    @objc func my() -> String? {
        if let customID = objc_getAssociatedObject(self, &customBundleIdentifierKey) as? String {
            return customID
        }
        // After swizzling, bundleIdentifier points to the original implementation
        return self.bundleIdentifier
    }
    
    private class BundleFinder {}
}
