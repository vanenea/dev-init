# AGENTS.md - 开发环境配置仓库

这是一个用于自动化 Linux 开发环境配置的 Bash 脚本仓库。

##仓库结构

- `dev-init.sh` - 原始安装脚本（遗留版本，存在安全问题）
- `dev-init-optimized.sh` - 优化后的生产级安装脚本

## 构建/测试命令

```bash
# 验证语法（提交前推荐）
bash -n dev-init.sh
bash -n dev-init-optimized.sh

# 使用 ShellCheck 进行代码检查（如果可用）
shellcheck dev-init.sh
shellcheck dev-init-optimized.sh

# 测试脚本（试运行，不进行实际安装）
# 注意：这些脚本需要交互式对话工具（whiptail/dialog）
# 如需在非交互环境中测试，请修改脚本以接受命令行参数
```

## 代码风格指南

### Bash Shebang
```bash
#!/usr/bin/env bash  # 可移植性，使用 PATH 查找 bash
```

### 错误处理
- 始终使用 `set -e` 在出错时退出
- 为不同失败模式定义退出代码
- 检查命令返回码：`if ! command; then ...; fi`
- 使用 `command -v` 代替 `which` 以提高可移植性

### 函数命名
- 使用 snake_case：`install_git`, `check_cmd`, `log_info`
- 使用动词前缀：`install_`, `check_`, `log_`
- 保持函数小而单一

### 变量
- 使用 UPPER_CASE 表示常量：`NVM_DIR`, `JAVA_VERSION`
- 使用小写表示局部变量：`version`, `exit_code`
- 引用所有变量扩展：`"$VAR"`, `"${ARRAY[@]}"`

### 输出格式
- 使用颜色代码提供用户反馈：
  - GREEN：成功/信息
  - YELLOW：警告
  - RED：错误
- 定义辅助函数以保持输出一致
- 使用 `==========` 或 `========` 清晰分隔各部分

### 安全最佳实践
- **关键**：绝不将下载内容直接通过管道传递给 shell
  - ❌ `curl URL | bash`
  - ✅ `curl URL -o temp.sh && bash temp.sh && rm temp.sh`

- 下载验证：
  - 检查 curl 退出代码
  - 验证下载的文件不为空
  - 使用 `-fsSL` 标志：静默失败、显示错误、跟随重定向

- 版本管理：
  - 尽可能避免硬编码版本
  - 从官方 API 获取最新版本（如 GitHub releases API）
  - API 调用失败时提供回退版本

### 对话/用户交互
- 支持多种对话工具：whiptail（首选）、dialog（备选）
- 检查用户取消操作：在对话调用后检查退出代码
- 用户取消时使用合理的默认值
- 在破坏性操作前显示确认摘要

### 第三方安装
- NVM (Node Version Manager)：
  - 从 GitHub API 获取最新版本
  - 在子 shell 中 source NVM，持久化到 ~/.bashrc 供用户会话使用

- Docker：
  - 使用官方 get.docker.com 脚本
  - 安装后将用户添加到 docker 组
  - 提示用户组更改需要注销/登录

### 错误恢复
- 在循环中跟踪失败的安装
- 失败后继续安装剩余组件
- 显示带有成功/失败状态的最终摘要
- 如果任何安装失败，返回非零退出代码

## 开发模式

### 添加新组件
1. 在 whiptail 检查列表中添加组件，包含描述和默认状态
2. 创建安装函数，遵循 `install_<component>()` 模式
3. 在主执行循环中添加 case 条目
4. 更新摘要显示

### 安全脚本下载模式
```bash
safe_download() {
    local url="$1"
    local output="$2"

    if ! curl -fsSL "$url" -o "$output"; then
        log_error "Failed to download: $url"
        rm -f "$output"
        return 1
    fi

    if [ ! -s "$output" ]; then
        log_error "Downloaded file is empty"
        rm -f "$output"
        return 1
    fi

    return 0
}
```

### 版本检测模式
```bash
if check_cmd java; then
    current=$(java -version 2>&1 | head -n 1)
    if [[ "$current" == *"$EXPECTED_VERSION"* ]]; then
        log_info "Already installed"
    else
        # Install/update
    fi
fi
```

## 常见问题

1. **whiptail 不可用**：使用 `sudo apt install whiptail` 安装，或回退到 dialog
2. **Docker 权限错误**：安装后用户必须运行 `newgrp docker` 或注销/登录
3. **NVM 不在 PATH 中**：安装后运行 `source ~/.bashrc`
4. **交互式测试**：使用 expect 或修改脚本以接受 CI/CD 的命令行参数

## 维护说明

- 每季度审查 NVM 版本获取 - GitHub API 可能会更改
- 随新版本发布更新 Java LTS 版本
- 在发布前在全新的 Ubuntu/Debian 安装上测试脚本
- 监控第三方安装程序 URL 的安全公告
