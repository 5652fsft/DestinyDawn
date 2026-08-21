# 联机自动化测试环境（tests/）

双进程真实 ENet 对局的自动化测试环境，用于联机同步与鲁棒性回归。
**探针默认未挂载**（不影响正常游戏），需要复测时按下方步骤启用。

## 目录

| 路径 | 说明 |
|------|------|
| `NetTest.gd` | 测试探针（autoload 脚本，`--nettest=<role>:<scenario>` 启用） |
| `run_case.ps1` | 运行器：启动 host/client 双进程（headless）、收集日志、等待退出 |
| `mount_probe.ps1` / `unmount_probe.ps1` | 挂载/恢复探针 autoload（自动重建注释行 + 验证） |
| `kill_test_procs.ps1` | 安全清理残留测试进程（只杀 `--nettest` 进程） |
| `analyze.ps1` | 双端日志对比分析（结算/拦截/最终态） |
| `logs/` | 运行产物（每场景 `_host.log` / `_client.log`），已 git 忽略 |

## 启用探针（临时）

```powershell
pwsh tests/mount_probe.ps1      # 挂载（自动重建注释行 + 验证）
pwsh tests/unmount_probe.ps1    # 恢复未挂载（探针文件保留复用）
```

> 若 Godot 编辑器正在运行，脚本会给出警告（不会杀它）；仅复测时挂载，挂载状态下不带
> `--nettest` 参数运行游戏无任何影响（探针惰性返回）。

## 运行

```powershell
pwsh tests/run_case.ps1 -Scenario <场景>
```

运行器会清理**残留的测试进程**（仅命令行含 `--nettest` 的 godot 进程，**绝不会碰 Godot 编辑器或其他进程**），host 先启动、
2 秒后 client 加入 `127.0.0.1`（端口由 host 写入 `logs/port.txt`，避免端口占用偏移）。

> **与 Godot 编辑器并行**：测试不杀编辑器，可与编辑器并行运行；但挂载/恢复探针会改写
> `project.godot`（编辑器可能弹"项目设置外部修改"提示，无害）。为最干净体验，测试期间建议关闭编辑器。
> 手动清理残留测试进程请用 `pwsh tests/kill_test_procs.ps1`（同样只杀 `--nettest` 进程，安全）。

## 场景清单

| 场景 | 覆盖 |
|------|------|
| `s0` | 干净开局对照（自动战斗 AI 对 AI，完整对局） |
| `s1` | host 残留 `is_ai_mode=true`（单机后开联机） |
| `s1full` | 完整用户路径：真实单机自动战斗 → 回菜单 → 开联机 |
| `s2` | client 残留 `is_ai_mode=true`（重复角色/卡死回归） |
| `s3` | client 延迟 4s 进场（重同步补全） |
| `s4` | client 中途掉线（进程退出）→ host 判投降结算 |
| `s5` | client 永不进场/永不响应编队 → host 30s setup 超时结算 |
| `s6` | client 延迟 12s 进场（极端慢加载恢复） |
| `s7` | 中途投降 → 双端一致结算 |
| `s8` | 同进程连续两局（状态残留回归） |
| `s9` | 延迟 8s 开自动战斗（中途接管） |
| `s11` | host 中途掉线 → client 判其投降、本端获胜结算 |

退出码：`0`=正常对局结束（含预期结算） `42`=检测到卡死 `43`=总超时(600s) `44`=连接创建失败 `77`=自杀（模拟掉线）。

## 判定要点（人工核对日志）

- **开局**：host 应出现 `已广播初始快照（host=3 client=3）` → `全部客户端就绪，开局`（或 5s `ready 等待超时，兜底开局`）；client 应出现 `已按快照生成角色并回执 ready`，双端 `chars=6`。
- **掉线**：host 掉线 → client 出现 `服务端断开连接，判定其投降`；client 掉线 → host 出现 `客户端 X 断线，判定其投降`。
- **结算**：双端 `BATTLE-OVER` 一致（GAME_OVER 或投降）。
- **异常**：出现 `FREEZE`（90s 无推进/连续非本端回合）即疑似卡死；`SCRIPT ERROR` 即代码错误。

## 已知说明

- headless 环境下 `user://` 与证书相关报错为环境噪音，不影响测试。
- 对局全程自动战斗（AI 对 AI）；`s9` 验证中途开自动。
- 随机先手由 `randi()` 决定，多轮复跑可覆盖双方先手。
- **导出隔离**：`export_presets.cfg` 两个预设的 `exclude_filter` 已排除 `tests/*,tests/logs/*`，本目录不会打进发布包（已实测导出产物无 `tests/` 路径）。
