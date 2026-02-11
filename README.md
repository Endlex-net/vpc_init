# vpc_init - Ubuntu 服务器初始化工具

快速自动化配置新购 Ubuntu 服务器的完整工具包。一条命令即可完成用户创建、SSH 配置、系统更新、防火墙设置等初始化工作。

## 🚀 快速开始

### 最简单的方式 (10 秒)

```bash
sudo bash setup.sh
# 然后选择选项 1: 全部自动初始化
```

### 使用配置文件 (30 秒)

```bash
# 1. 复制配置文件示例
cp config.example.toml config.toml

# 2. 编辑配置（可选）
vim config.toml

# 3. 运行初始化
sudo bash setup.sh
# 选择选项 1，会自动读取 config.toml
```

### 交互式菜单 (5 分钟)

```bash
sudo bash setup.sh
```

## ✨ 主要功能

| 功能 | 说明 | 位置 |
|------|------|------|
| **用户创建** | 创建用户并生成安全随机密码 | setup.sh |
| **SSH 配置** | 配置 SSH 密钥登录 | setup.sh |
| **系统更新** | 更新包列表和安装基础依赖 | setup.sh |
| **防火墙** | 启用 UFW 防火墙 | setup.sh |
| **时区配置** | 设置系统时区 | setup.sh, advanced-config.sh |
| **断点续跑** | 中断后可从断点继续 | setup.sh + checkpoint.sh |
| **密码管理** | 管理 SSH 密钥和用户密码 | manage-user.sh |
| **高级配置** | BBR 加速、Swap、Docker、Nginx 等 | advanced-config.sh |

## 📂 项目结构

```
vpc_init/
├── 📜 脚本文件
│   ├── setup.sh                   ⭐ 主初始化脚本（交互式菜单）
│   ├── advanced-config.sh         高级配置工具（时区、Swap、Docker、Nginx 等）
│   ├── config.sh                  TOML 配置解析器
│   ├── verify.sh                  系统验证工具
│   ├── checkpoint.sh              断点续跑库
│   ├── checkpoint-manager.sh      断点管理工具
│   └── manage-user.sh             用户管理工具
│
├── 📋 配置文件
│   └── config.example.toml        完整配置示例
│
└── 📚 文档文件
    ├── README.md                  本文件（项目概述）
    ├── GUIDE.md                   完整使用指南
    ├── REFERENCE.md               API 参考与重要细节
    ├── CHECKPOINT_GUIDE.md        断点续跑详细说明
    └── DPKG_FIX_GUIDE.md          系统问题修复指南
```

## 🔧 配置方式

### 方式 1: 使用配置文件

```bash
# 1. 复制示例配置
cp config.example.toml config.toml

# 2. 编辑配置文件
vim config.toml

# 3. 运行初始化
sudo bash setup.sh
# 选择选项 1: 全部自动初始化
```

### 方式 2: 直接运行（使用默认值）

```bash
sudo bash setup.sh
# 选择选项 1，将使用默认配置
```

## 🎯 使用场景

### 场景 1: 首次初始化新服务器

```bash
# 1. 登录新服务器（通常是 root）
ssh root@your-server-ip

# 2. 下载脚本
git clone https://github.com/yourusername/vpc_init.git
cd vpc_init

# 3. 复制并编辑配置（可选）
cp config.example.toml config.toml
vim config.toml

# 4. 运行初始化
sudo bash setup.sh

# 5. 用新用户登录
ssh endlex@your-server-ip
```

### 场景 2: 脚本执行中断后恢复

```bash
# 直接重新运行，自动从断点继续
sudo bash setup.sh

# 系统会提示是否从上次的检查点恢复
# Found previous checkpoint state: setup-20260211-154230.state
# Resume from checkpoint? [Y/n] Y
```

### 场景 3: 安装 Nginx 并配置 Web 服务器

```bash
# 方式 1: 使用菜单
sudo bash setup.sh
# 选择 2) 高级配置 → 6) 安装并配置 Nginx

# 方式 2: 命令行直接安装
sudo bash advanced-config.sh --nginx --domain example.com --ssl

# 方式 3: 在配置文件中启用
echo 'enable_nginx = true' >> config.toml
sudo bash setup.sh
```

### 场景 4: 清理旧检查点

```bash
# 查看所有检查点
bash checkpoint-manager.sh list

# 清理 7 天前的检查点
bash checkpoint-manager.sh clean

# 重置所有检查点
bash checkpoint-manager.sh reset -y
```

## 📝 常用命令

```bash
# 启动交互式菜单
sudo bash setup.sh

# 验证系统环境
bash verify.sh

# 管理用户和 SSH 密钥
bash manage-user.sh

# 高级配置（BBR、Swap、Docker、Nginx 等）
sudo bash advanced-config.sh

# 查看初始化日志
sudo tail -f /var/log/vpc-init/setup-*.log

# 管理检查点
bash checkpoint-manager.sh help

# 修复 dpkg 问题
sudo bash fix-dpkg.sh
```

## 🌐 Nginx 配置示例

### 安装 Nginx（静态站点）

```bash
sudo bash advanced-config.sh --nginx --domain example.com
```

### 安装 Nginx + SSL 证书

```bash
sudo bash advanced-config.sh --nginx --domain example.com --ssl
```

### 安装 Nginx + 反向代理

```bash
sudo bash advanced-config.sh --nginx --domain api.example.com --proxy http://localhost:3000
```

### 完整配置（Nginx + SSL + 反向代理）

```bash
sudo bash advanced-config.sh --nginx --domain example.com --ssl --proxy http://localhost:8080
```

## 🔐 安全性

- **随机密码**: 用户创建时自动生成强随机密码，存储在 `/root/endlex-credentials.txt`
- **密钥加密**: 凭证文件权限设置为 600，仅 root 可读
- **Sudo 权限**: 配置为 NOPASSWD，仅在初始化阶段使用
- **防火墙**: 自动启用 UFW，仅允许 SSH 访问
- **日志记录**: 所有操作记录到 `/var/log/vpc-init/` 目录

**强烈建议**:
1. 初始化完成后立即修改密码
2. 为生产环境配置更强的防火墙规则
3. 定期审查和更新 SSH 密钥

## 🐛 故障排除

### 常见问题

**Q: 脚本执行失败，如何重新开始？**

```bash
# 方式 1: 删除检查点，完全重新开始
bash checkpoint-manager.sh reset -y
sudo bash setup.sh

# 方式 2: 查看错误日志
sudo tail -100 /var/log/vpc-init/setup-errors-*.log

# 方式 3: 手动修复后继续
# 修复问题，重新运行脚本，自动从断点继续
```

**Q: 如何添加新的 SSH 密钥？**

```bash
# 方式 1: 使用管理脚本
bash manage-user.sh
# 选择选项 1: "添加 SSH 密钥"

# 方式 2: 直接添加
cat ~/.ssh/id_rsa.pub | ssh endlex@server 'cat >> ~/.ssh/authorized_keys'
```

**Q: 如何修改用户密码？**

```bash
# 方式 1: 使用 manage-user.sh
bash manage-user.sh

# 方式 2: 直接使用 passwd
sudo passwd endlex
```

**Q: 脚本需要什么权限？**

A: 大部分脚本需要 root 权限，使用 `sudo` 运行。

**Q: dpkg 被中断错误怎么办？**

```bash
# 运行修复脚本
sudo bash fix-dpkg.sh

# 或手动修复
sudo dpkg --configure -a
sudo apt-get install -f -y
sudo apt-get update
```

## 📋 系统要求

- Ubuntu 20.04 LTS 或更高版本
- Root 或 sudo 权限
- 网络连接（用于下载包）
- 磁盘空间 >= 500MB

## 📚 更多文档

- **[GUIDE.md](GUIDE.md)** - 完整使用指南，包括所有功能详解、配置选项、高级用法
- **[REFERENCE.md](REFERENCE.md)** - API 参考、脚本函数列表、环境变量、故障诊断
- **[CHECKPOINT_GUIDE.md](CHECKPOINT_GUIDE.md)** - 断点续跑功能详细说明
- **[DPKG_FIX_GUIDE.md](DPKG_FIX_GUIDE.md)** - dpkg 问题修复指南

## 🔄 更新日志

### v2.0 (2026-02-11)

- ✅ **重大重构**: 整合 init.sh 到 setup.sh，简化项目结构
- ✅ **菜单优化**: 重新设计交互式菜单，更简洁易用
- ✅ **新增功能**: 完整 Nginx 安装和配置支持
  - 支持静态站点配置
  - 支持自动申请 Let's Encrypt SSL 证书
  - 支持反向代理配置
  - 支持负载均衡配置
- ✅ **完全汉化**: advanced-config.sh 所有输出改为中文
- ✅ **配置增强**: config.example.toml 新增 nginx 配置段
- ✅ **文档更新**: 全面更新 README、GUIDE、REFERENCE 文档

### v1.2 (2026-02-10)

- ✅ 添加断点续跑功能（可从中断处继续执行）
- ✅ 新增 checkpoint.sh 库和 checkpoint-manager.sh 工具
- ✅ 改进 init.sh 支持检查点保存
- ✅ 添加密码修改交互功能
- ✅ 重新整理文档，精简为 5 个核心文件

### v1.1 (2026-02-09)

- 修复 init.sh 中的 prev_arg 初始化问题
- 修复 configure_timezone 函数硬编码时区问题
- 改进 TOML 配置解析器
- 添加跨平台兼容性

### v1.0 (初始版本)

- 核心初始化功能
- 配置文件支持
- 基础文档

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 或 Pull Request 来改进此项目。

## 📞 支持

- 📖 查看文档: 本文件及 GUIDE.md、REFERENCE.md
- 🔍 查看日志: `sudo tail -f /var/log/vpc-init/setup-*.log`
- 💾 备份配置: `cp config.example.toml config.backup.toml`
- 🔄 恢复检查点: `bash checkpoint-manager.sh list`

---

**最后更新**: 2026-02-11  
**当前版本**: 2.0  
**状态**: 生产就绪 ✅
