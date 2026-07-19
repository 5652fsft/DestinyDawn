# Git 规范

## 分支策略

```
master               ← 稳定发布分支
  └─ feature/*       ← 功能开发分支（在本地创建）
```

- `master` 始终是可运行状态
- 功能开发在本地 `feature/*` 分支进行
- 完成后 **fast-forward** 合并到 `master`，推送前先 `pull --rebase`
- 不再保留长期特性分支，每个迭代完成后删除

---

## 提交信息格式

```
<type>: <简短描述>

<详细说明（可选）>
```

### Type 类型

| Type | 用途 | 示例 |
|---|---|---|
| `feat` | 新功能 | `feat: character standee cards with flip details` |
| `fix` | 修复 Bug | `fix: client hand disappearing (root cause - _client_send_setup)` |
| `refactor` | 重构 | `refactor: shared CharacterData, unified naming, layout fixes` |
| `style` | 样式/UI 变更 | `style: glass-like card backgrounds (alpha 0.8)` |
| `docs` | 文档 | `docs: create 6 documentation files in docs/` |
| `revert` | 回滚 | `revert: camera.gd to pre-zoom-mouse state` |

### 描述规范

- **中文**描述（项目面向中文用户）
- 第一行不超过 72 字符
- 写明**为什么**改、**怎么**改
- 必要时附带 root cause 分析

### 示例

```
fix: avoid init_player race in _client_send_setup

_client_send_setup arrives via async RPC and can race with
advance_turn_phase. If init_player(2, deck) runs after draws
have started, it resets player 2's hand to empty.

Guard: only apply client deck when game hasn't started
(current_turn_phase == NONE).
```

---

## 提交流程

```bash
# 1. 查看当前状态
git status

# 2. 检查改动内容
git diff

# 3. 暂存需要的文件（不要使用 git add -A 盲目添加）
git add <file1> <file2> ...

# 4. 提交
git commit -m "type: 描述"

# 5. 推送前先拉取
git pull --rebase origin master

# 6. 推送
git push origin master
```

---

## 文件管理规范

### .tscn 文件

- `.tscn` 文件被 `Set-Content` 写入会损坏 UTF-8 中文编码
- 始终使用 `[System.IO.File]::WriteAllText` + UTF8 无 BOM，或使用 Godot 编辑器保存
- PowerShell 修改 `Write` 工具会自动处理编码

### 文件改名（Windows 大小写）

Windows 文件系统不区分大小写。要改文件名大小写（如 `Fronts` → `Fonts`）需两步：

```bash
git mv Assets/Fonts Assets/Fonts_temp
git mv Assets/Fonts_temp Assets/Fonts
```

### .uid 文件

- Godot 4 自动生成的资源 `uid` 文件（`.gd.uid`、`.tscn.uid`）
- 这些文件不应手动修改
- 如果文件被重命名，对应的 uid 文件会被 Godot 自动处理或重新生成
- 建议将 `.uid` 文件加入版本控制

### 废弃文件

- 使用 `git rm <file>` 删除已跟踪的文件
- 对于 Godot 自动重新生成的残留文件，检查 `.godot/editor/` 中的编辑状态缓存并清理

---

## 回滚操作

```bash
# 回滚单个文件到某次提交
git checkout <commit-hash> -- <file-path>

# 撤销最近一次提交（保留改动在工作区）
git reset --soft HEAD~1

# 强制推送（仅当确定没有其他人基于该分支工作时使用）
git push --force-with-lease origin master
```

---

## .gitignore 规则

建议确保以下内容被忽略：

```
.godot/
*.import
*.translation
```

`.godot/` 目录包含编辑器缓存和导入资源，不应提交到版本控制。`*.import` 文件由 Godot 自动生成。
