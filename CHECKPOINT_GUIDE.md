# 断点续跑功能 (Checkpoint & Resume Guide)

## 概述

vpc_init 现已支持 **断点续跑 (Checkpoint & Resume)** 功能。当脚本执行过程中因网络中断、操作系统问题或其他原因导致脚本中断时，你可以直接重新运行脚本，已完成的步骤将被自动跳过，脚本将从断点位置继续执行。

## 核心特性

✅ **自动保存执行状态** - 每个成功完成的步骤都会被记录  
✅ **智能断点恢复** - 脚本能自动识别已完成的步骤并跳过  
✅ **用户确认** - 恢复前会询问用户确认  
✅ **完整日志记录** - 所有断点操作都被记录到日志文件  
✅ **便捷管理工具** - 提供专门的断点管理命令  

## 工作原理

### 1. 断点存储机制

所有断点数据存储在 `.vpc-init-checkpoint` 目录中，使用以下格式：

```
.vpc-init-checkpoint/
├── setup-20260210-154230.state   # 状态文件 (包含所有已完成的检查点)
├── setup-20260210-165500.state
└── setup-20260210-172010.state
```

### 2. 状态文件格式

每个状态文件记录已完成的检查点，格式为：

```
checkpoint_name|timestamp|description|status
create_user|2026-02-10 15:42:30|User created|COMPLETED
setup_sudo|2026-02-10 15:42:35||COMPLETED
update_system|2026-02-10 15:43:15||COMPLETED
```

### 3. 执行流程

```
启动 setup.sh
    ↓
扫描 .vpc-init-checkpoint 目录
    ↓
[如果找到之前的状态文件]
    ↓
显示发现的检查点
    ↓
询问用户: "Resume from checkpoint? [Y/n]"
    ↓
┌─────────┴─────────┐
↓                   ↓
Y: 恢复执行         n: 重新开始
    ↓                   ↓
跳过已完成步骤      删除旧状态
开始于断点位置      从头执行所有步骤
    ↓                   ↓
执行剩余步骤        执行所有步骤
    ↓
保存检查点状态
    ↓
完成初始化
```

## 使用示例

### 示例 1: 首次执行脚本

```bash
$ sudo bash setup.sh

[2026-02-10 15:42:30] [INFO] ========== Ubuntu 服务器初始化工具启动 ==========
[2026-02-10 15:42:30] [INFO] Script directory: /root/vpc_init
[2026-02-10 15:42:30] [INFO] Log file: /var/log/vpc-init/setup-20260210-154230.log

==> Starting server initialization...
==> Running as root - OK
==> Ubuntu system detected: 22.04 LTS
==> Updating system packages...
✓ System updated
==> Installing basic dependencies...
✓ Dependencies installed
==> Creating user 'endlex'...
✓ User 'endlex' created
...
```

脚本在"安装依赖项"步骤中断，日志显示：

```
✓ create_user                        2026-02-10 15:42:30
✓ setup_sudo                         2026-02-10 15:42:35
✓ update_system                      2026-02-10 15:43:15
```

### 示例 2: 脚本中断后恢复

```bash
# 网络中断，脚本停止
^C

# 修复问题后，重新运行
$ sudo bash setup.sh

Found previous checkpoint state: setup-20260210-154230.state
═══════════════════════════════════════════════════════════
State file: init-20260210-154230.state
═══════════════════════════════════════════════════════════

  create_user                      2026-02-10 15:42:30  COMPLETED
  setup_sudo                       2026-02-10 15:42:35  COMPLETED
  update_system                    2026-02-10 15:43:15  COMPLETED

Resume from checkpoint? [Y/n] Y

[2026-02-10 15:45:00] [INFO] Resuming from checkpoint: .vpc-init-checkpoint/init-20260210-154230.state
==> Resuming server initialization from previous checkpoint...
==> Running as root - OK
==> Ubuntu system detected: 22.04 LTS
⊘ [SKIPPED] Checkpoint 'create_user' already completed
⊘ [SKIPPED] Checkpoint 'setup_sudo' already completed
⊘ [SKIPPED] Checkpoint 'update_system' already completed
==> Installing basic dependencies...
✓ Dependencies installed
==> Creating user 'endlex'...
...
```

### 示例 3: 选择重新开始

```bash
$ sudo bash setup.sh

Found previous checkpoint state: setup-20260210-154230.state
...
Resume from checkpoint? [Y/n] n

[2026-02-10 15:45:30] [INFO] Starting fresh initialization
# 脚本重新从头执行所有步骤，不跳过任何内容
```

## 检查点列表

setup.sh 中设置的检查点包括：

| 检查点名称 | 说明 | 耗时 |
|-----------|------|------|
| `check_root` | 检查是否为 root 用户 | ~1s |
| `check_ubuntu` | 检查是否为 Ubuntu 系统 | ~1s |
| `update_system` | 更新系统包列表 | ~30-60s |
| `install_dependencies` | 安装基础依赖包 | ~2-5min |
| `create_user` | 创建用户账户 | ~2s |
| `setup_sudo` | 配置 sudo 权限 | ~1s |
| `setup_ssh` | 配置 SSH 目录 | ~1s |
| `setup_ssh_config` | 配置 SSH 服务器 | ~1s |
| `configure_firewall` | 配置防火墙 | ~5-10s |
| `configure_hostname` | 配置主机名 | ~1s |
| `configure_timezone` | 配置时区 | ~1s |
| `prompt_change_password` | 提示修改密码 | 取决于用户 |

## 断点管理工具

### 查看所有检查点

```bash
$ bash checkpoint-manager.sh list

═══════════════════════════════════════════════════════════
Checkpoint List (pattern: *)
═══════════════════════════════════════════════════════════

State file: init-20260210-154230.state
═══════════════════════════════════════════════════════════

  create_user                      2026-02-10 15:42:30  COMPLETED
  setup_sudo                       2026-02-10 15:42:35  COMPLETED
  update_system                    2026-02-10 15:43:15  COMPLETED

State file: setup-20260210-165500.state
═══════════════════════════════════════════════════════════

  create_user                      2026-02-10 16:55:00  COMPLETED
  setup_sudo                       2026-02-10 16:55:05  COMPLETED
  ...
```

### 按日期过滤

```bash
$ bash checkpoint-manager.sh list "20260210*"

# 只显示 2026-02-10 的检查点
```

### 查看检查点状态

```bash
$ bash checkpoint-manager.sh status

═══════════════════════════════════════════════════════════
Checkpoint Status
═══════════════════════════════════════════════════════════

Checkpoint Status:
  • State files: 3
  • Total checkpoints: 18
  • Storage directory: .vpc-init-checkpoint
```

### 重置检查点（需要确认）

```bash
# 重置所有检查点（会询问确认）
$ bash checkpoint-manager.sh reset -y

# 重置特定日期的检查点
$ bash checkpoint-manager.sh reset "20260210*" -y

# 不使用 -y 标志会提示确认
$ bash checkpoint-manager.sh reset
Checkpoints to be reset:
  .vpc-init-checkpoint/setup-20260210-154230.state
  .vpc-init-checkpoint/setup-20260210-165500.state
Continue? [y/N] y
```

### 清理旧检查点

```bash
# 删除 7 天前的检查点（默认）
$ bash checkpoint-manager.sh clean

# 删除 1 天前的检查点
$ bash checkpoint-manager.sh clean 1

# 删除 30 天前的检查点
$ bash checkpoint-manager.sh clean 30
```

### 按日期删除

```bash
# 删除特定日期的所有检查点
$ bash checkpoint-manager.sh remove-date 20260210-154230

# 不询问确认，直接删除
$ bash checkpoint-manager.sh remove-date 20260210-154230 -y
```

### 只保留最新的检查点

```bash
# 只保留最新的 5 个检查点文件（默认）
$ bash checkpoint-manager.sh keep-latest

# 只保留最新的 10 个
$ bash checkpoint-manager.sh keep-latest 10

# 只保留最新的 1 个
$ bash checkpoint-manager.sh keep-latest 1
```

## 常见场景

### 场景 1: 网络中断恢复

**问题**: 执行 `apt-get install` 时网络中断

**解决**:
```bash
# 修复网络连接
$ sudo vi /etc/netplan/01-netcfg.yaml  # 修复网络配置
$ sudo netplan apply                     # 应用配置

# 重新运行脚本，自动从网络安装后继续
$ sudo bash setup.sh
```

### 场景 2: 权限问题

**问题**: 某个 chown 命令失败

**解决**:
```bash
# 检查权限问题
$ ls -la /home/

# 手动修复权限
$ sudo chown -R endlex:endlex /home/endlex

# 清除检查点，重新运行
$ bash checkpoint-manager.sh reset -y
$ sudo bash setup.sh
```

### 场景 3: 需要从特定步骤开始

**问题**: 只想重新执行防火墙配置及以后的步骤

**解决**:
```bash
# 方法 1: 删除所有检查点，重新开始（但会重复所有步骤）
$ bash checkpoint-manager.sh reset -y

# 方法 2: 编辑状态文件，手动删除某些检查点
$ cat .vpc-init-checkpoint/init-*.state

# 删除防火墙相关的检查点
$ vim .vpc-init-checkpoint/init-20260210-154230.state
# 删除包含 configure_firewall 的行，保存

# 重新运行脚本
$ sudo bash setup.sh
```

## 故障排除

### Q1: 如何强制重新开始所有步骤？

A: 删除 `.vpc-init-checkpoint` 目录中的所有状态文件：

```bash
$ rm -rf .vpc-init-checkpoint/
$ sudo bash setup.sh
```

或使用管理工具：

```bash
$ bash checkpoint-manager.sh reset -y
$ sudo bash setup.sh
```

### Q2: 检查点文件存储在哪里？

A: 默认存储在脚本执行目录的 `.vpc-init-checkpoint/` 子目录中。存储位置由 `CHECKPOINT_DIR` 环境变量控制：

```bash
# 查看当前位置
$ ls -la .vpc-init-checkpoint/

# 自定义位置
$ CHECKPOINT_DIR=/tmp/vpc-checkpoints sudo bash setup.sh
```

### Q3: 可以在远程服务器上安全使用吗？

A: 可以。断点数据完全本地化存储，不会上传到任何地方。但需要注意：

- 如果服务器重启，需要在同一目录重新运行脚本才能恢复
- 如果清除了 `.vpc-init-checkpoint` 目录，将无法恢复
- 建议在完整执行一次后再删除断点数据

### Q4: 为什么某些步骤总是执行？

A: 某些步骤（如 SSH 密钥添加）设计为总是执行，因为它们具有幂等性（重复执行不会造成问题）。只有具有破坏性或耗时长的步骤才使用检查点。

### Q5: 日志文件在哪里？

A: 日志文件存储在 `/var/log/vpc-init/` 目录中：

```bash
# 查看初始化日志
$ sudo tail -f /var/log/vpc-init/setup-20260210-154230.log

# 查看错误日志
$ sudo tail -f /var/log/vpc-init/setup-errors-20260210-154230.log

# 查看所有日志
$ ls -lh /var/log/vpc-init/
```

## 最佳实践

1. **定期清理** - 使用 `checkpoint-manager.sh clean` 定期清理旧的检查点

   ```bash
   # 清理 7 天前的检查点
   $ bash checkpoint-manager.sh clean 7
   ```

2. **备份状态文件** - 在修复 bug 前备份状态文件

   ```bash
   $ cp -r .vpc-init-checkpoint .vpc-init-checkpoint.backup
   ```

3. **查看日志** - 遇到问题时总是先查看日志

   ```bash
   $ sudo tail -100 /var/log/vpc-init/init-*.log
   ```

4. **使用配置文件** - 总是使用 `--config` 参数指定配置文件

   ```bash
   $ sudo bash setup.sh
   ```

5. **逐步调试** - 如果脚本反复失败，可以逐个跳过步骤来调试

   ```bash
   # 跳过防火墙配置
   $ bash checkpoint-manager.sh list
   # 编辑状态文件删除 configure_firewall
   # 重新运行脚本
   ```

## 环境变量

### CHECKPOINT_DIR

设置检查点数据存储目录（默认: `.vpc-init-checkpoint`）

```bash
# 使用自定义目录
$ CHECKPOINT_DIR=/var/lib/vpc-checkpoints sudo bash setup.sh

# 禁用检查点功能（不建议）
$ CHECKPOINT_DIR=/dev/null sudo bash setup.sh  # 注意：这会导致无法恢复
```

## 技术细节

### 断点库文件 (checkpoint.sh)

包含以下核心函数：

- `init_checkpoint_system()` - 初始化检查点系统
- `checkpoint_mark()` - 标记检查点为已完成
- `checkpoint_exists()` - 检查检查点是否已完成
- `checkpoint_execute()` - 条件执行函数
- `checkpoint_list()` - 列出所有检查点
- `checkpoint_reset()` - 重置检查点
- `checkpoint_cleanup()` - 清理旧检查点

### 文件大小

- `checkpoint.sh` - ~10KB (断点库)
- `checkpoint-manager.sh` - ~12KB (管理工具)
- `.vpc-init-checkpoint/` - 每个状态文件 ~1-2KB

### 性能影响

- 检查点操作非常快速（<1ms）
- 不会显著增加脚本执行时间
- 磁盘占用极小

## 更新日志

### v1.2 (2026-02-10)

- ✅ 添加断点续跑功能
- ✅ 实现 checkpoint.sh 库
- ✅ 创建 checkpoint-manager.sh 工具
- ✅ 修改 setup.sh 支持断点
- ✅ 编写完整文档

## 支持

如有问题或建议，请：

1. 查看日志: `sudo tail -f /var/log/vpc-init/init-*.log`
2. 检查断点: `bash checkpoint-manager.sh list`
3. 查看本文档相关部分
4. 重置并重试: `bash checkpoint-manager.sh reset -y`

---

**最后更新**: 2026-02-10  
**文档版本**: 1.0  
**状态**: 正式发布
