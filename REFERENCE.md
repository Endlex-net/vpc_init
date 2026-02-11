# vpc_init API 参考与重要细节

本文档提供脚本 API、函数列表、环境变量和重要配置细节。

## 目录

1. [setup.sh API](#setupsh-api)
2. [advanced-config.sh API](#advanced-configsh-api)
3. [config.sh API](#configsh-api)
4. [checkpoint.sh API](#checkpointsh-api)
5. [环境变量](#环境变量)
6. [配置选项速查](#配置选项速查)
7. [重要路径](#重要路径)

---

## setup.sh API

### 主要函数

#### 用户管理

```bash
# 创建用户账户
create_user()

# 配置 sudo 权限
setup_sudo()

# 提示修改密码
prompt_change_password()

# 生成随机密码
generate_password()
```

#### SSH 配置

```bash
# 设置 SSH 目录和权限
setup_ssh()

# 配置 SSH 服务器
setup_ssh_config()

# 添加 SSH 公钥
add_ssh_key <public_key>
```

#### 系统配置

```bash
# 更新系统包列表
update_system()

# 安装基础依赖
install_dependencies()

# 配置防火墙
configure_firewall()

# 配置主机名
configure_hostname()

# 配置时区
configure_timezone <timezone>
```

#### 配置处理

```bash
# 加载配置文件
load_config <config_file>

# 自动初始化流程
auto_setup()
```

#### 验证函数

```bash
# 验证 root 权限
check_root()

# 验证 Ubuntu 系统
check_ubuntu()

# 验证 dpkg 状态
check_dpkg()

# 验证 swap 大小格式
validate_swap_size <size>

# 验证时区
validate_timezone <timezone>

# 验证用户名
validate_username <username>
```

#### 工具函数

```bash
# 初始化日志
init_logging()

# 记录日志
log <level> <message>

# 打印状态消息
print_status <message>

# 打印成功消息
print_success <message>

# 打印警告消息
print_warning <message>

# 打印信息消息
print_info <message>

# 打印标题
print_header <title>

# 打印菜单
print_menu()

# 打印总结
print_summary()

# 错误退出
error_exit <message> [exit_code]
```

#### 菜单函数

```bash
# 高级配置菜单
advanced_config_menu()

# Nginx 配置子菜单
advanced_nginx_menu()

# SSH 密钥管理菜单
manage_ssh_menu()

# 日志查看菜单
view_logs_menu()

# 显示帮助
show_help()
```

### 配置变量

```bash
# 脚本位置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 日志位置
LOG_DIR="/var/log/vpc-init"
LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="${LOG_DIR}/setup-errors-$(date +%Y%m%d-%H%M%S).log"

# 用户配置
USERNAME="endlex"                          # 默认用户名
TIMEZONE="Asia/Shanghai"                   # 默认时区
SSH_KEYS=""                                # SSH 密钥
CONFIG_FILE=""                             # 配置文件路径
```

### 返回值

```bash
# 成功: 返回 0
create_user && echo "Success"

# 失败: 返回非 0
! install_dependencies && echo "Failed"
```

---

## advanced-config.sh API

### 系统配置函数

```bash
# 配置时区
configure_timezone <timezone>

# 设置 Swap
setup_swap <size>

# 安全加固
security_hardening()

# 配置系统限制
setup_limits()
```

### 软件安装函数

```bash
# 安装 Docker
install_docker()

# 启用 BBR
enable_bbr()

# 安装 Powerlevel10k
install_p10k()
```

### Nginx 函数（新增）

```bash
# 安装 Nginx
install_nginx()

# 配置 Nginx 站点
configure_nginx_site <domain> [enable_ssl] [backend]

# 设置 SSL 证书
setup_ssl <domain>

# Nginx 完整配置流程
nginx_full_setup()
```

### Nginx 变量

```bash
# Nginx 域名
NGINX_DOMAIN=""

# 是否启用 SSL
NGINX_ENABLE_SSL=false

# 反向代理后端地址
NGINX_BACKEND=""
```

### 使用示例

```bash
#!/bin/bash

source advanced-config.sh

# 配置时区
configure_timezone "Asia/Shanghai"

# 设置 Swap
setup_swap "2G"

# 安装 Nginx 并配置站点
NGINX_DOMAIN="example.com"
NGINX_ENABLE_SSL=true
NGINX_BACKEND="http://localhost:3000"
nginx_full_setup
```

---

## config.sh API

配置解析库，用于读取 TOML 配置文件。

### 主要函数

```bash
# 解析 TOML 文件
parse_toml <config_file>

# 获取配置值
get_config <key> [default_value]

# 从指定 section 获取配置
get_config_section <section> <key> [default_value]

# 验证配置
validate_config()

# 打印配置值
print_config()

# 检查配置键是否存在
config_exists <key>

# 获取所有带前缀的键
get_config_keys <prefix>
```

### 使用示例

```bash
#!/bin/bash

# 加载配置库
source config.sh

# 解析配置文件
parse_toml config.toml || exit 1

# 验证配置
validate_config || exit 1

# 读取配置值
username=$(get_config "basic:username" "defaultuser")
timezone=$(get_config "basic:timezone" "UTC")
enable_bbr=$(get_config "features:enable_bbr" "false")

# 打印所有配置
print_config
```

### 配置键格式

配置键使用 `section:key` 格式：

```toml
# TOML 文件
[basic]
username = "endlex"
timezone = "Asia/Shanghai"
swap_size = "2G"

[ssh]
keys = "ssh-rsa AAAA..."

[features]
enable_bbr = true
enable_nginx = true

[nginx]
domain = "example.com"
enable_ssl = true
proxy_pass = "http://localhost:3000"
```

对应的键：

```bash
get_config "basic:username"        # "endlex"
get_config "basic:timezone"        # "Asia/Shanghai"
get_config "basic:swap_size"       # "2G"
get_config "ssh:keys"              # "ssh-rsa AAAA..."
get_config "features:enable_bbr"   # "true"
get_config "features:enable_nginx" # "true"
get_config "nginx:domain"          # "example.com"
get_config "nginx:enable_ssl"      # "true"
get_config "nginx:proxy_pass"      # "http://localhost:3000"
```

---

## checkpoint.sh API

断点续跑库，用于保存和恢复脚本执行状态。

### 核心函数

```bash
# 初始化检查点系统
init_checkpoint_system()

# 标记检查点为已完成
checkpoint_mark <checkpoint_name> [description]

# 检查点是否已完成
checkpoint_exists <checkpoint_name>

# 执行函数并自动检查点
checkpoint_execute <checkpoint_name> <function_name> [args...]

# 手动跳过检查点
checkpoint_skip <checkpoint_name> [reason]
```

### 查询函数

```bash
# 列出所有检查点
checkpoint_list [pattern]

# 获取检查点数量
checkpoint_count [pattern]

# 获取最新的检查点文件
checkpoint_get_latest()
```

### 管理函数

```bash
# 重置检查点
checkpoint_reset [pattern] [-y|--yes]

# 清理旧检查点
checkpoint_cleanup [days]

# 按日期删除检查点
checkpoint_remove_by_date <date> [-y|--yes]

# 只保留最新 N 个检查点
checkpoint_keep_latest [count]
```

### 输出函数

```bash
# 打印跳过消息
print_checkpoint_skipped <checkpoint_name>

# 打印标记消息
print_checkpoint_marked <checkpoint_name>

# 打印状态
print_checkpoint_status()
```

### 使用示例

```bash
#!/bin/bash

source checkpoint.sh

# 初始化
export CHECKPOINT_DIR=".vpc-init-checkpoint"
init_checkpoint_system

# 检查并执行
if ! checkpoint_exists "my_task"; then
    my_function arg1 arg2
    checkpoint_mark "my_task"
else
    echo "Already done"
fi

# 或者使用 checkpoint_execute
checkpoint_execute "my_task" my_function arg1 arg2
```

---

## 环境变量

### 关键变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SCRIPT_DIR` | 自动 | 脚本所在目录 |
| `CHECKPOINT_DIR` | `.vpc-init-checkpoint` | 检查点存储目录 |
| `USERNAME` | `endlex` | 创建的用户名 |
| `TIMEZONE` | `Asia/Shanghai` | 系统时区 |
| `LOG_DIR` | `/var/log/vpc-init` | 日志目录 |
| `NGINX_DOMAIN` | `""` | Nginx 域名 |
| `NGINX_ENABLE_SSL` | `false` | 是否启用 SSL |
| `NGINX_BACKEND` | `""` | 反向代理后端地址 |

### 自定义环境变量

```bash
# 使用自定义用户名
USERNAME=myuser sudo bash setup.sh

# 使用自定义时区
TIMEZONE=America/New_York sudo bash setup.sh

# 使用自定义检查点目录
CHECKPOINT_DIR=/tmp/checkpoints sudo bash setup.sh

# 组合使用
USERNAME=alice TIMEZONE=Europe/London CHECKPOINT_DIR=/var/checkpoints \
    sudo bash setup.sh
```

---

## 配置选项速查

### 基础配置 [basic]

```toml
[basic]
username = "endlex"              # 用户名（默认: endlex）
timezone = "Asia/Shanghai"       # 时区（默认: Asia/Shanghai）
swap_size = "2G"                 # Swap 大小（默认: 2G）
```

**时区示例**:
- `Asia/Shanghai` - 北京时间 (UTC+8)
- `Asia/Tokyo` - 日本时间 (UTC+9)
- `America/New_York` - 纽约 (UTC-5)
- `Europe/London` - 伦敦 (UTC+0)
- `Australia/Sydney` - 悉尼 (UTC+10)

### SSH 配置 [ssh]

```toml
[ssh]
keys = ""  # 逗号分隔的 SSH 公钥或文件路径
```

**示例**:
```toml
# 直接指定公钥
keys = "ssh-rsa AAAAB3NzaC1y..., ssh-rsa AAAAC5XfH9k..."

# 从文件读取
keys = "/home/user/.ssh/id_rsa.pub"

# 多个文件
keys = "/home/user/.ssh/id_rsa.pub, /home/user/.ssh/id_ed25519.pub"
```

### 功能开关 [features]

```toml
[features]
enable_swap = true          # 启用 Swap
enable_security = true      # 启用安全加固
enable_limits = true        # 启用系统限制配置
enable_docker = false       # 安装 Docker
enable_nginx = false        # 安装 Nginx
enable_bbr = true           # 启用 BBR TCP 加速
enable_p10k = true          # 安装 Powerlevel10k
```

### Nginx 配置 [nginx]

```toml
[nginx]
domain = "example.com"           # 主域名
enable_ssl = true                # 启用 SSL 证书
proxy_pass = ""                  # 反向代理地址（可选）
enable_www = true                # 启用 www 子域名
```

**配置示例**:

```toml
# 静态站点
[nginx]
domain = "www.example.com"
enable_ssl = true
proxy_pass = ""

# 反向代理（API 服务器）
[nginx]
domain = "api.example.com"
enable_ssl = true
proxy_pass = "http://localhost:3000"

# WebSocket 服务
[nginx]
domain = "ws.example.com"
enable_ssl = true
proxy_pass = "http://localhost:3001"
```

### 软件包 [packages]

```toml
[packages]
additional = "curl,wget,git,build-essential,htop,net-tools,vim,nano,openssh-server"
```

---

## 重要路径

### 日志文件

```
/var/log/vpc-init/
├── setup-20260211-154230.log          # 初始化日志
├── setup-errors-20260211-154230.log   # 错误日志
└── advanced-config-*.log              # 高级配置日志
```

查看日志:
```bash
sudo tail -f /var/log/vpc-init/setup-*.log
sudo grep "ERROR" /var/log/vpc-init/setup-errors-*.log
```

### 凭证文件

```
/root/endlex-credentials.txt           # 用户凭证（仅 root 可读）
```

查看凭证:
```bash
sudo cat /root/endlex-credentials.txt
```

### SSH 配置

```
/home/endlex/.ssh/                     # SSH 目录（700 权限）
├── authorized_keys                    # 授权密钥文件（600 权限）
└── ...
```

### 检查点文件

```
.vpc-init-checkpoint/                  # 检查点目录
├── setup-20260211-154230.state        # 状态文件
├── setup-20260211-165500.state
└── ...
```

### Nginx 配置

```
/etc/nginx/
├── nginx.conf                         # 主配置文件
├── sites-available/                   # 可用站点配置
│   ├── example.com                   # 你的站点配置
│   └── default                       # 默认配置
├── sites-enabled/                     # 启用站点（软链接）
│   └── example.com -> ../sites-available/example.com
└── snippets/                          # 配置片段

/var/www/                              # Web 根目录
├── example.com/                      # 站点目录
│   └── index.html
└── html/                             # 默认站点

/var/log/nginx/                        # Nginx 日志
├── access.log                        # 访问日志
└── error.log                         # 错误日志

/etc/letsencrypt/                      # SSL 证书
├── live/
│   └── example.com/
│       ├── fullchain.pem
│       └── privkey.pem
└── renewal/                           # 续期配置
```

### Sudoers 配置

```
/etc/sudoers.d/endlex                  # Sudo 配置文件（440 权限）
```

### SSH 服务器配置

```
/etc/ssh/sshd_config                   # SSH 服务器配置
/etc/ssh/sshd_config.backup            # 备份文件
```

---

## 脚本执行流程

### setup.sh 执行顺序

```
1. 检查 root 权限
2. 初始化日志系统
3. 显示主菜单
4. 根据用户选择执行：
   
   选项 1: 全部自动初始化
   ├── 加载配置文件（如果存在）
   ├── 检查系统（Ubuntu, dpkg）
   ├── 更新系统包
   ├── 安装依赖
   ├── 创建用户
   ├── 配置 Sudo
   ├── 设置 SSH 目录
   ├── 配置 SSH 服务器
   ├── 添加 SSH 密钥
   ├── 配置防火墙
   ├── 配置主机名
   ├── 配置时区
   ├── 执行高级配置（根据配置）
   ├── 打印摘要
   └── 提示修改密码
   
   选项 2: 高级配置菜单
   ├── 显示高级选项
   └── 执行选择的功能
   
   选项 3: 管理 SSH 密钥
   
   选项 4: 查看日志
   
   选项 5: 帮助文档
```

每个步骤都会:
- 检查是否已在检查点中完成
- 如果已完成，跳过该步骤
- 如果未完成，执行并记录到检查点

---

## 常见代码片段

### 在其他脚本中使用 setup.sh 的函数

```bash
#!/bin/bash

source setup.sh

# 使用 setup.sh 中的函数
print_status "Starting my task..."
print_success "Task completed!"
log "INFO" "My log message"
```

### 在其他脚本中使用检查点

```bash
#!/bin/bash

source checkpoint.sh

export CHECKPOINT_DIR=".my-checkpoints"
init_checkpoint_system

my_task() {
    echo "Doing something..."
    sleep 2
}

checkpoint_execute "my_task" my_task
echo "Done!"
```

### 在其他脚本中使用配置

```bash
#!/bin/bash

source config.sh

parse_toml config.toml || {
    echo "Failed to parse config"
    exit 1
}

user=$(get_config "basic:username")
echo "Username: $user"
```

### 在其他脚本中使用 Nginx 配置

```bash
#!/bin/bash

source advanced-config.sh

# 设置变量
NGINX_DOMAIN="example.com"
NGINX_ENABLE_SSL=true
NGINX_BACKEND="http://localhost:3000"

# 执行安装和配置
nginx_full_setup
```

---

## 文件权限速查

| 路径 | 权限 | 所有者 | 说明 |
|------|------|--------|------|
| `/root/endlex-credentials.txt` | 600 | root | 仅 root 读取 |
| `/home/endlex/.ssh/` | 700 | endlex | 仅所有者访问 |
| `/home/endlex/.ssh/authorized_keys` | 600 | endlex | 仅所有者读取 |
| `/etc/sudoers.d/endlex` | 440 | root | 仅 root 和 sudo 组 |
| `/var/log/vpc-init/` | 755 | root | 所有人读取 |
| `/etc/nginx/` | 755 | root | 所有人读取 |
| `/var/www/` | 755 | root | 所有人读取 |
| `/var/www/*/index.html` | 644 | www-data | 所有人读取 |

---

## 调试技巧

### 启用详细日志

```bash
# 查看脚本执行过程中的所有命令
bash -x setup.sh 2>&1 | tee debug.log

# 仅查看错误
bash setup.sh 2>&1 | tee error.log
```

### 逐行执行

```bash
# 交互式调试模式
bash -i setup.sh
```

### 检查语法错误

```bash
# 检查 Bash 脚本语法
bash -n setup.sh
bash -n advanced-config.sh
bash -n config.sh
```

### 查看变量值

在脚本中添加调试打印:

```bash
# 添加到脚本中
echo "DEBUG: USERNAME=$USERNAME"
echo "DEBUG: TIMEZONE=$TIMEZONE"
echo "DEBUG: NGINX_DOMAIN=$NGINX_DOMAIN"
echo "DEBUG: CHECKPOINT_DIR=$CHECKPOINT_DIR"
```

### Nginx 调试

```bash
# 测试配置语法
sudo nginx -t

# 查看详细错误
sudo nginx -t -c /etc/nginx/nginx.conf

# 调试模式启动
sudo nginx -g 'daemon off;'

# 查看配置
sudo cat /etc/nginx/sites-available/example.com
```

---

**更新日期**: 2026-02-11  
**文档版本**: 2.0  
**状态**: 完整
