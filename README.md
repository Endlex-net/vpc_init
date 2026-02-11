# VPC_INIT v3.0 - Ubuntu 服务器初始化工具

基于模块化架构的 Ubuntu 服务器快速初始化工具。通过简单的命令即可完成用户创建、SSH 配置、系统更新、防火墙设置、Nginx 部署等初始化工作。

## 🚀 快速开始

### 基础初始化

```bash
sudo bash main.sh init
```

### 交互式选择模块

```bash
sudo bash main.sh init -i
```

### 使用配置文件

```bash
# 生成配置文件
sudo bash main.sh config

# 编辑 config.toml
vim config.toml

# 执行初始化
sudo bash main.sh init
```

## ✨ 主要特性

- **模块化架构** - 功能拆分为独立模块，按需加载
- **自动注册** - 新模块自动被发现和注册
- **依赖管理** - 自动处理模块依赖关系
- **断点续跑** - 支持从中断处继续执行
- **多种模式** - 支持配置驱动和交互式两种模式
- **易于扩展** - 添加新模块只需创建文件并注册

## 📂 项目结构

```
vpc_init/
├── main.sh              # 主入口脚本
├── lib/                 # 核心库
│   ├── core.sh         # 日志、错误处理、工具函数
│   ├── checkpoint.sh   # 断点续跑系统
│   ├── registry.sh     # 模块注册机制
│   └── loader.sh       # 模块加载器
├── modules/            # 功能模块
│   ├── 00-core/        # 核心模块
│   │   ├── user.sh    # 用户创建
│   │   ├── ssh.sh     # SSH配置
│   │   └── system.sh  # 系统基础
│   ├── 10-network/     # 网络模块
│   │   ├── firewall.sh
│   │   └── nginx.sh
│   ├── 20-runtime/     # 运行环境
│   │   ├── docker.sh
│   │   └── swap.sh
│   └── 30-tools/       # 工具模块
│       ├── security.sh
│       ├── p10k.sh
│       ├── verify.sh
│       └── fix-dpkg.sh
└── config.example.toml # 配置示例
```

## 🔧 命令说明

```bash
# 显示帮助
sudo bash main.sh --help

# 执行初始化
sudo bash main.sh init

# 交互式模式
sudo bash main.sh init -i

# 使用自定义配置
sudo bash main.sh init -c my-config.toml

# 列出所有模块
sudo bash main.sh modules

# 单独安装模块
sudo bash main.sh install nginx
sudo bash main.sh install docker

# 生成配置文件
sudo bash main.sh config

# 验证系统环境
sudo bash main.sh install verify

# 修复 dpkg 错误
sudo bash main.sh install fix-dpkg
```

## 📋 模块列表

| 模块 | 分类 | 描述 |
|------|------|------|
| **user** | core | 创建用户账户并生成安全密码 |
| **ssh** | core | 配置 SSH 目录和密钥 |
| **system** | core | 系统更新和基础依赖安装 |
| **firewall** | network | 配置 UFW 防火墙规则 |
| **nginx** | network | 安装并配置 Nginx（支持 SSL 和反向代理） |
| **docker** | runtime | 安装 Docker 和 Docker Compose |
| **swap** | runtime | 配置 Swap 虚拟内存 |
| **security** | tools | 系统安全加固 |
| **p10k** | tools | 安装 Powerlevel10k (zsh 主题) |
| **verify** | tools | 验证系统环境和兼容性 |
| **fix-dpkg** | tools | 修复 dpkg 包管理器错误 |

## 📝 配置文件

```toml
[basic]
username = "endlex"
timezone = "Asia/Shanghai"

[features]
enable_firewall = true
enable_nginx = false
enable_docker = false
enable_swap = false
enable_security = false
enable_p10k = false

[nginx]
domain = ""
enable_ssl = false
proxy_pass = ""
```

## 🎯 使用场景

### 场景 1: 快速初始化新服务器

```bash
ssh root@your-server-ip
git clone https://github.com/yourusername/vpc_init.git
cd vpc_init
sudo bash main.sh init
ssh endlex@your-server-ip
```

### 场景 2: 部署 Web 服务器（Nginx + SSL）

```bash
# 编辑配置
cat > config.toml << 'EOF'
[basic]
username = "webuser"

[features]
enable_nginx = true

[nginx]
domain = "example.com"
enable_ssl = true
EOF

# 执行
sudo bash main.sh init
```

### 场景 3: 部署 Docker 环境

```bash
sudo bash main.sh install docker
```

### 场景 4: 脚本中断后恢复

```bash
# 如果脚本中断，直接重新运行
sudo bash main.sh init
# 会自动提示是否从断点继续
```

## 🔐 安全性

- **随机密码** - 自动生成强随机密码
- **密钥加密** - 凭证文件权限 600，仅 root 可读
- **防火墙** - 自动启用 UFW，默认仅允许 SSH
- **日志记录** - 所有操作记录到 `/var/log/vpc-init/`

## 🐛 故障排除

### 问题 1: macOS 上运行出错

**原因**: macOS 默认 Bash 3.2 不支持关联数组

**解决**:
```bash
# 使用 Zsh
zsh main.sh init

# 或安装新版 Bash
brew install bash
/usr/local/bin/bash main.sh init
```

### 问题 2: 模块执行失败

```bash
# 查看日志
sudo tail -f /var/log/vpc-init/vpc-init-*.log

# 验证系统环境
sudo bash main.sh install verify

# 修复 dpkg 错误
sudo bash main.sh install fix-dpkg
```

### 问题 3: 如何重新开始

```bash
# 清除断点记录
rm -rf .checkpoint/

# 重新运行
sudo bash main.sh init
```

## 📚 更多文档

- **[GUIDE.md](GUIDE.md)** - 详细使用指南
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - 架构说明和扩展指南

## 🔄 更新日志

### v3.0 (2026-02-11)

- ✅ **全新模块化架构** - 功能拆分为独立模块
- ✅ **自动注册机制** - 新模块自动发现
- ✅ **断点续跑** - 支持中断恢复
- ✅ **依赖管理** - 声明式依赖处理
- ✅ **多模式支持** - 配置驱动 + 交互式
- ✅ **macOS 兼容提示** - 版本检测和解决方案

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 或 Pull Request！

---

**最后更新**: 2026-02-11  
**当前版本**: v3.0  
**状态**: 生产就绪 ✅
