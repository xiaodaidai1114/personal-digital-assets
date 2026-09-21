# AGENTS.md

面向在本仓库工作的 AI 编码代理。核心读者是代理，兼顾人类协作者。

## 项目定位

个人数字资产管理 App（仅 Android）：统一管理邮箱 / AI 订阅、API Key、日常密码、个人物品与账单；资产之间以带类型的边建立关联，并以图谱呈现。

核心设计决策：一切资产皆为节点（用 `type` 区分），关系即有向边；账单同样是节点（`bill`），通过边挂到订阅、支付方式、邮箱等资产上。后续新增资产类型（银行卡、域名、VPS 等）只扩展 `type`，不改底层结构。

UI 设计方向已定为「纸墨加密账册」，唯一视觉依据是 `docs/design/DESIGN.md`（已整合实现锁点与页面契约，含 token 与代码色名对照）；改 UI 前先读设计文档并遵守其中对比度与触控标准。

## 状态与路线

- 阶段：MVP 功能与「纸墨加密账册」UI 已完成：加密核心与解锁、资产 CRUD、关系图谱、SQLCipher 持久化、账单日历与提醒、加密备份。验证以 `dart analyze` + `flutter test` 为准。
- 平台：仅 Android；不做 iOS 与桌面。
- 分支：日常开发在 `guoxingyun`，稳定后合入 `main`；远程仓库 `xiaodaidai1114/personal-digital-assets`（私有）。
- MVP 清单：✅ 加密核心与解锁 → ✅ 资产 CRUD → ✅ 关系与图谱（含动态效果）→ ✅ 账单日历与提醒 → ✅ 加密备份。

## 技术栈（已定）

- Flutter（Dart），本地优先：数据全部存在手机端加密数据库中，无云端依赖。
- 加密体系：`sqflite_sqlcipher`（加密 SQLite）+ `flutter_secure_storage`（密钥托管）+ `local_auth`（生物识别解锁）。密钥派生当前为 PBKDF2-HMAC-SHA256（210k 次迭代）过渡实现，接口已抽象为 `KeyDeriver`，录入真实数据前替换为 Argon2id。
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
- 修改代码后运行 `flutter analyze`；涉及逻辑改动需补测试并通过 `flutter test`。
- 构建产物不入库：`.apk`、`.aab`、`build/` 等由骨架的 `.gitignore` 排除。

## 常用命令（本机环境）

- Flutter 不在 PATH，完整路径：`C:\dev\flutter\bin\flutter.bat`（3.47.5 stable，2026-09-21 zip 安装）。`C:\dev\pda` 是指向仓库的 junction，gradle/analyze 等命令一律从该路径运行，避开中文路径。
- 每次 pub 相关命令前设置国内镜像：`$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'; $env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'`（已写入用户环境变量）。
- 仓库路径含中文会导致 `flutter analyze` 崩溃（analysis_server LSP bug），验证用 `dart analyze` + `flutter test`。
- JDK 17（Temurin `C:\dev\jdk-17.0.20.1+1`）与 Android SDK（`C:\dev\android-sdk`：platform-tools、platforms;android-36、build-tools;36.0.0，licenses 已接受）已于 2026-09-21 重装。gradle 需 `JAVA_HOME` 指向该 JDK，flutter CLI 需 `ANDROID_HOME=C:\dev\android-sdk`（已用 `flutter config --android-sdk` 持久化）。
- 打 APK：**必须在 `C:\dev\pda-release` worktree（`git worktree add --detach C:/dev/pda-release <commit>`）里构建**——flutter 工具会把 junction `C:\dev\pda` 规范化回中文真实路径，gen_snapshot/AOT 读不了非 ASCII 路径（app.dill 报 Unable to read file，exit 255）。构建前把 `android/local.properties` 复制过去；产物在 `build\app\outputs\flutter-apk\app-release.apk`。
- 发 Release：本机 `api.github.com` 不通（Clash 规则所致，`uploads.github.com` 走 `http://127.0.0.1:7897` 代理可用）。流程：更新 `.github/release-notes/<版本>.md` → 推 `release-v<版本>` 触发 tag（workflow 建 Release 并把 release id 推到 `release-meta` 分支）→ `git fetch` 读 `.release-id` → 本地 curl 走 7897 把 APK POST 到 `uploads.github.com/repos/<repo>/releases/<id>/assets` → 删除 `release-meta` 分支与触发 tag。参考脚本 `C:\dev\release_v130.sh`。
- Gradle 发行包走腾讯镜像（`android/gradle/wrapper/gradle-wrapper.properties` 已配置）；maven 依赖走阿里云镜像（`android/settings.gradle.kts`、`android/build.gradle.kts` 已配置，另 `C:\Users\admin\.gradle\init.d\cn-mirrors.init.gradle.kts` 为 flutter SDK 自带构建注入镜像），官方源在本机直连会卡死。
- 验证：`flutter analyze` + `flutter test`。
- 本机 git 对 github.com 配置了失效代理（socks5://127.0.0.1:1081），推送时需加参数绕过：`git -c http.https://github.com.proxy= push`。
