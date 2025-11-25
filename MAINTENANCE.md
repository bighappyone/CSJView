# 🔧 CSJView Pod 维护指南

## 📦 发布新版本流程

### 1. 更新版本号

在 `CSJView.podspec` 中更新版本：

```ruby
s.version = "1.0.1"  # 新版本号
```

### 2. 更新代码

```bash
# 修改代码后
git add .
git commit -m "Update: 描述你的更改"
```

### 3. 创建标签并推送

```bash
# 创建新标签
git tag 1.0.1
git tag v1.0.1  # 可选，同时创建带 v 的标签

# 推送代码
git push origin main

# 推送标签
git push origin 1.0.1
git push origin v1.0.1
# 或一次性推送所有标签
git push --tags
```

### 4. 发布新版本

```bash
pod trunk push CSJView.podspec --allow-warnings --skip-import-validation
```

## 📝 版本号规范

遵循 [语义化版本](https://semver.org/)：

- **主版本号 (MAJOR)**: 不兼容的 API 修改
- **次版本号 (MINOR)**: 向后兼容的功能新增
- **修订号 (PATCH)**: 向后兼容的问题修正

示例：
- `1.0.0` → `1.0.1` (修复 bug)
- `1.0.1` → `1.1.0` (新功能)
- `1.1.0` → `2.0.0` (重大变更)

## 🔍 验证发布

### 本地验证

```bash
pod lib lint CSJView.podspec --allow-warnings --skip-import-validation
```

### 检查已发布版本

```bash
pod trunk info CSJView
```

### 搜索 Pod

```bash
pod search CSJView
```

## 🛠️ 维护任务

### 定期检查

- [ ] 检查依赖更新（Ads-CN）
- [ ] 测试新版本 iOS/Xcode
- [ ] 更新文档
- [ ] 处理 Issues

### 更新依赖

如果 `Ads-CN` 有新版本：

1. 测试兼容性
2. 更新 podspec（如果需要）
3. 发布新版本

## 📊 统计信息

查看 Pod 的下载和使用情况：

```bash
pod trunk info CSJView
```

或在 CocoaPods 网站查看：
https://cocoapods.org/pods/CSJView

## 🚨 紧急修复

如果发现严重 bug：

1. 快速修复代码
2. 发布补丁版本（如 1.0.0 → 1.0.1）
3. 通知用户更新

## 📚 文档更新

每次发布新版本时：

- [ ] 更新 `USAGE.md` 中的版本历史
- [ ] 更新 API 文档（如有变更）
- [ ] 更新 README.md
- [ ] 更新示例代码

## 🔐 安全注意事项

- 不要提交敏感信息（API keys, tokens）
- 使用 `.gitignore` 排除敏感文件
- 定期检查依赖的安全性

## 📞 用户支持

- GitHub Issues: 处理 bug 报告和功能请求
- 文档: 保持文档最新和清晰
- 示例: 提供完整的使用示例

