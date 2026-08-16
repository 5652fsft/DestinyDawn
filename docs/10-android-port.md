# Android 移植文档

> 状态：已实现，待真机验证 | 适用版本：Godot 4.7 | 最后更新：v1.5.3

## 1. 目标与原则

- **目标**：游戏可在安卓手机横屏完整游玩（编队、卡组构筑、单人 AI、联机战斗）
- **铁律**：所有安卓改动必须带平台守卫（`OS.has_feature("android")`），**绝不影响 Windows 端体验**；守卫失败时回退到 Windows 行为
- 允许安卓端适量功能阉割，阉割项必须在本文档登记

## 2. 架构：TouchInputBridge（Autoload）

文件：`Global/TouchInputBridge.gd`，注册顺序位于 `AudioManager` 之后。

### 2.1 激活条件

```gdscript
_active = OS.has_feature("android")
```

非安卓平台 `set_process_input(false)`，完全旁路（零开销、零行为影响）。

### 2.2 单指：触摸 → 鼠标事件桥

Godot 4.7 中 `Input.emulate_mouse_from_touch`（注意：旧名 `use_emulated_mouse_from_touch` 已在 4.7 移除）默认开启，但双指手势会与之冲突，因此安卓端显式关闭内置模拟，由桥全权转换：

| 触摸事件 | 转换 | 目的 |
|----------|------|------|
| 触摸按下（第一指） | `MouseMotion` → `MouseButton(LEFT, pressed)` | **先发 motion 再发按下**，保证 `gui_get_hovered_control()` 悬停判定正确 |
| 拖动（第一指） | `MouseMotion` | 更新虚拟鼠标位置，`get_global_mouse_position()` 跟随 |
| 触摸抬起 | `MouseButton(LEFT, released)` | 结束点击/拖拽 |

**坐标转换（重要，官方 PR #89509 确认）**：`InputEventScreenTouch/Drag.position` 在 `_input()` 中**已经是 viewport 坐标**（Godot 分发前已做 window→viewport 变换），**不要**再做 `_to_viewport` 之类的逆变换。而 `Input.parse_input_event` **期望 window/屏幕坐标**（注入后 Viewport 会再转回 viewport 给 GUI）。桥内正确做法：注入鼠标事件前用 `get_viewport().get_screen_transform() * pos` 转成 window 坐标（`_to_window()`，`get_screen_transform` 不含相机变换，比 `get_final_transform()` 可靠）。

转换后事件经 `Input.parse_input_event()` 注入，现有全部鼠标交互逻辑（`main.gd._input`、`BaseCharacter.handle_move/handle_attack`、`CardUI` 拖拽、菜单控件）零改动复用。

**滚动区域适配**：`ScrollContainer` 原生触摸滚动依赖 `InputEventScreenDrag` 直达其 `_gui_input`，会被子控件（如卡牌按钮）拦截且与鼠标桥冲突，故桥内统一处理——按下时若悬停控件祖先含 `ScrollContainer` 则进入滚动模式，拖动 delta 直接写入 `scroll_vertical/scroll_horizontal`（自然滚动方向），超过死区（8px）补发鼠标释放取消误触，抬起/双指介入结束滚动。编队 `RosterScroll`、卡组 `PoolScroll`、角色卡牌描述 `CardBack/Scroll` 均自动生效。

**移动端图标按钮**：`ButtonTheme.apply_icon_small` 全状态无底色/边框并 `FOCUS_NONE`（不显示任何"框"）；投降菜单打开与战斗结算时 `_set_mobile_buttons_visible(false)` 隐藏，关闭（未结算）恢复——仅安卓生效。位置：右上角敌方玩家信息面板左侧（锚点右上，菜单键贴面板、手牌键再左），刘海安全区适配用右侧 insets。

### 2.3 双指手势

| 手势 | 事件 → 行为 |
|------|-------------|
| 双指捏合 | `touch_zoom(factor, center)` → 以**双指中心为聚焦点**缩放（`_zoom_at`），`scale_num` 限制 0.4~1.0（与滚轮一致） |
| 双指平移 | `touch_pan(screen_delta)` → `position -= screen_delta * scale_num ** 0.5`（反向=跟手，速度系数与右键拖拽一致） |

- 相机通过 `add_to_group("touch_camera")` 注册，桥用 `call_group` 调用；其他场景无相机时调用自动落空，无副作用
- 双指模式期间主指不再发 `motion`，防止视角/点击互相打架；任一指抬起即退出双指模式
- **统一"目标位置"机制（v1.5.3）**：`camera.gd` 用 `_target_position` 作为唯一位置目标，滚轮聚焦/双指/右键拖拽/AI 镜头均写该目标，`_process` 中 `position = lerp(position, _target_position, 8*delta)` 平滑跟随——**无任何 tween kill 竞争，后写者赢**（AI 镜头播放中玩家操作以 AI 渐变继续为准）
- **聚焦缩放**：`_zoom_at(screen_pos, new_scale)` 保持 screen_pos 处世界点缩放前后屏幕位置不变；视口中心必须用 `ProjectSettings` 的设计分辨率（`get_viewport_rect()` 返回窗口尺寸，非 1280×720 窗口下会偏左上）

### 2.4 安全区

`get_content_safe_insets() -> Vector4`（x=left, y=top, z=right, w=bottom，viewport 坐标）：

- 返回**内容区域被系统安全区（刘海/挖孔）实际覆盖**的边距 = `maxf(0, 内容区超出安全区的量)`；黑边不计入（safe 通常=整个窗口，content_rect 小于窗口时差值<0 取 0）
- `main.gd._apply_safe_area()`（仅安卓）把边缘面板内收避开遮挡：左列按钮右移、右上/右下玩家面板内收
- 未处理 TurnIndicator（full-rect 布局，横屏顶部挖孔罕见；真机验证后再决定是否细化）

## 3. 安卓功能阉割清单（登记）

| 功能 | 处理 | 位置 |
|------|------|------|
| 键盘快捷键 | F/ESC 无键盘替代，改为右上角「手牌」「菜单」按钮（仅安卓显示） | `Scenes/scene.tscn` + `main.gd:_setup_mobile_buttons()` |
| 右键拖视角/滚轮缩放 | 双指手势替代（见 2.3） | `TouchInputBridge.gd` |

> 注：菜单视频背景守卫与设置页视频选项过滤已移除（Theora 720p 可解码，官方认可移动端 720p；现有视频码率 ~10Mbps 偏高，低端机若卡顿需重编码降码率）。

## 4. 导出配置

`export_presets.cfg` 的 `[preset.1]`（Android），关键项：

| 项 | 值 | 说明 |
|----|----|------|
| `architectures/arm64-v8a` | true | 主流机型；v7a/x86 关闭缩小包体 |
| `rendering/renderer/rendering_method` | `mobile` | 纯 2D 游戏，Vulkan Mobile 降功耗/兼容门槛（预设级覆盖，不影响 Windows 的 Forward Plus） |
| `texture_format/etc2_astc` | true | Android 纹理压缩 |
| `screen/immersive_mode` | true | 全屏沉浸 |
| `display/window/handheld/orientation` | 0 | 横屏 |
| `permissions/internet` | true | 联机（ENet/UPnP/HTTP 公网 IP）。**必须开启**：v1.5.3 曾为 false，APK 无 INTERNET 权限 → 移动端建主机报"端口不可用"、HTTP 公网 IP 获取失败 |
| `package/signed` | false | **测试用 debug 签名**；正式发布前需配置 release keystore 并改 true |
| `package/unique_name` | `com.destinydawn.game` | 按需修改 |

**导出前置**：Godot 编辑器 → 项目 → 导出 → 安装 Android 导出模板。

## 5. 真机测试清单（待执行）

- [ ] 单指：选角色、移动、攻击、技能、拖牌出牌、目标点选
- [ ] 双指：捏合缩放（0.4~1.0）、平移视角
- [ ] 「手牌」「菜单」按钮；投降流程
- [ ] 刘海屏设备：边缘面板不被遮挡
- [ ] 联机：主机/加入双方对局同步（移动 NAT 下 UPnP 可能失败，验证 VPN 房间码）
- [ ] 编队、卡组构筑、设置、游戏指南全流程
- [ ] 长时间对局：内存/发热（卡面大 PNG 是主要压力点）

## 6. 已知限制与预留

- **悬停兜底**：桥的"motion 先行"策略理论上让 `gui_get_hovered_control()` 正常；若真机出现 UI 穿透，在 `BaseCharacter._is_mouse_over_ui()` 等 4 处补"触摸按下位置点检"兜底（桥已预留 `static var touch_active` / `last_touch_pos`）
- **联机 NAT**：移动网络下 UPnP 大概率失败属正常；跨网联机（移动端 ↔ 电脑）推荐**蒲公英组网**（贝锐，国内免费，电脑+手机装 App 组虚拟局域网，房间码直接输虚拟 IP）
- **视频背景**：若未来需要改进，可改为静态图轮播或 WebM（VP9 硬解）方案
- **卡牌大图**：34 张 500-900KB PNG 是移动端内存/加载的主要压力，后续可压缩或转 WebP/ASTC

## 7. Godot 4.7 兼容性注意（踩坑记录）

1. `Input.use_emulated_mouse_from_touch` 在 4.7 已改名为 `emulate_mouse_from_touch`，旧名直接编译失败
2. 4.7 严格类型检查：`Vector2i` 与 `Vector2` 混合运算（如 `ws - vp * scale`）传参给 `Rect2()` 会编译失败，需显式 `Vector2(ws)` 转换
