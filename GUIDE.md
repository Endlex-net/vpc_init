# vpc_init 完整使用指南

本指南包含所有详细的使用说明、配置选项、高级功能和故障排除信息。

## 目录

1. [安装与基础](#安装与基础)
2. [配置详解](#配置详解)
3. [功能说明](#功能说明)
4. [断点续跑](#断点续跑)
5. [高级用法](#高级用法)
6. [Nginx 配置](#nginx-配置)
7. [故障排除](#故障排除)

---

## 安装与基础

### 获取脚本

```bash
# 方式 1: Clone 仓库
git clone https://github.com/yourusername/vpc_init.git
cd vpc_init

# 方式 2: 直接下载
wget https://github.com/yourusername/vpc_init/archive/main.zip
unzip main.zip
cd vpc_init-main
```

### 基础执行

```bash
# 最简单的方式（使用所有默认值）
sudo bash setup.sh
# 然后选择选项 1

# 使用配置文件
sudo bash setup.sh
# 确保 config.toml 存在，选择选项 1

# 高级配置
sudo bash advanced-config.sh
```

### 执行权限

大多数脚本需要 root 权限，使用 `sudo` 运行：

```bash
# 需要 sudo
sudo bash setup.sh
sudo bash advanced-config.sh
sudo bash manage-user.sh

# 不需要 sudo
bash verify.sh              # 只是验证
bash config.sh              # 只是解析配置
bash checkpoint-manager.sh  # 只是管理检查点
```

---

## 配置详解

### 配置文件格式

所有配置文件使用 TOML 格式。基础结构如下：

```toml
[basic]
username = "endlex"              # 用户名
timezone = "Asia/Shanghai"       # 时区
swap_size = "2G"                 # Swap 大小

[ssh]
keys = ""                        # SSH 公钥（逗号分隔）

[features]
enable_swap = true               # 是否启用 Swap
enable_security = true           # 是否启用安全加固
enable_limits = true             # 是否配置系统限制
enable_docker = false            # 是否安装 Docker
enable_nginx = false             # 是否安装 Nginx
enable_bbr = true                # 是否启用 BBR
enable_p10k = true               # 是否安装 Powerlevel10k

[nginx]
domain = "example.com"           # Nginx 域名
enable_ssl = true                # 是否启用 SSL
proxy_pass = ""                  # 反向代理地址
```

### 自定义配置

```bash
# 1. 复制示例配置
cp config.example.toml config.toml

# 2. 编辑配置文件
vim config.toml

# 3. 运行脚本
sudo bash setup.sh
# 选择选项 1
```

#### 常见配置修改

**修改用户名:**
```toml
[basic]
username = "myusername"
```

**添加 SSH 密钥:**
```toml
[ssh]
keys = "ssh-rsa AAAA..., ssh-rsa BBBB..."
```

**从文件读取 SSH 密钥:**
```toml
[ssh]
keys = "/home/user/.ssh/id_rsa.pub"
```

**启用高级功能:**
```toml
[features]
enable_bbr = true
enable_swap = true
swap_size = "4G"
enable_nginx = true
```

**Nginx 配置:**
```toml
[nginx]
domain = "mywebsite.com"
enable_ssl = true
proxy_pass = "http://localhost:3000"
```

---

## 功能说明

### 1. 用户创建 (setup.sh)

- **功能**: 创建新用户账户并配置权限
- **执行**: `sudo bash setup.sh` → 选项 1
- **结果**:
  - 创建用户（默认 `endlex`）
  - 生成随机密码: `/root/endlex-credentials.txt`
  - 配置 sudo 无密码权限
  - 设置 Home 目录为 `/home/endlex`

```bash
# 查看凭证
sudo cat /root/endlex-credentials.txt
```

### 2. SSH 配置 (setup.sh)

- **功能**: 配置 SSH 免密钥登录
- **执行**: 自动执行
- **配置位置**:
  - SSH 目录: `/home/endlex/.ssh/`
  - 授权密钥: `/home/endlex/.ssh/authorized_keys`

```bash
# 添加 SSH 密钥
cat ~/.ssh/id_rsa.pub | ssh endlex@server 'cat >> ~/.ssh/authorized_keys'

# 使用 manage-user.sh 管理
bash manage-user.sh
```

### 3. 系统更新 (setup.sh)

- **功能**: 更新包列表和安装基础依赖
- **包括**:
  - curl, wget, git
  - build-essential, htop, net-tools
  - vim, nano, openssh-server

### 4. 防火墙配置 (setup.sh)

- **功能**: 启用 UFW 防火墙
- **默认规则**:
  - 允许 SSH (22/tcp)
  - 其他端口默认关闭

```bash
# 查看防火墙状态
sudo ufw status verbose

# 开放端口
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw allow 3306/tcp # MySQL

# 删除规则
sudo ufw delete allow 80/tcp
```

### 5. 时区配置 (setup.sh / advanced-config.sh)

- **默认**: Asia/Shanghai (UTC+8)
- **修改方式**:
  ```toml
  [basic]
  timezone = "America/New_York"  # 或其他时区
  ```

- **验证时区**:
  ```bash
  date
  timedatectl
  ```

### 6. 密码管理 (setup.sh / manage-user.sh)

#### 初始密码

脚本自动创建的初始密码存储在:

```bash
sudo cat /root/endlex-credentials.txt
```

#### 修改密码

```bash
# 方式 1: 初始化时提示
sudo bash setup.sh
# 脚本会提示修改密码

# 方式 2: 使用 manage-user.sh
bash manage-user.sh
# 选择选项修改密码

# 方式 3: 直接使用 passwd
sudo passwd endlex
```

### 7. 日志记录

所有操作记录到:

```bash
# 主日志
/var/log/vpc-init/setup-20260211-154230.log

# 错误日志
/var/log/vpc-init/setup-errors-20260211-154230.log

# 查看日志
sudo tail -f /var/log/vpc-init/setup-*.log

# 统计日志
sudo wc -l /var/log/vpc-init/*.log
```

---

## 断点续跑

### 工作原理

脚本能记录每个成功完成的步骤，当脚本中断后，再次运行时会自动跳过已完成的步骤，从断点位置继续。

### 基本使用

```bash
# 首次运行
sudo bash setup.sh

# 如果脚本中断（Ctrl+C 或网络问题）
# 修复问题后，再次运行
sudo bash setup.sh

# 系统会提示：
# Found previous checkpoint state: setup-20260211-154230.state
# Resume from checkpoint? [Y/n] Y
```

### 查看检查点

```bash
# 列出所有检查点
bash checkpoint-manager.sh list

# 查看检查点状态
bash checkpoint-manager.sh status
```

### 重置检查点

```bash
# 重置所有检查点（需确认）
bash checkpoint-manager.sh reset

# 强制重置（跳过确认）
bash checkpoint-manager.sh reset -y

# 删除特定日期的检查点
bash checkpoint-manager.sh remove-date 20260211-154230 -y
```

### 清理检查点

```bash
# 清理 7 天前的检查点
bash checkpoint-manager.sh clean

# 清理 1 天前的检查点
bash checkpoint-manager.sh clean 1

# 只保留最新 5 个检查点
bash checkpoint-manager.sh keep-latest 5
```

### 完整的断点文档

详见 [CHECKPOINT_GUIDE.md](CHECKPOINT_GUIDE.md)

---

## 高级用法

### 1. 交互式菜单 (setup.sh)

提供友好的菜单界面，适合不熟悉命令行的用户：

```bash
sudo bash setup.sh

# 菜单选项：
# 1) 全部自动初始化（基于配置文件）
# 2) 高级配置（手动选择）
# 3) 管理 SSH 密钥
# 4) 查看日志
# 5) 帮助文档
# 0) 退出
```

### 2. 高级配置菜单

在 setup.sh 中选择选项 2，或使用 advanced-config.sh：

```bash
sudo bash setup.sh
# 选择 2) 高级配置

# 高级配置选项：
# 1) 配置时区
# 2) 设置 Swap
# 3) 安全加固
# 4) 配置系统限制
# 5) 安装 Docker
# 6) 安装并配置 Nginx
# 7) 启用 BBR
# 8) 安装 Powerlevel10k
# 9) 应用所有配置
# 0) 返回主菜单
```

### 3. Nginx 配置子菜单

在高级配置中选择选项 6：

```bash
# Nginx 配置选项：
# 1) 仅安装 Nginx
# 2) 安装 Nginx + 申请 SSL 证书
# 3) 安装 Nginx + 配置反向代理
# 4) 完整配置（Nginx + SSL + 反向代理）
# 0) 返回上级菜单
```

### 4. 用户管理 (manage-user.sh)

管理用户账户和 SSH 密钥：

```bash
bash manage-user.sh

# 选项：
# 1. 添加 SSH 密钥
# 2. 列出 SSH 密钥
# 3. 删除 SSH 密钥
# 4. 重置密码
# 5. 更改 Shell
# 6. 锁定/解锁账户
```

### 5. 系统验证 (verify.sh)

验证系统环境和脚本兼容性：

```bash
bash verify.sh

# 检查：
# - Ubuntu 版本
# - Bash 版本
# - 网络连接
# - 磁盘空间
# - 必要命令可用性
```

### 6. 配置解析 (config.sh)

用于其他脚本解析 TOML 配置文件：

```bash
source config.sh
parse_toml config.toml
get_config "basic:username"      # 输出: endlex
get_config "basic:timezone"      # 输出: Asia/Shanghai
```

---

## Nginx 配置

### 概述

vpc_init 提供完整的 Nginx 安装和配置功能，支持：
- 静态站点托管
- 反向代理
- SSL 证书自动申请（Let's Encrypt）
- 负载均衡
- WebSocket 代理

### 安装方式

#### 方式 1: 使用交互式菜单

```bash
sudo bash setup.sh
# 选择 2) 高级配置
# 选择 6) 安装并配置 Nginx
# 然后根据提示选择配置级别
```

#### 方式 2: 命令行参数

```bash
# 仅安装 Nginx
sudo bash advanced-config.sh --nginx

# 安装 + 静态站点
sudo bash advanced-config.sh --nginx --domain example.com

# 安装 + SSL 证书
sudo bash advanced-config.sh --nginx --domain example.com --ssl

# 安装 + 反向代理
sudo bash advanced-config.sh --nginx --domain api.example.com --proxy http://localhost:3000

# 完整配置
sudo bash advanced-config.sh --nginx --domain example.com --ssl --proxy http://localhost:8080
```

#### 方式 3: 配置文件

```toml
[features]
enable_nginx = true

[nginx]
domain = "example.com"
enable_ssl = true
proxy_pass = "http://localhost:3000"
```

### 配置详解

#### 静态站点配置

Nginx 将创建一个静态站点，默认页面位于 `/var/www/example.com/index.html`。

```bash
sudo bash advanced-config.sh --nginx --domain example.com
```

#### SSL 证书配置

自动申请 Let's Encrypt 免费 SSL 证书，并设置自动续期。

```bash
sudo bash advanced-config.sh --nginx --domain example.com --ssl
```

**注意**: 申请 SSL 证书前，请确保域名已正确解析到服务器 IP。

#### 反向代理配置

将请求转发到后端服务（如 Node.js、Python、Java 应用）。

```bash
sudo bash advanced-config.sh --nginx --domain api.example.com --proxy http://localhost:3000
```

生成的配置包括：
- WebSocket 支持
- 静态文件缓存
- 超时设置
- 真实 IP 转发

#### 完整配置示例

```bash
# Web 服务器（静态 + SSL）
sudo bash advanced-config.sh --nginx --domain www.example.com --ssl

# API 服务器（反向代理 + SSL）
sudo bash advanced-config.sh --nginx --domain api.example.com --ssl --proxy http://localhost:8080

# 微服务（WebSocket + SSL）
sudo bash advanced-config.sh --nginx --domain ws.example.com --ssl --proxy http://localhost:3001
```

### Nginx 管理命令

```bash
# 查看状态
sudo systemctl status nginx

# 启动/停止/重启
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx

# 测试配置
sudo nginx -t

# 查看访问日志
sudo tail -f /var/log/nginx/access.log

# 查看错误日志
sudo tail -f /var/log/nginx/error.log
```

### SSL 证书管理

```bash
# 查看证书
sudo certbot certificates

# 测试续期
sudo certbot renew --dry-run

# 手动续期
sudo certbot renew

# 删除证书
sudo certbot delete --cert-name example.com
```

### 配置文件位置

```
/etc/nginx/
├── nginx.conf              # 主配置文件
├── sites-available/        # 可用站点配置
│   ├── example.com        # 你的站点配置
│   └── default            # 默认配置
├── sites-enabled/          # 启用站点（软链接）
│   └── example.com -> ../sites-available/example.com
└── snippets/              # 配置片段
```

---

## 故障排除

### 问题 1: "Permission denied" 错误

**原因**: 脚本需要 root 权限

**解决**:
```bash
sudo bash setup.sh
```

### 问题 2: 找不到 config.sh

**原因**: checkpoint.sh 无法加载配置库

**解决**:
```bash
# 确保在脚本目录运行
cd /path/to/vpc_init
sudo bash setup.sh
```

### 问题 3: UFW 启用失败

**原因**: 系统未安装 ufw 或已启用

**解决**:
```bash
# 安装 ufw
sudo apt-get install ufw

# 查看状态
sudo ufw status

# 重新运行脚本
bash checkpoint-manager.sh reset -y
sudo bash setup.sh
```

### 问题 4: 用户已存在

**原因**: 用户 `endlex` 已被创建

**解决**:
```bash
# 方式 1: 使用不同的用户名（编辑配置文件）
vim config.toml
# 修改 username = "myuser"
sudo bash setup.sh

# 方式 2: 删除现有用户
sudo userdel -r endlex
bash checkpoint-manager.sh reset -y
sudo bash setup.sh
```

### 问题 5: 包安装失败

**原因**: 网络问题或包源不可用

**解决**:
```bash
# 方式 1: 更新包源
sudo apt-get update
sudo apt-get upgrade

# 方式 2: 从检查点恢复
bash checkpoint-manager.sh reset -y
sudo bash setup.sh

# 方式 3: 查看详细日志
sudo tail -100 /var/log/vpc-init/setup-errors-*.log
```

### 问题 6: 如何强制重新开始

**场景**: 需要重新运行所有步骤

**解决**:
```bash
# 方式 1: 删除检查点目录
rm -rf .vpc-init-checkpoint/
sudo bash setup.sh

# 方式 2: 使用管理工具
bash checkpoint-manager.sh reset -y
sudo bash setup.sh
```

### 问题 7: SSH 无法连接

**原因**: SSH 配置未正确应用

**解决**:
```bash
# 查看 SSH 状态
sudo systemctl status ssh

# 重启 SSH 服务
sudo systemctl restart ssh

# 测试连接
ssh -v endlex@your-server-ip

# 查看授权密钥
sudo cat /home/endlex/.ssh/authorized_keys
```

### 问题 8: 日志查看不到内容

**原因**: 日志文件权限问题

**解决**:
```bash
# 查看日志
sudo tail -100 /var/log/vpc-init/setup-*.log

# 检查权限
ls -la /var/log/vpc-init/

# 重新初始化日志目录
sudo mkdir -p /var/log/vpc-init
sudo chmod 755 /var/log/vpc-init
```

### 问题 9: Nginx 配置测试失败

**原因**: 配置文件语法错误或端口冲突

**解决**:
```bash
# 测试配置
sudo nginx -t

# 查看错误详情
sudo tail -50 /var/log/nginx/error.log

# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# 重启 Nginx
sudo systemctl restart nginx
```

### 问题 10: SSL 证书申请失败

**原因**: 域名未解析或防火墙阻挡

**解决**:
```bash
# 检查域名解析
dig example.com
ping example.com

# 确保 80 端口开放
sudo ufw allow 80/tcp

# 手动申请证书
sudo certbot --nginx -d example.com
```

---

## 常用命令速查

```bash
# 执行脚本
sudo bash setup.sh                          # 启动菜单
sudo bash advanced-config.sh               # 高级配置
sudo bash advanced-config.sh --nginx --domain example.com --ssl

# 管理工具
bash manage-user.sh                        # 用户管理
bash checkpoint-manager.sh list            # 查看检查点
bash checkpoint-manager.sh reset -y        # 重置检查点
bash verify.sh                             # 系统验证
bash fix-dpkg.sh                           # 修复 dpkg

# 系统操作
sudo tail -f /var/log/vpc-init/setup-*.log # 查看日志
sudo cat /root/endlex-credentials.txt      # 查看凭证
sudo ufw status                            # 查看防火墙
sudo passwd endlex                         # 修改密码

# Nginx 操作
sudo systemctl status nginx                # Nginx 状态
sudo nginx -t                              # 测试配置
sudo tail -f /var/log/nginx/access.log     # 访问日志
sudo certbot certificates                  # 查看证书

# SSH 操作
ssh endlex@your-server-ip                  # 连接服务器
ssh-copy-id -i ~/.ssh/id_rsa endlex@server # 复制 SSH 密钥
```

---

## 最佳实践

1. **总是使用配置文件** - 方便重复使用和版本控制
2. **定期清理检查点** - `bash checkpoint-manager.sh clean`
3. **备份凭证文件** - `sudo cp /root/endlex-credentials.txt safe-location/`
4. **查看日志** - 遇到问题时先查看日志文件
5. **测试连接** - 初始化后立即测试 SSH 连接
6. **强化安全** - 完成后立即修改密码和配置防火墙
7. **定期更新** - `sudo apt-get update && sudo apt-get upgrade`
8. **Nginx 安全** - 使用 SSL 证书，配置安全头
9. **监控资源** - 使用 htop、df -h 监控服务器资源
10. **备份配置** - 定期备份 config.toml 和 Nginx 配置

---

**更新日期**: 2026-02-11  
**文档版本**: 2.0  
**状态**: 最新
