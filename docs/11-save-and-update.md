# 本地保存与自动更新（SaveManager / UpdateManager）

## 1. 本地保存系统

### 保存文件

- 路径：`user://settings.cfg`
  - Windows：`%APPDATA%\Godot\app_userdata\DestinyDawn\settings.cfg`
  - Android：应用私有数据目录
- 格式：Godot 原生 `ConfigFile`（INI 风格），调试可用 `SaveManager.get_save_path()` 查看实际路径

### 保存字段

| 节 | 键 | 对应 GlobalGameData 字段 | 说明 |
|---|---|---|---|
| general | player_name | `player_name` | 玩家昵称 |
| general | server_port | `server_port` | 默认联机端口 |
| audio | audio_volume_master/bgm/sfx | 同名 | 三个音量（0~1） |
| ui | menu_background | `menu_background` | 菜单背景 id，默认 `elaina` |
| game | selected_team | `selected_team` | 编队（角色 id 数组） |
| game | selected_deck | `selected_deck` | 卡组（卡牌 id 数组） |
| update | auto_update | `auto_update` | 启动自动检查更新开关 |
| update | proxy_mode | `proxy_mode` | 更新通道：direct / ghfast / ghproxy / custom |
| update | proxy_prefix | `proxy_prefix` | 自定义镜像前缀（custom 时生效） |
| update | update_proxy_host | `update_proxy_host` | HTTP 代理地址（如本地 Clash `127.0.0.1`），可空 |
| update | update_proxy_port | `update_proxy_port` | HTTP 代理端口（如 `7897`） |

### 机制

- 内存字段统一挂在 `GlobalGameData`，`Global/SaveManager.gd` 只负责磁盘读写：
  - `load_all()`：读盘 → 写入 GlobalGameData（文件缺失/损坏时静默保留默认值）
  - `save_all()`：GlobalGameData → 写盘
- 字段映射集中定义在 `SaveManager.FIELD_MAP`，增删字段只需改这一处
- 加载时机：`SaveManager._ready()`（autoload 启动即加载，早于 `BackgroundManager._ready()`）+ `MainMenu._ready()` 二次刷新
- 保存时机：设置页/编队/卡组的「保存」按钮、音量滑块变化、背景切换（`BackgroundManager.set_background()` 内）

### 迁移说明

- v1.7.0 起背景选择不再写入 `ProjectSettings`（旧逻辑仅编辑器生效，导出版会丢失），改由本系统持久化
- 旧的 `project.godot` `menu_background` 键已移除

## 2. 自动更新

### 版本号

- 唯一来源：`Global/UpdateManager.gd` 的 `const VERSION`，发布时同步 `export_presets.cfg` 导出路径
- 发布脚本 `tools/publish.ps1` 会自动从 UpdateManager.gd 提取版本号

### 检查更新

- 请求 `https://api.github.com/repos/5652fsft/DestinyDawn/releases/latest`（带 `User-Agent`，公开仓库无需 token）
- 语义化比较 `a.b.c`，本地版本低于最新 tag 视为有更新
- 主菜单启动时（若 `auto_update` 开启）延迟 1.5s 静默检查；发现新版本弹出更新面板（样式与联机面板一致）
- 设置页有手动「检查更新」按钮

### 下载与安装（Windows）

1. `HTTPClient` 流式下载（64KB 分块，避免 200MB+ 文件进内存），进度实时推送
2. 下载到 exe 旁 `.dd_update/` 临时目录，完成后与 release 资产 `size` 字段校验
3. 写入 `install_update.bat`：等待 3 秒（旧进程退出）→ `move /y` 覆盖 exe → 启动新 exe → 自删
4. `OS.create_process` 启动 bat 后游戏退出，由 bat 完成替换与重启
5. 失败保护：`move` 失败不会删除旧 exe，游戏仍可正常运行

注意：若游戏安装在受保护目录（如 `Program Files`），替换可能因权限失败，需以管理员运行一次或改放自定义目录。

### 下载与提示（Android）

- apk 无法自动替换（需系统安装权限），检测到新版本后提示 + `OS.shell_open` 打开 release 下载页，由用户手动安装

### 代理加速（更新通道）

设置页「更新通道」：
- 直连 GitHub
- 镜像 ghfast.top / ghproxy.net（内置前缀，主要代理 release 下载路径，api 查询可能被镜像拒绝）
- 自定义镜像（输入形如 `https://ghfast.top/` 的前缀，拼接规则：前缀 + 原始 URL）
- **HTTP 代理**（单独输入框）：填本地代理地址与端口（如 `127.0.0.1:7897`），直连与镜像都不通时可用。Godot 不走系统代理，需在此手动填写

所有候选 URL 按序尝试：选定镜像 → 直连兜底。
镜像仅用于更新检查/下载，不影响联机等其它功能。

### 状态信号

| 信号 | 参数 | 说明 |
|---|---|---|
| `check_state_changed` | (state, message) | IDLE/CHECKING/UP_TO_DATE/UPDATE_AVAILABLE/ERROR |
| `download_state_changed` | (state, progress, total, message) | IDLE/DOWNLOADING/READY/INSTALLING/ERROR |

## 3. 发布流程

### 一键脚本（推荐）

前置：Godot 4.7（已装导出模板）、[gh CLI](https://cli.github.com/) 已登录（`gh auth login`）

```powershell
# 仅 Windows（内嵌 pck 单 exe）
.\tools\publish.ps1

# 同时导出并上传 Android apk
.\tools\publish.ps1 -Android

# 指定 Godot 可执行文件路径
.\tools\publish.ps1 -GodotExe "D:\Godot\godot.exe"
```

脚本步骤：提取 VERSION → 无头导出 → 确认 → `gh release create vX.Y.Z <exe> [apk] --generate-notes --target master`

### 手动发布

1. 修改 `Global/UpdateManager.gd` 的 `VERSION`
2. 同步 `export_presets.cfg` 中两个预设的 `export_path`
3. Godot 编辑器 → 项目 → 导出（Windows 预设 `embed_pck=true`，产物为单个 exe）
4. GitHub → Releases → 新建 tag `vX.Y.Z` → 上传 exe（/apk）→ 设为 latest

### 资产命名约定

- Windows：`DestinyDawn-vX.Y.Z.exe`（单文件，内嵌 pck，无需 zip）
- Android：`DestinyDawn-vX.Y.Z.apk`

更新器按扩展名匹配资产：Windows 找 `.exe`，Android 找 `.apk`，请勿在 release 中上传其它同名后缀文件。