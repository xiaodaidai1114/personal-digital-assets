# 设计系统 · 青穹资产云（Airy Vault）

产品契约见 [DESIGN.md](DESIGN.md)。本文件只保留实现时最常查的锁点；冲突时以 `DESIGN.md` 为准。

## 视觉基底

- 视觉基底为 getwidget 7.0.2 默认风格；Material 主题（M3 ColorScheme）由 AppSkin 色对驱动，原生亮暗双主题（`ThemeMode` 亮 / 暗 / 跟随系统），暗色不是滤镜。
- GF 组件不读 ThemeData：一切 GF 用法必须显式传 `context.skin` 颜色，禁止落回 GFColors 默认值（暗色下会翻车）。卡片统一走 `_SkinCard` / `_DetailCard`（GFCard：surface + outline 8dp 描边 + 零边距 + 零 elevation）。
- 列表行高 56；卡片圆角 8；对话框与底部抽屉圆角 12；无阴影，层级靠 canvas/surface/surfaceAlt/outline 表达。
- 按钮最小高度 48；金额、日期、倒计时、版本号使用 tabular figures 并右对齐。
- 类型色默认关闭：类型用线框图标 + 文字表达（AssetTypeBadge）。
- 动效 fast 140ms / medium 220ms / slow 360ms；骨架用 GFShimmer。

## Skin Token（lib/theme/app_theme.dart，context.skin）

| Token | 亮色 | 暗色 | 用途 |
|---|---|---|---|
| `canvas` | `#F4F5F8` (GFColors.BACKGROUND) | `#17181D` | 画布 |
| `surface` | `#FFFFFF` | GFColors.DARK | 卡片、模态、抽屉 |
| `surfaceAlt` | `#F4F5F8` | `#2B2D34` | 输入槽、选中态、骨架 |
| `outline` | `#E0E0E0` (GFColors.LIGHT) | `#3A3D45` | 1px 细线、描边 |
| `textPrimary` | `#222428` (GFColors.DARK) | `#F4F5F8` | 标题、正文 |
| `textSecondary` | `#616569` | `#B3B8C4` | 元信息（≥4.5:1） |
| `textTertiary` | GFColors.NEUTRAL | — | 占位与辅助 |
| `primary` | `#3880FF` (GFColors.PRIMARY) | 同左 | 主按钮、FAB、命中高亮 |
| `onPrimary` | `#FFFFFF` | 同左 | 主色上文字 |
| `danger` | GFColors.DANGER | 同左 | 删除、解锁失败 |
| `success` | `#1A8257` | 同左 | 成功，极少使用 |
| `disabled` | GFColors.DISABLED | `#6B6E76` | 禁用态 |

对比度由 `test/design_system_test.dart` 锁定：正文 ≥4.5:1，强调色 ≥3:1。

## 保留的 Material 残件（GF 缺位）

TextField/TextFormField（表单/倾倒口/面板输入）、chips、SegmentedButton（外观三选）、showModalBottomSheet（草稿卡/批量标签/类型选择）、showDialog+AlertDialog、自绘行 _AssetRow、DashedBorder 封缄卡、_MonthGrid、FAB、ListTile（带 trailing 的行）。

## 禁止项

- 绕过 `context.skin` 写死颜色，或在暗色下使用 GFColors 默认色对。
- 用滤镜/Matrix 假装暗色模式，或为「夜间」单独维护一套页面。
- 青紫渐变、粒子、辉光、毛玻璃、阴影；每类资产一种填色圆；横向长条分类作为主要筛选入口。
- 疑似完整凭据（密码/Key/Token）进入普通字段或 UI 明文展示——一律走封缄（加密）内容。
- 空状态、错误文案展示技术细节或情绪化比喻。
