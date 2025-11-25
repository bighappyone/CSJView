import SwiftUI
import ObjectiveC

private nonisolated(unsafe) var customBundleIdentifierKey: UInt8 = 0

extension Bundle {
    // 保存原始实现的 IMP
    private static var originalBundleIdentifierIMP: IMP?
    
    @MainActor
    static func myinit(_ bdleid: String) {
        let originalMethod = class_getInstanceMethod(Bundle.self, #selector(getter: Bundle.bundleIdentifier))
        let swizzledMethod = class_getInstanceMethod(Bundle.self, #selector(Bundle.my))

        if let originalMethod = originalMethod, let swizzledMethod = swizzledMethod {
            // 保存原始实现
            Bundle.originalBundleIdentifierIMP = method_getImplementation(originalMethod)
            
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
        // 直接调用原始实现，避免递归
        // 在方法交换后，我们需要通过保存的 IMP 来调用原始实现
        if let originalIMP = Bundle.originalBundleIdentifierIMP {
            // 使用 objc_msgSend 调用原始实现
            // 注意：需要导入 objc/message.h 或使用 @_silgen_name
            typealias BundleIdentifierGetter = @convention(c) (AnyObject, Selector) -> String?
            let originalGetter = unsafeBitCast(originalIMP, to: BundleIdentifierGetter.self)
            return originalGetter(self, #selector(getter: Bundle.bundleIdentifier))
        }
        // 如果原始实现不可用，返回 nil
        return nil
    }
    
    private class BundleFinder {}
}
