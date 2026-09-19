# 设计系统 · 青穹资产云（Airy Vault Nebula）

Digital Asset OS 唯一视觉依据。日常页是"昼"：浅色空气感、白卡、高对比数字；图谱页是"夜"：同族渐变压深的星云。昼夜同源，切换即转场。

## 1. 色彩 Tokens

### 1.1 品牌渐变（青穹轴）

| Token | 值 | 用途 |
|---|---|---|
| `brand/cyan` | `#82E2FF` | 亮青，装饰渐变起点 |
| `brand/blue` | `#AED8FF` | 天蓝，装饰渐变中段 |
| `brand/violet` | `#9F86FF` | 淡紫，装饰渐变终点 |
| `gradient/light` | `180°: #82E2FF → #AED8FF → #9F86FF` | 页面装饰底、解锁页背景（其上文字必须用深色） |
| `gradient/hero` | `180°: #5A4FD8 → #1F7FB8` | 统计卡底（其上用白字；小字置于上半区） |
| `gradient/nebula` | `180°: #101A3C → #2B1E52` | 图谱页固定夜底 |

### 1.2 昼模式（日常页默认）

| Token | 值 | 对比度 | 用途 |
|---|---|---|---|
| `day/bg` | `#F3F4F9` | — | 页面中性底（列表区） |
| `day/surface` | `#FFFFFF` | — | 卡片 |
| `day/surface-frosted` | `rgba(255,255,255,.72)` + blur 20 | — | 封缄敏感卡 |
| `day/text-primary` | `#16181D` | 16.7:1 on surface | 标题/正文 |
| `day/text-secondary` | `#5A6072` | 5.9:1 | 次要信息 |
| `day/text-tertiary` | `#8A90A2` | 3.2:1 | 仅限 ≥18sp 或图标 |
| `day/outline` | `#E3E6F0` | — | 分隔线、输入框描边 |
| `accent/primary` | `#6355E8` | 白字 5.3:1 | 主按钮、选中态 |
| `accent/link` | `#5A4FD8` | 5.9:1 on surface | 文字链接 |
| `danger` | `#C93B3B` | 5.0:1 | 删除、错误 |
| `warning` | `#A56512` | 4.7:1 | 到期提醒文案 |
| `success` | `#1E7F5C` | 5.3:1 | 成功反馈 |

### 1.3 夜模式（系统深色 + 图谱页）

| Token | 值 | 对比度 | 用途 |
|---|---|---|---|
| `night/bg` | `#101426` | — | 页面底 |
| `night/surface` | `#1A2038` | — | 卡片（配 1px `rgba(255,255,255,.08)` 描边替代阴影） |
| `night/text-primary` | `#ECEDF5` | 14.1:1 | 标题/正文 |
| `night/text-secondary` | `#A7ADC4` | 7.2:1 | 次要信息 |
| `graph/node` | `#F5F7FF` | — | 星点/标签文字 |
| `graph/edge` | `rgba(255,255,255,.28)` | — | 关系连线，选中边用类型 light 色 |

### 1.4 九类资产色（类型索引环）

色彩 + 图标 + 文字三重编码，色不是唯一信息载体。昼模式文字/图标用 deep（全部 ≥4.5:1 on surface），底色用 deep 12% 透明度的 tint；夜模式用 light 变体。

| 类型 | deep（昼·文字/图标） | light（夜·文字/图标） | 图标（Material Symbols outlined） |
|---|---|---|---|
| 邮箱 email | `#0E7490` | `#7DD8F2` | `mail` |
| 订阅 subscription | `#5A4FD8` | `#B4A6FF` | `autorenew` |
| API Key apiKey | `#2D4ED8` | `#9DB2FF` | `key` |
| 密码 password | `#0C7A57` | `#63D6AE` | `password` |
| 设备 device | `#9A5B00` | `#F3B95F` | `devices` |
| 物品 item | `#8A4B2A` | `#E0A87B` | `inventory_2` |
| 账单 bill | `#C0245C` | `#F287A9` | `receipt_long` |
| 银行卡 bankCard | `#8A6D00` | `#E8CF6B` | `credit_card` |
| 其他 other | `#555B6E` | `#B8BEDA` | `category` |

## 2. 字体系统

- 中文：Noto Sans SC（400 / 500 / 700），系统字体兜底。
- 数字：默认字体 + `FontFeature.tabularFigures()`，用于金额、日期、进度——账务对齐是语义需求，不是装饰。
- 字阶（sp，字号/行高）：

| Token | 值 | 用途 |
|---|---|---|
| `type/display` | 32/40 · 700 | 统计卡大数字 |
| `type/headline` | 24/32 · 700 | 页面主标题 |
| `type/title-lg` | 18/26 · 700 | 卡片标题 |
| `type/title-md` | 16/24 · 500 | 区块标题、按钮 |
| `type/body` | 14/22 · 400 | 正文 |
| `type/label` | 12/16 · 400 | 辅助说明（≥4.5:1 颜色） |

## 3. 间距、圆角、高度

- 间距：4dp 基；常用 8 / 12 / 16 / 20 / 24 / 32；卡片内边距 16；屏幕左右边距 16。
- 圆角：卡片 20、对话框 24、输入框 14、徽章 full、FAB 20。
- 触控目标 ≥48×48dp。
- 昼模式阴影：卡片 `0 2 8 rgba(23,28,64,.06)`；浮起 `0 6 20 rgba(23,28,64,.10)`；hero 卡 `0 10 32 rgba(90,79,216,.16)`。夜模式以描边替代阴影。

## 4. 组件规格

### 4.1 Hero 统计卡
`gradient/hero` 底、20dp 圆角；白字大数字（`type/display` tabular）+ 标签；进度条轨道 `rgba(255,255,255,.30)`、填充 `#FFFFFF`。用于：资产总数、本月账单、临期提醒（续费倒计时进度）。

### 4.2 资产卡
白卡（夜 surface）、20dp 圆角、卡片阴影；左 40dp 类型徽章（tint 底 + deep 图标）；中：标题 `type/title-lg` + meta 行（类型 · 标签，`text-secondary`）；右侧：账单类型显示金额（tabular 700，bill deep 色），其他显示 chevron。按压：阴影升至浮起级。

### 4.3 类型徽章
40dp 圆（大）/24dp（列表外场景）；底 = 类型 deep 12% tint；图标 = deep。选中态加 2dp deep 描边。

### 4.4 封缄敏感卡
frosted surface + blur；锁定态：居中 `password` 图标 + "敏感内容已加密" + "显示"按钮；显示态：大号明文 + 复制 + 隐藏，8 秒无操作自动隐藏（未来接剪贴板清除）。

### 4.5 关系行
`link` 图标 + "关系类型：对方名称" + 方向说明（当前资产 → 关联资产 / 反向）；右侧"在图谱中查看"入口（未来）。

### 4.6 筛选 Chip
"全部" + 九类；选中：类型 tint 底 + deep 文字 + 描边；未选中：surface 底 + outline。图谱页用深色 frosted 变体。

### 4.7 空状态
统一插画语言：渐变晕底 + 单笔触线性图标 + 一句主文案 + 一个行动按钮。禁止情绪化文案，空状态是行动邀请。

### 4.8 解锁卡
`gradient/light` 页面底（浅）上居中白色圆角卡；busy 态按钮变进度条并显示"正在生成密钥（210,000 次迭代加固）"——把等待变成信任时刻。

## 5. 动效 Tokens

| Token | 值 | 用途 |
|---|---|---|
| `motion/fast` | 120ms | 按压、chip 切换 |
| `motion/medium` | 240ms | 卡片展开、封缄开合（blur + opacity） |
| `motion/slow` | 400ms | 解锁渐变展开、图谱入夜 crossfade |
| `motion/easing` | `cubic-bezier(0.2, 0, 0, 1)` | 通用 |

解锁转场：`gradient/hero` 自上而下展开后淡出到主界面；图谱入夜：背景 crossfade + 星点渐次点亮（≤600ms 总时长）。尊重系统"减少动画"设置，此时改用 0ms 直接切换。

## 6. 无障碍检查点

- 正文对比 ≥4.5:1、大字与图形 ≥3:1（上表已验证）。
- 图标按钮必须带语义标签；类型信息 = 色 + 图标 + 文字三重编码。
- 动态字号 1.3× 下卡片不溢出：标题单行省略、meta 可换行、金额右对齐独立列。
- 焦点可见（2dp 描边或主题焦点环），Tab/读屏顺序 = 视觉顺序。
