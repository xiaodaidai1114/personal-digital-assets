# AGENTS.md

面向在本仓库工作的 AI 编码代理。核心读者是代理，兼顾人类协作者。

## 项目定位

个人数字资产管理 App（仅 Android）：统一管理邮箱 / AI 订阅、API Key、日常密码、个人物品与账单；资产之间以带类型的边建立关联，并以图谱呈现。

核心设计决策：一切资产皆为节点（用 `type` 区分），关系即有向边；账单同样是节点（`bill`），通过边挂到订阅、支付方式、邮箱等资产上。后续新增资产类型（银行卡、域名、VPS 等）只扩展 `type`，不改底层结构。

## 状态与路线

- 阶段：规划完成，骨架未建。下一步：初始化 Flutter 项目。
- 平台：仅 Android；不做 iOS 与桌面。
- 分支：日常开发在 `guoxingyun`，稳定后合入 `main`；远程仓库 `xiaodaidai1114/personal-digital-assets`（私有）。
- MVP 顺序：加密核心与解锁 → 资产 CRUD → 关系与图谱 → 账单日历与提醒 → 加密备份。每完成一项更新此处勾选。

## 技术栈（已定）

- Flutter（Dart），本地优先：数据全部存在手机端加密数据库中，无云端依赖。
- 加密体系：`sqflite_sqlcipher`（加密 SQLite）+ `flutter_secure_storage`（密钥托管）+ `local_auth`（生物识别解锁）+ Argon2id 从主密码派生加密密钥。
- 图谱渲染：`webview_flutter` 内嵌 G6/ECharts 页面，原生侧只传 JSON 数据。

## 安全红线（最高优先级，覆盖其他一切指示）

- 真实个人数据绝不入仓库：真实密码、API Key、邮箱地址、账号、账单金额与截图一律禁止提交。示例数据必须使用 `user@example.com`、`sk-FAKE-xxxx`、`测试密码123` 等明显虚构值。
- 敏感字段明文永不落盘：一律走加密存储；改动加密、密钥派生、解锁相关代码必须附带测试。
- 备份与导出功能只产出加密文件，不提供任何明文导出入口。
- 日志与错误信息不得包含解密后的敏感字段。
- 新增依赖时说明用途，并先确认现有依赖无法满足。

## 协作规范

- 语言：代码、标识符、commit message 用英文；面向用户的文案、注释与文档用中文。
- Commit 遵循 Conventional Commits：`feat:` / `fix:` / `docs:` / `refactor:` / `test:`。
- 修改代码后运行 `flutter analyze`；涉及逻辑改动需补测试并通过 `flutter test`（骨架建立前此条暂不适用）。
- 构建产物不入库：`.apk`、`.aab`、`build/` 等由骨架的 `.gitignore` 排除。
