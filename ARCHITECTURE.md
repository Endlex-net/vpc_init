# VPC_INIT v3.0 架构说明

## 概述

VPC_INIT v3.0 引入了**模块化架构**，将功能拆分为独立的模块，通过注册机制统一管理。这种设计使得：

- ✅ 代码结构更清晰
- ✅ 易于扩展和维护
- ✅ 支持按需加载和执行
- ✅ 便于测试和调试

---

## 目录结构

```
vpc_init/
├── main.sh                      # 主入口脚本
├── lib/                         # 核心库
│   ├── core.sh                 # 核心功能（日志、错误处理、工具函数）
│   ├── registry.sh             # 模块注册机制
│   └── loader.sh               # 模块加载器
├── modules/                     # 功能模块
│   ├── 00-core/                # 核心模块（必须）
│   │   ├── user.sh            # 用户创建
│   │   ├── ssh.sh             # SSH配置
│   │   └── system.sh          # 系统基础
│   ├── 10-network/             # 网络模块
│   │   ├── firewall.sh        # 防火墙
│   │   └── nginx.sh           # Nginx
│   ├── 20-runtime/             # 运行环境
│   │   ├── docker.sh          # Docker
│   │   └── swap.sh            # Swap
│   └── 30-tools/               # 工具模块
│       ├── security.sh        # 安全加固
│       ├── p10k.sh            # Powerlevel10k
│       ├── verify.sh          # 系统验证
│       └── fix-dpkg.sh        # Dpkg修复
└── ...                         # 其他文件
```

---

## 模块系统

### 1. 模块结构

每个模块都是一个独立的 `.sh` 文件，遵循以下结构：

```bash
#!/bin/bash

################################################################################
# 模块: <模块名>
# 分类: <分类>
# 描述: <描述>
# 依赖: <依赖模块>
# @category: <分类>
# @description: <描述>
# @depends: <依赖>
################################################################################

# 检查函数 - 返回0表示需要执行，返回1表示跳过
<module>_check() {
    # 检查逻辑
    return 0
}

# 执行函数 - 实际的模块功能
<module>_execute() {
    print_header "模块标题"
    
    # 功能代码
    
    return 0
}

# 注册模块（必须）
register_module \
    --name "<模块名>" \
    --category "<分类>" \
    --description "<描述>" \
    --depends-on "<依赖>" \
    --config-section "<配置段>"
```

### 2. 注册机制

模块通过 `register_module` 函数注册到系统：

```bash
register_module \
    --name "nginx" \
    --category "network" \
    --description "安装并配置 Nginx" \
    --depends-on "firewall" \
    --config-section "nginx"
```

**参数说明：**
- `--name`: 模块唯一标识
- `--category`: 分类（core, network, runtime, tools）
- `--description`: 模块描述
- `--depends-on`: 依赖的其他模块
- `--config-section`: 对应的配置文件段（可选）

### 3. 分类说明

| 分类 | 代码 | 说明 | 示例 |
|------|------|------|------|
| core | 00-core | 核心功能，必须执行 | user, ssh, system |
| network | 10-network | 网络相关 | firewall, nginx |
| runtime | 20-runtime | 运行环境 | docker, swap |
| tools | 30-tools | 工具软件 | security, p10k |

---

## 使用方法

### 基础命令

```bash
# 显示帮助
sudo bash main.sh --help

# 基础初始化（使用默认配置）
sudo bash main.sh init

# 使用自定义配置
sudo bash main.sh init -c my-config.toml

# 交互式模式
sudo bash main.sh init -i

# 列出所有模块
sudo bash main.sh modules

# 单独安装某个模块
sudo bash main.sh install nginx

# 生成配置文件
sudo bash main.sh config
```

### 配置文件

```toml
[basic]
username = "endlex"
timezone = "Asia/Shanghai"

[features]
enable_firewall = true
enable_nginx = true
enable_docker = false
enable_swap = false
enable_security = true
enable_p10k = false

[nginx]
domain = "example.com"
enable_ssl = true
proxy_pass = ""
```

---

## 扩展模块

### 如何添加新模块

1. **创建模块文件**

在 `modules/` 下选择合适的分类目录创建 `.sh` 文件：

```bash
# 例如: modules/40-custom/myapp.sh
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
# @description: 安装和配置我的应用
################################################################################

myapp_check() {
    if command -v myapp &>/dev/null; then
        print_info "myapp 已安装"
        return 1
    fi
    return 0
}

myapp_execute() {
    print_header "安装 MyApp"
    
    print_status "下载 MyApp..."
    # 安装代码
    
    print_success "MyApp 安装完成"
    return 0
}

register_module \
    --name "myapp" \
    --category "custom" \
    --description "安装和配置 MyApp"
```

3. **使用新模块**

```bash
# 单独安装
sudo bash main.sh install myapp

# 或在配置文件中启用
# [features]
# enable_myapp = true
```

就是这么简单！新模块会自动被发现和加载。

---

## 核心库 API

### core.sh

```bash
# 日志
log <level> <message>
log_error <message>
init_logging

# 输出
print_header <title>
print_status <message>
print_success <message>
print_warning <message>
print_info <message>
print_error <message>

# 系统检查
check_root
check_ubuntu
check_dpkg

# 工具函数
confirm [message] [default_Y/N]
validate_username <username>
validate_timezone <timezone>
validate_swap_size <size>
generate_password
```

### registry.sh

```bash
# 注册模块
register_module --name <name> --category <cat> --description <desc>

# 查询模块
is_module_registered <name>
get_module_category <name>
get_module_description <name>
get_module_depends <name>

# 列出模块
list_modules [category_filter]
list_categories

# 加载模块
load_module <name>
load_all_modules
load_modules_by_category <category>

# 执行模块
execute_module <name> [args...]
execute_all_modules
```

### loader.sh

```bash
# 自动发现
discover_modules

# 初始化
initialize_modules

# 配置驱动
execute_modules_from_config [config_file]

# 交互式
select_modules_interactive
```

---

## 与旧版本对比

| 特性 | v2.0 (旧) | v3.0 (新) |
|------|-----------|-----------|
| 架构 | 扁平结构 | 模块化结构 |
| 扩展性 | 需修改现有文件 | 只需添加新模块文件 |
| 主脚本大小 | ~30KB | ~5KB |
| 模块数量 | 全部在几个大文件 | 独立小文件 |
| 注册方式 | 无 | 自动注册 |
| 依赖管理 | 硬编码 | 声明式依赖 |

---

## 最佳实践

1. **模块命名**: 使用小写字母和下划线
2. **函数命名**: `<module>_check` 和 `<module>_execute`
3. **错误处理**: 使用 `error_exit` 处理严重错误
4. **日志记录**: 使用 `log` 和 `print_*` 函数输出信息
5. **依赖声明**: 在 `depends-on` 中明确声明依赖

---

**更新日期**: 2026-02-11  
**架构版本**: v3.0
