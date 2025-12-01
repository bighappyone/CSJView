Pod::Spec.new do |s|
  s.name         = "CSJView"
  s.version      = "1.0.6"
  s.summary      = "Ads-CN wrapper for Pangle ads display"
  s.description  = <<-DESC
  CSJView is a Swift SDK that wraps Ads-CN (Pangle) for easy integration of advertising features.
  It provides support for reward videos, splash screens, interstitial ads, and more.
  The SDK includes a complete ad flow management system with caching and analytics support.
  DESC

  s.homepage     = "https://github.com/bighappyone/CSJView"
  s.license      = { :type => "MIT" }
  s.author       = { "bighappyone" => "bighappyone@gmail.com" }

  s.ios.deployment_target = "15.0"

  s.source       = { :git => "https://github.com/bighappyone/CSJView.git", :tag => s.version }

  # 二进制分发配置
  # 注意：二进制框架已经包含了所有依赖（Ads-CN、BUTTSDKFramework等），不需要额外声明依赖
  # 需要将 xcframework 提交到 Git 仓库（建议使用 Git LFS）
  s.vendored_frameworks = "Output/CSJView.xcframework"
  s.preserve_paths = "Output/CSJView.xcframework"

  # 二进制版本不依赖 Ads-CN，所有依赖已包含在框架内

  s.swift_versions = ["5.0", "5.5", "6.0"]
  # 注意：框架是动态框架，不需要设置 static_framework
  # 动态框架会被 CocoaPods 正确嵌入到应用中
  
  # 确保使用模块
  s.module_name = "CSJView"
end

