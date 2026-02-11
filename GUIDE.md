# VPC_INIT 使用指南 v3.0

本指南包含 VPC_INIT v3.0 的详细使用说明、配置选项和故障排除。

## 目录

1. [快速开始](#快速开始)
2. [命令详解](#命令详解)
3. [模块系统](#模块系统)
4. [配置说明](#配置说明)
5. [故障排除](#故障排除)
6. [扩展开发](#扩展开发)

---

## 快速开始

### 安装

```bash
git clone https://github.com/yourusername/vpc_init.git
cd vpc_init
```

### 基础使用

```bash
# 基础初始化（执行默认模块）
sudo bash main.sh init

# 交互式选择模块
sudo bash main.sh init -i

# 生成并编辑配置文件
sudo bash main.sh config
vim config.toml
sudo bash main.sh init
```

---

## 命令详解

### `main.sh init` - 执行初始化

执行模块初始化，支持多种模式：

```bash
# 基础模式（执行默认核心模块）
sudo bash main.sh init

# 交互式模式（手动选择模块）
sudo bash main.sh init -i

# 使用自定义配置
sudo bash main.sh init -c my-config.toml

# 详细输出
sudo bash main.sh init -v
```

### `main.sh modules` - 列出模块

显示所有可用的模块及其状态：

```bash
sudo bash main.sh modules
```

输出示例：
```
[core]
  user                 创建用户账户并生成安全密码
  ssh                  配置 SSH 目录和密钥
  system               系统更新和基础依赖安装

[network]
  firewall             配置 UFW 防火墙规则
  nginx                安装并配置 Nginx

[runtime]
  docker               安装 Docker 和 Docker Compose
  swap                 配置 Swap 虚拟内存
```

### `main.sh install <模块>` - 安装单个模块

单独执行某个模块：

```bash
# 安装 Nginx
sudo bash main.sh install nginx

# 安装 Docker
sudo bash main.sh install docker

# 验证系统
sudo bash main.sh install verify

# 修复 dpkg
sudo bash main.sh install fix-dpkg
```

### `main.sh config` - 生成配置文件

生成默认配置文件：

```bash
sudo bash main.sh config
# 生成 config.toml

sudo bash main.sh config my-config.toml
# 生成指定名称的配置文件
```

---

## 模块系统

### 模块分类

模块按功能分为四个分类：

| 分类 | 代码 | 说明 | 优先级 |
|------|------|------|--------|
| core | 00-core | 核心功能，必须执行 | 10 |
| network | 10-network | 网络相关 | 20 |
| runtime | 20-runtime | 运行环境 | 30 |
| tools | 30-tools | 工具软件 | 40 |

### 核心模块 (00-core)

#### user 模块

创建用户账户并配置密码。

**配置项**:
```toml
[basic]
username = "endlex"  # 用户名
```

**执行**:
```bash
sudo bash main.sh install user
```

**输出**:
- 创建用户账户
- 生成随机密码
- 保存凭证到 `/root/<username>-credentials.txt`

#### ssh 模块

配置 SSH 目录和密钥。

**配置项**:
```toml
[ssh]
keys = "ssh-rsa AAAA..., /path/to/key.pub"
```

**功能**:
- 创建 `~/.ssh` 目录
- 设置正确权限
- 添加 SSH 公钥

#### system 模块

系统更新和基础依赖安装。

**功能**:
- 更新软件包列表
- 安装基础依赖（curl, wget, git, vim 等）
- 配置时区

### 网络模块 (10-network)

#### firewall 模块

配置 UFW 防火墙。

**功能**:
- 安装 UFW（如未安装）
- 默认拒绝入站，允许出站
- 允许 SSH (22)
- 如启用 Nginx，自动开放 80/443

#### nginx 模块

安装并配置 Nginx。

**配置项**:
```toml
[features]
enable_nginx = true

[nginx]
domain = "example.com"          # 域名
enable_ssl = true               # 启用 SSL
proxy_pass = ""                 # 反向代理地址
```

**功能**:
- 安装 Nginx
- 配置站点
- 自动申请 Let's Encrypt SSL 证书
- 支持反向代理

### 运行环境模块 (20-runtime)

#### docker 模块

安装 Docker。

**功能**:
- 安装 Docker CE
- 安装 Docker Compose
- 将用户添加到 docker 组

#### swap 模块

配置 Swap 虚拟内存。

**配置项**:
```toml
[basic]
swap_size = "2G"  # Swap 大小
```

### 工具模块 (30-tools)

#### security 模块

系统安全加固。

**功能**:
- 禁用 root SSH 登录
- 禁用空密码
- 配置系统限制
- 禁用不必要的服务

#### p10k 模块

安装 Powerlevel10k (zsh 主题)。

**功能**:
- 安装 zsh
- 安装 Oh My Zsh
- 安装 Powerlevel10k 主题
- 配置默认 shell

#### verify 模块

验证系统环境。

**检查项**:
- 操作系统版本
- root 权限
- 网络连接
- 磁盘空间
- 内存大小

#### fix-dpkg 模块

修复 dpkg 错误。

**修复步骤**:
1. 清理损坏的状态文件
2. 配置未完成的包
3. 修复依赖关系
4. 清理 apt 缓存
5. 更新包列表

---

## 配置说明

### 配置文件格式

使用 TOML 格式：

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

### 配置项说明

#### [basic] 基础配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| username | endlex | 要创建的用户名 |
| timezone | Asia/Shanghai | 系统时区 |

#### [features] 功能开关

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| enable_firewall | true | 启用防火墙 |
| enable_nginx | false | 安装 Nginx |
| enable_docker | false | 安装 Docker |
| enable_swap | false | 配置 Swap |
| enable_security | false | 安全加固 |
| enable_p10k | false | 安装 Powerlevel10k |

#### [nginx] Nginx 配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| domain | "" | 域名 |
| enable_ssl | false | 启用 SSL |
| proxy_pass | "" | 反向代理后端地址 |

### 配置示例

#### 最小化配置

```toml
[basic]
username = "user"
```

#### Web 服务器

```toml
[basic]
username = "webuser"

[features]
enable_nginx = true

[nginx]
domain = "example.com"
enable_ssl = true
```

#### Docker 开发环境

```toml
[basic]
username = "devuser"

[features]
enable_docker = true
enable_swap = true
```

---

## 故障排除

### 问题 1: macOS 上无法运行

**错误信息**:
```
错误: 需要 Bash 4.0+（支持关联数组）
```

**解决**:
```bash
# 使用 Zsh
zsh main.sh init

# 或安装新版 Bash
brew install bash
/usr/local/bin/bash main.sh init
```

### 问题 2: 模块执行失败

**诊断**:
```bash
# 查看日志
sudo tail -f /var/log/vpc-init/vpc-init-*.log

# 验证系统
sudo bash main.sh install verify

# 修复 dpkg
sudo bash main.sh install fix-dpkg
```

### 问题 3: 脚本中断后如何恢复

**解决**:
```bash
# 直接重新运行，会自动提示是否从断点继续
sudo bash main.sh init
```

### 问题 4: 如何重新开始

**解决**:
```bash
# 清除断点记录
rm -rf .checkpoint/

# 重新运行
sudo bash main.sh init
```

### 问题 5: Nginx SSL 证书申请失败

**原因**: 域名未解析或防火墙阻挡

**解决**:
```bash
# 检查域名解析
dig example.com

# 确保 80 端口开放
sudo ufw allow 80/tcp

# 手动申请
sudo certbot --nginx -d example.com
```

---

## 扩展开发

### 添加新模块

1. **创建模块文件**

```bash
touch modules/40-custom/myapp.sh
```

2. **编写模块代码**

```bash
#!/bin/bash

################################################################################
# 模块: myapp
# 分类: custom
# 描述: 我的自定义应用
# @category: custom
# @description: 安装和配置 MyApp
################################################################################

# 检查函数
myapp_check() {
    if command -v myapp &>/dev/null; then
        print_info "MyApp 已安装"
        return 1  # 已安装，跳过
    fi
    return 0
}

# 执行函数
myapp_execute() {
    print_header "安装 MyApp"
    
    print_status "下载 MyApp..."
    # 安装代码
    
    print_success "MyApp 安装完成"
    return 0
}

# 注册模块
register_module \
    --name "myapp" \
    --category "custom" \
    --description "安装和配置 MyApp"
```

3. **使用新模块**

```bash
# 单独安装
sudo bash main.sh install myapp

# 或在配置中启用
# [features]
# enable_myapp = true
```

### 模块最佳实践

1. **函数命名**: `<module>_check` 和 `<module>_execute`
2. **返回值**: `check` 函数返回 0 执行，1 跳过
3. **错误处理**: 使用 `error_exit` 处理严重错误
4. **日志记录**: 使用 `log` 和 `print_*` 函数
5. **用户交互**: 使用 `confirm` 函数获取确认

---

## 常见问题

**Q: 如何查看已安装的模块？**

A: 运行 `sudo bash main.sh modules`

**Q: 如何只安装特定模块？**

A: 使用 `sudo bash main.sh install <模块名>`

**Q: 如何禁用某个模块？**

A: 在配置文件中设置 `enable_<模块> = false`

**Q: 如何添加自定义模块？**

A: 在 `modules/` 目录下创建新文件，调用 `register_module` 注册

**Q: 日志文件在哪里？**

A: `/var/log/vpc-init/vpc-init-*.log`

---

**更新日期**: 2026-02-11  
**文档版本**: v3.0
