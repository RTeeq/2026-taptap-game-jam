# Git 版本管理

对当前游戏项目执行 git 版本管理操作。

## 使用方式

用户可以说以下内容来触发此命令：
- `/git` — 查看状态或交互式选择操作
- `/git init` — 初始化仓库
- `/git 提交` 或 `/git commit` — 提交当前更改
- `/git 历史` 或 `/git log` — 查看提交历史
- `/git 回退` 或 `/git revert` — 回退到指定版本
- `/git 状态` 或 `/git status` — 查看当前状态
- `/git diff` — 查看未提交的更改

## 执行流程

### 1. 初始化（如果还没有 git 仓库）

检查 `/workspace` 是否已是 git 仓库（`git rev-parse --is-inside-work-tree`）。
如果不是，执行以下操作：

```bash
cd /workspace
git init
git config user.email "maker@game.dev"
git config user.name "Maker"
```

创建 `.gitignore`（如果不存在），内容为：

```
# 引擎和构建产物（不需要版本管理）
dist/
.tmp/
.build/
.project/
logs/
node_modules/

# 引擎只读资源
engine-docs/
examples/
templates/
urhox-libs/
.emmylua/
tools/
prompts/

# 系统文件
.DS_Store
Thumbs.db
```

然后做首次提交：
```bash
git add scripts/ assets/ .gitignore
git commit -m "初始提交：项目初始化"
```

### 2. 提交代码

```bash
cd /workspace
git status
```

展示当前有哪些更改，然后询问用户提交信息（如果用户没有提供的话）。

提交时只追踪游戏代码和资源：
```bash
git add scripts/ assets/
git commit -m "<用户提供的提交信息>"
```

如果用户没指定提交信息，根据 `git diff --cached --stat` 的内容自动生成一条简洁的中文提交信息。

### 3. 查看状态

```bash
cd /workspace
git status
```

用简洁的中文向用户汇报：
- 有哪些文件被修改
- 有哪些新文件未追踪
- 是否有未提交的更改

### 4. 查看历史

```bash
cd /workspace
git log --oneline -20
```

以表格形式展示最近 20 条提交记录（哈希、日期、信息）。

### 5. 回退版本

先展示最近的提交历史，让用户选择要回退到哪个版本。

- **回退单次提交**（保留后续更改）：`git revert <commit-hash> --no-edit`
- **硬回退到某版本**（丢弃后续所有更改）：先确认用户理解后果，再执行 `git reset --hard <commit-hash>`
- **查看某版本内容**（不回退）：`git show <commit-hash> --stat`

⚠️ 硬回退（reset --hard）会丢失数据，必须二次确认！

### 6. 查看差异

```bash
cd /workspace
git diff scripts/ assets/
```

展示自上次提交以来的具体代码变更。

## 注意事项

- 只管理 `scripts/` 和 `assets/` 目录的内容
- 不要将 `dist/`、`engine-docs/`、`urhox-libs/` 等引擎目录纳入版本管理
- 提交信息使用中文，简洁明了
- 回退操作前始终提醒用户风险
