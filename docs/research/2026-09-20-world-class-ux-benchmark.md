# 世界级资产管理工作台竞品调研

日期：2026-09-20
范围：移动端资产管理、密码库、订阅/API Key、关系图谱。所有外部结论优先采用官方支持文档、官方产品页或官方源码；未采用第三方评测作为依据。

## 结论摘要

当前版本的核心问题不是缺少动效，而是产品对象模型没有转化成高效的工作流：

1. **资产页把“类型”当成唯一导航**。九类资产靠横向滑动，且只能单选；缺少搜索、标签、收藏、状态、排序、结果计数与清除条件。
2. **新增/编辑表单过于通用**。所有类型共用“名称 + 逗号标签 + 一个敏感内容”结构，无法体现订阅、API Key、账单、设备等真实字段差异。
3. **图谱缺少语义编码**。Android WebView 当前使用固定节点尺寸，关闭 many-body 斥力，边长和线宽固定；视觉上是星云装饰，不是可分析的关系工具。
4. **竞品的共同范式是：搜索先行 + 当前范围 + 多维筛选 + 高优先级置顶 + 安全/临期任务**，而不是一排类型 chip。
5. **Obsidian 图谱的价值来自可解释交互**：节点度数决定大小、悬停高亮一跳邻域、全局/局部图、过滤与分组、力参数可调、时间演化；这些都能迁移到资产关系图。

## 现状诊断

### 资产列表

代码证据：

- `lib/ui/asset_list_screen.dart:32` 只有 `AssetType? _typeFilter` 一个筛选状态。
- `lib/ui/asset_list_screen.dart:145` 三个统计卡使用 `PageView`，用户必须横滑才能看到关键状态。
- `lib/ui/asset_list_screen.dart:166` 九类资产使用横向 `SingleChildScrollView`，正是用户需要长时间左滑的原因。
- `lib/ui/asset_edit_screen.dart:143` 标签靠逗号输入；`lib/ui/asset_edit_screen.dart:157` 不同资产共用同一个敏感内容输入。

体验后果：

- “找资产”的路径过长：用户必须先找到类型 chip，再逐条目视扫描。
- 筛选不可组合：无法表达“已收藏 + AI 标签 + 30 天临期”。
- 统计卡与任务脱节：看到“30 天临期提醒”后仍要自己找是哪几条。
- 类型既是数据模板，又是唯一导航维度，导致类型数量增长后导航成本线性增加。

### 图谱

代码证据：

- `assets/graph/g6.html:25` 节点固定 `34px`。
- `assets/graph/g6.html:66` 使用 `type: 'force'`。
- `assets/graph/g6.html:68` 显式设置 `manyBody: false`，关闭节点间斥力，容易聚团。
- `assets/graph/g6.html:71` 只有画布拖拽、缩放、节点拖拽，缺少邻域高亮、局部图、搜索定位、分组、时间动画。

### 视觉

- 首页同时出现大渐变统计卡、圆角资产卡、彩色类型 chip、FAB，层级全部近似，信息密度低。
- 类型颜色承担了过多装饰功能；顶级密码管理器通常只在图标与小面积状态上使用语义色。
- 入场动效覆盖列表项，但没有表达对象关系或用户任务；动效应转向“打开、筛选、定位、关联”等状态变化。

## 竞品与规范调研

### 1Password：类型是模板，搜索和关联是主路径

来源：

- [Item categories](https://support.1password.com/item-categories/)
- [Search in the 1Password app](https://support.1password.com/search-1password/)
- [Organize with favorites and tags](https://support.1password.com/favorites-tags/)
- [Link related items](https://support.1password.com/link-items/)
- [Watchtower](https://support.1password.com/watchtower/)

可验证模式：

- 常见类型包括 Login、Secure Note、Credit Card、Identity、Password、Document；扩展类型包括 API Credential、Bank Account、Crypto Wallet、Database、Email Account 等。每类有不同字段模板。
- 搜索结果包含 item、tag、category、vault，并匹配标题、section、字段和备注；可用精确短语。
- 搜索过滤包含 Location、Passkey、Untagged、Favorites、Tags、Categories、Vaults，可继续叠加关键词。
- Favorites 用于快速访问；Tags 无数量上限，可多标签、嵌套，用于之后缩小搜索。
- 相关条目在详情页展示，点击即可跳转；链接是单向的，一对条目可双向各建一条。
- Watchtower 按安全问题分类，只展示有条目的分类，并在条目内继续显示告警；可按账户/集合缩小范围。

对本产品的启发：

- 类型选择应发生在“新增资产”时，列表页不要把类型作为唯一入口。
- 搜索需要同时检索标题、标签、普通字段、关联对象；类型与标签可以成为搜索 token。
- 收藏/置顶、未打标签、无关联、临期、风险状态应成为一等筛选条件。
- 资产详情必须把“关联资产”作为核心区块，而不是附属操作。

### Bitwarden：搜索受当前筛选范围约束

来源：

- [Search your Vault](https://bitwarden.com/help/searching-vault/)
- [Filter your Vault](https://bitwarden.com/help/filter-your-vault/)
- [Vault Health Reports](https://bitwarden.com/help/reports/)

可验证模式：

- 搜索结果取决于当前 filter 或导航选中的 vault、folder、collection、type。
- Web 端顶部提供 Vault、Collection、Folder、Type 选择器；移动端从左侧列选择筛选条件。
- 支持按字段搜索、通配符和高级查询。
- 安全报告本地运行，暴露密码、复用密码、弱密码、未启 2FA 等按问题分组。

对本产品的启发：

- 搜索栏应显示当前范围，例如“全部 / API Key / AI 标签”；搜索只在当前结果集内继续过滤。
- 筛选器必须有结果计数、已选条件、清空按钮和稳定状态。
- 安全面板可从本地可判断的问题开始：弱/复用敏感内容、无关联、无备份、临期未处理，不需要先做云端泄露检测。

### Proton Pass：模板化创建、置顶与批量组织

来源：

- [Use Proton Pass on Android](https://proton.me/support/use-pass-android)
- [Pin an item](https://proton.me/support/pin-item-proton-pass)
- [Bulk select items](https://proton.me/support/pass-bulk-select-items)
- [Create a custom item](https://proton.me/support/create-custom-item)

可验证模式：

- Android 端可创建 login、alias、note、password、credit card、identity、WiFi、passport 或 custom item。
- Login 中包含用户名、密码、URL、2FA、备注，并可添加自定义字段。
- 置顶条目始终出现在列表顶部。
- 批量选择用于移动、删除、整理多个条目。

对本产品的启发：

- 新增流程应先选类型，再出现类型专属字段；仍保留自定义字段兜底。
- 首页应有“置顶 / 收藏”分区，不要把所有资产平铺。
- 达到一定资产量后需要多选批量打标签、删除、关联。

### Dashlane：风险不是数字，而是下一步行动

来源：

- [Personal password manager](https://www.dashlane.com/personal-password-manager)
- [Credential Protection](https://www.dashlane.com/features/credential-protection)

可验证模式：

- 弱密码、泄露、数据泄露会给出告警和下一步处理建议。
- 风险能力覆盖弱密码、复用凭据、compromised credentials、钓鱼与暗网洞察。

对本产品的启发：

- 首页安全/临期模块应从“统计数字”改为“任务卡”：最多展示 3 条可处理事项，点击直达资产并给出建议动作。
- 对本地优先产品，第一阶段可做本地风险：临期订阅、未关联账单、无恢复邮箱、敏感内容为空、重复标题。

### Obsidian Graph View：关系图的核心是聚焦与解释

来源：[Graph view](https://help.obsidian.md/graph/view)

官方文档明确的能力：

- 圆圈是节点，线是内部链接；被引用越多节点越大。
- 悬停高亮该节点连接；点击打开；右键显示可用操作。
- 支持缩放、拖拽与键盘导航。
- Filters 支持 Search files、Tags、Attachments、Existing files only、Orphans。
- Groups 通过查询表达式创建颜色分组。
- Display 支持 Arrows、Text fade threshold、Node size、Link thickness、Animate。
- Forces 支持 Center force、Repel force、Link force、Link distance。
- Time-lapse 按创建时间依次出现节点。
- Local Graph 只显示当前对象的连接，并可调整深度。

对本产品的启发：

- 节点大小应由关系度数或资产重要性决定，而不是固定值。
- 点击节点不应立即离开图谱；先高亮一跳邻域并弹出摘要，用户再选择“查看详情”。
- 需要全局图与局部图两种模式：全局看资产群，局部看某个订阅、邮箱、账单的上下游。
- 边的粗细/颜色应编码关系类型或强度；箭头可开关。
- 标签按缩放级别淡入，避免小缩放时文字糊成一片。

### AntV G6 官方示例：应使用 `d3-force` 语义参数

来源：

- [layout-force-lattice.ts](https://github.com/antvis/G6/blob/master/packages/g6/__tests__/demos/layout-force-lattice.ts)
- [case-unicorns-investors.ts](https://github.com/antvis/G6/blob/master/packages/g6/__tests__/demos/case-unicorns-investors.ts)

可验证模式：

- 官方示例使用 `type: 'd3-force'`、`manyBody.strength`、`link.distance/strength/iterations`。
- 大图示例按节点尺寸设置 `collide.radius`，many-body 斥力随节点尺寸变化，并用 `drag-element-force` 保持力反馈。
- 官方示例还有 `hover-activate`、`inactiveState`、tooltip、autoFit、map-node-size 等能力。

对本产品的启发：

- Android 图谱应从当前 `force + manyBody:false` 切到 `d3-force`。
- 使用 `collide` 防重叠，`manyBody` 负责展开，`link.distance` 按关系类型/强度变化。
- 使用 `hover-activate` / tap-activate 做邻域高亮，非邻域降透明。
- 使用 `drag-element-force` 让拖拽具有物理反馈，而不是拖完又弹回。

### Material 3

来源：

- [Search](https://m3.material.io/components/search/overview)
- [Chips](https://m3.material.io/components/chips/overview)
- [Navigation bar](https://m3.material.io/components/navigation-bar/overview)
- [Motion](https://m3.material.io/styles/motion/overview)

可验证模式：

- Search 支持关键词输入并在输入时提供建议。
- Chips 用于输入、选择、过滤内容或触发动作。
- Navigation bar 面向小屏幕视图切换。
- Motion 应让 UI 有表现力且易于使用。

对本产品的启发：

- 搜索栏应位于列表上方并持久可见；建议词来自最近搜索、置顶资产、标签和类型。
- Filter chip 只承载快捷条件，完整筛选放 bottom sheet。
- 动效必须服务于状态解释：筛选结果变化、节点聚焦、抽屉展开、锁定解锁。

## 重设计方案

### 1. 信息架构

保留四个底部入口，但重定义职责：

1. **资产**：搜索、筛选、置顶、任务、全量列表。
2. **图谱**：全局关系探索与局部关系聚焦。
3. **日历**：账单与续期时间轴。
4. **设置**：安全、备份、偏好。

资产页第一屏改为：

```text
┌──────────────────────────────────────────────┐
│ 我的资产                         头像/锁定   │
│ ┌──────────────────────────────┐ ┌────────┐ │
│ │ 搜索标题、标签、字段、关联    │ │ 筛选 2 │ │
│ └──────────────────────────────┘ └────────┘ │
│ [全部] [置顶] [密码] [API] [订阅] [更多 ▾]   │
│ 已选：AI · 30 天内到期 · 2 个条件 [清除]     │
├──────────────────────────────────────────────┤
│ 需要处理                                     │
│ ├ AI 订阅 9/28 续费 · $20       [查看]      │
│ └ API Key 未绑定设备           [关联]       │
├──────────────────────────────────────────────┤
│ 置顶                                         │
│ ┌ OpenAI API Key  · AI · 3 关联         ☆  │ │
└──────────────────────────────────────────────┘
```

规则：

- 顶部搜索常驻；点击后展开全屏搜索，包含最近搜索、建议、标签、类型和资产结果。
- 快捷 chip 最多 5 个；“更多”打开筛选 sheet，不再要求用户横向滑过九类。
- 已选条件以 token 展示，可单个删除或全部清除。
- “需要处理”最多 3 条，展示到期、无关联、敏感内容缺失等可行动问题。
- 统计信息压缩为小面积摘要，不再使用横滑 hero card。

### 2. 筛选系统

筛选 bottom sheet 分五组：

1. **类型**：多选，九类，每项显示数量。
2. **标签**：多选，来自真实资产，支持包含/排除。
3. **状态**：置顶/收藏、30 天临期、未关联、未打标签、有金额、已逾期。
4. **时间**：更新时间、到期时间、账单月份。
5. **排序**：最近更新、到期时间、名称、关系数量。

底部固定操作条：

```text
当前 12 条        [重置] [应用筛选]
```

必须支持的组合示例：

- `type = subscription OR apiKey` + `tag = AI`
- `favorite = true` + `dueWithin = 30d`
- `relations = 0` + `type != bill`
- `tag != 已归档` + `sort = dueDate`

### 3. 资产列表项

从“大卡片”改为“高信息密度分组列表”：

```text
┌─────────────────────────────────────────────┐
│ [icon] OpenAI API Key            ☆  ⋯      │
│        API Key · AI · 3 关联 · 更新 9/18    │
│        [9/28 续费] [绑定设备]               │
└─────────────────────────────────────────────┘
```

设计规则：

- 行高 68–76dp，触控目标不低于 48dp。
- 类型色只用于图标底色或小标识，不做大面积渐变。
- 第二行必须回答“这是什么、和什么有关、何时到期”。
- 置顶、临期、未关联、风险徽标最多显示两个，避免噪声。
- 长按进入多选；滑动操作用于置顶/归档，删除保留在菜单中并二次确认。

### 4. 新增与编辑

新增入口先弹 bottom sheet 选择类型，再进入类型模板：

- **订阅**：服务名、套餐、周期、金额、下次续费、支付方式、绑定邮箱、自动续费。
- **API Key**：服务、环境、前缀、权限范围、负责人、过期时间、存放设备、恢复邮箱。
- **账单**：金额、账单日、周期、支付方式、关联订阅、是否已付。
- **邮箱**：地址、恢复邮箱、2FA、密码、用途标签。
- **设备**：型号、系统、序列号、保修到期、存放 Key。
- **密码**：站点、用户名、密码、URL、备注。

所有类型保留：

- 标签 token 输入，支持新建、建议、删除。
- 自定义字段。
- 关联创建入口。
- 敏感字段封缄状态，编辑时明确“留空保持不变”。

### 5. 资产详情

详情页结构：

1. 标题与类型徽标，右上角更多菜单。
2. 常用动作条：显示/隐藏、复制、打开、编辑、置顶。
3. 类型字段分组，不做一张无差别大卡。
4. 关联资产列表，显示方向与关系类型；每行提供“查看”和“局部图谱”。
5. 局部图谱预览：默认一跳，可切两跳。
6. 安全与时间信息：更新时间、备份状态、临期、风险。

### 6. Obsidian 式图谱

#### 布局

- 使用 `d3-force`：
  - `manyBody.strength` 随节点度数增强，例如 `-160 - degree * 40`。
  - `collide.radius = nodeRadius + 8`。
  - `link.distance` 按关系类型：支付/绑定 110–130，弱关联 170–220。
  - `link.strength` 支付/绑定强于备注/恢复。
- 节点半径：`20 + degree * 6`，上限 48；置顶或当前资产额外加成。
- 初始布局按类型分区或圆形播种，再让力导向微调，避免随机聚团。

#### 交互

- 点击节点：高亮一跳邻域，其余节点降透明；底部出现摘要 sheet。
- 二次点击“查看详情”才进入资产详情。
- 搜索节点：输入后自动 focus + fit，匹配节点外圈脉冲。
- 局部模式：1–2 跳深度，详情页也可嵌入。
- 长按：菜单包含查看详情、添加关联、置顶、隐藏此类型。
- 双击空白：fit view；拖拽节点时暂停其他动画，释放后 reheat。
- 关系边点击显示关系详情。

#### 视觉

- 夜底保留，但减少大面积辉光和星点噪声。
- 节点：类型色描边 + 低饱和填充；当前/邻域高亮，非邻域 20% 透明。
- 边：默认细线；选中邻域后按关系类型着色；箭头可开关。
- 标签：按缩放阈值淡入，避免全部常显。
- 背景：细点阵或极弱网格，提供空间感。
- 图例：类型、关系、当前筛选；可折叠。

#### 动效

- 初次渲染：节点从中心按度数依次出现，总时长 500–700ms。
- 筛选：被移除节点淡出，保留节点平滑重排。
- 聚焦：相机 ease-in-out 移动到目标，邻域高亮 120ms 延迟出现。
- 拖拽：节点跟随，释放后阻尼回弹。
- 时间轴：按资产创建/更新/到期时间播放，可 scrub。
- 系统减少动画时关闭常驻星闪与时间动画，仅保留直接状态切换。

## 视觉方向建议

### 主题

把“青穹资产云”从大面积渐变改成“清晰的云端仪器台”：

| Token | 建议值 | 用途 |
|---|---:|---|
| `canvas/day` | `#F6F7FB` | 日常页面背景 |
| `surface/raised` | `#FFFFFF` | 列表、sheet、输入 |
| `ink/primary` | `#111827` | 主文本 |
| `ink/secondary` | `#5F6676` | 次级文本 |
| `accent/sky` | `#0EA5B7` | 主操作、焦点 |
| `accent/violet` | `#6355E8` | 图谱与关联 |
| `canvas/graph` | `#0A1020` | 图谱页 |

规则：

- 日常页不用大面积渐变；渐变只保留在图谱背景和解锁品牌瞬间。
- 主按钮使用一个 accent，类型色只做识别，不参与主操作。
- 卡片半径 14–18dp，同屏最多两层 elevation。
- 列表左右 16dp、组间距 24dp、标题区上下 12dp。
- 图标 20–22dp，正文 14–15dp，标题 17–18dp，数字用 tabular figures。

### 文案

- 筛选按钮显示数量：“筛选 · 2”。
- 空结果写清条件：“没有同时包含 AI 标签且 30 天内到期的资产”。
- 任务卡写行动：“9 月 28 日将续费 $20”，按钮“查看订阅”。
- 图谱空状态：“先添加资产，星图会在这里点亮”；无关系：“从资产详情添加第一条关联”。

## 分阶段落地

### P0：先解决找资产

1. 增加常驻搜索：标题、标签、普通字段。
2. 增加筛选 bottom sheet：类型多选、标签多选、状态多选、排序。
3. 搜索栏下方展示已选 token、结果数、清除按钮。
4. 快捷 chip 改为最多 5 个 + “更多”。
5. 增加置顶/收藏字段和列表分区。
6. 列表项补齐上下文信息与状态徽标。

验收：

- 不需要横滑超过一屏才能到达目标类型。
- 任意资产 3 次点击/输入内可定位。
- 复杂筛选可组合、可清除、可看见结果数。

### P1：重做图谱

1. 切换 `d3-force`，启用 manyBody、link、collide。
2. 节点半径与颜色编码度数/类型。
3. 点击高亮一跳邻域，其余降透明。
4. 增加全局/局部模式与深度 1–2。
5. 增加类型、标签、关系过滤和图例。
6. 增加搜索定位、fit view、拖拽 reheat。

验收：

- 100 个节点、200 条边时不出现重叠团块。
- 点击任意节点能立即解释它的上下游。
- 从图谱到目标资产详情不超过两步。

### P2：任务化与安全感

1. 首页任务卡：临期、无关联、敏感内容缺失、重复标题。
2. 详情页局部图谱预览。
3. 类型模板表单与标签 token 输入。
4. 多选批量打标签/归档/删除。
5. 安全面板按本地规则分组。

验收：

- 首页前两屏内能看到需要处理的资产。
- 每个风险/临期状态都有明确下一步动作。
- 常见类型的创建不需要用户理解自定义字段。

## 明确不做

- 不做明文导出。
- 不为了视觉引入真实个人数据截图。
- 不做常驻、无语义的炫光动画。
- 不用类型数量扩张绑架导航结构；新增类型进入模板系统和筛选器，而不是增加首页横滑长度。
