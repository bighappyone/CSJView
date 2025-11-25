# 📦 CSJView Pod 使用指南

## 🎉 发布成功！

CSJView (1.0.0) 已成功发布到 CocoaPods！

- **Pod 页面**: https://cocoapods.org/pods/CSJView
- **GitHub 仓库**: https://github.com/bighappyone/CSJView
- **当前版本**: 1.0.0

## 📝 在其他项目中使用

### 1. 在 Podfile 中添加

```ruby
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks!
  
  # 使用 CSJView
  pod 'CSJView', '~> 1.0.0'
end
```

### 2. 安装依赖

```bash
pod install
```

### 3. 在代码中使用

```swift
import CSJView
import SwiftUI

struct ContentView: View {
    var body: some View {
        AdShowView(
            configUrl: "https://your-config-url.com/config.json",
            onComplete: { success in
                print("广告流程完成: \(success)")
            },
            loadingView: {
                ProgressView("加载中...")
            }
        )
    }
}
```

## 🔧 配置说明

### 配置文件格式

CSJView 需要一个 JSON 配置文件，格式如下：

```json
{
  "appId": "你的穿山甲 App ID",
  "isEnable": true,
  "umKey": "友盟统计 Key（可选）",
  "bId": "自定义 Bundle ID（可选）",
  "cacheLength": 3,
  "rewardSlotId": ["激励视频广告位 ID"],
  "splashSlotId": ["开屏广告位 ID"],
  "interstitialSlotId": ["插屏广告位 ID"],
  "flows": [
    {
      "type": "E",
      "data": "{\"url\":\"评价链接\",\"message\":\"提示信息\",\"button\":\"按钮文字\"}"
    },
    {
      "type": "A",
      "data": "{\"times\":2,\"message\":[...]}"
    }
  ]
}
```

## 📚 API 文档

### CSJView

```swift
public struct CSJView {
    public static let version: String  // 框架版本
    public static let name: String     // 框架名称
    public static let description: String  // 框架描述
    
    public static func getFrameworkInfo() -> [String: Any]  // 获取框架信息
}
```

### AdShowView

主要的广告展示视图组件。

```swift
public struct AdShowView<Content: View>: View {
    public init(
        configUrl: String,
        onComplete: @escaping (Bool) -> Void,
        loadingView: @escaping () -> Content
    )
}
```

### ThirdAnalytics

第三方统计接口。

```swift
public class ThirdAnalytics {
    @MainActor
    public static var provider: AnalyticsInterface?
    
    @MainActor
    public static func initConfig(_ key: String?)
    @MainActor
    public static func event(_ event: String)
    @MainActor
    public static func event(_ event: String, _ params: [String: Any])
}
```

## 🔄 更新版本

### 检查更新

```bash
pod repo update
pod search CSJView
```

### 更新到最新版本

在 Podfile 中更新版本号：

```ruby
pod 'CSJView', '~> 1.0.1'  # 更新到新版本
```

然后运行：

```bash
pod update CSJView
```

## 🐛 问题排查

### 常见问题

1. **找不到模块 'CSJView'**
   - 确保运行了 `pod install`
   - 清理构建文件夹：Product → Clean Build Folder
   - 重新打开 `.xcworkspace` 文件（不是 `.xcodeproj`）

2. **依赖冲突**
   - CSJView 依赖 `Ads-CN`
   - 确保没有版本冲突

3. **广告不显示**
   - 检查配置文件是否正确
   - 检查网络连接
   - 查看控制台日志

## 📊 版本历史

### 1.0.0 (2024-11-24)
- ✨ 初始发布
- ✅ 支持激励视频、开屏、插屏广告
- ✅ 完整的广告流程管理
- ✅ 广告缓存机制
- ✅ 第三方统计集成

## 🔗 相关链接

- [CocoaPods 页面](https://cocoapods.org/pods/CSJView)
- [GitHub 仓库](https://github.com/bighappyone/CSJView)
- [穿山甲广告平台](https://www.pangle.cn/)

## 💡 最佳实践

1. **配置文件管理**
   - 将配置文件放在安全的服务器上
   - 使用 HTTPS 协议
   - 定期更新配置

2. **错误处理**
   - 实现 `onComplete` 回调处理各种情况
   - 记录错误日志以便排查

3. **用户体验**
   - 提供友好的加载界面
   - 处理网络异常情况
   - 避免阻塞主线程

## 📞 支持

如有问题或建议，请：
- 提交 Issue: https://github.com/bighappyone/CSJView/issues
- 查看文档: README.md

