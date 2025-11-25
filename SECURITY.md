# 🔒 安全提示

## GitHub Token 安全

**重要：** 脚本中包含了 GitHub Personal Access Token。

### 安全建议

1. **不要将包含 token 的脚本提交到公共仓库**
   - Token 已经在 `.gitignore` 中被忽略（通过环境变量文件）
   - 但脚本文件本身会被提交

2. **使用环境变量（推荐）**
   ```bash
   # 在 ~/.zshrc 或 ~/.bash_profile 中设置
   export GITHUB_TOKEN="your_token_here"
   ```
   然后脚本会自动使用环境变量。

3. **如果 token 泄露，立即撤销**
   - 访问：https://github.com/settings/tokens
   - 找到对应的 token 并撤销

4. **限制 token 权限**
   - 只授予必要的权限（repo 权限用于推送）

### 当前配置

脚本会优先使用环境变量 `GITHUB_TOKEN`，如果没有设置，才使用脚本中的默认值。

### 最佳实践

1. 从脚本中移除硬编码的 token
2. 使用环境变量或密钥管理服务
3. 定期轮换 token

