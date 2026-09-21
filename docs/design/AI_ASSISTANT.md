# AI 助手架构设计(不破坏加密红线)

> 状态:设计稿,尚未实施。实施前先读 `AGENTS.md` 安全红线与本文第一节。

## 一、总原则

**模型永远不进入保险库,数据以脱敏投影的形式流出到模型;模型只能"提议",不能"执行"。**

现有红线"明文永不落盘、不写日志"对 AI 领域的等价表述:

> 封缄字段解密后的明文,永远不进入 assistant 模块的任何一条代码路径。

不是"不发给云端",是"assistant 代码拿都拿不到"。这样即使 assistant 模块出 bug、被提示注入、日志打错位置,泄露面也是零。

## 二、信任三层模型

| 层 | 内容 | 端内模型 | 云端模型 |
|---|---|---|---|
| L0 封缄层 | 完整密码、API Key、完整卡号(加密存储) | 不可见 | 不可见 |
| L1 结构层 | 资产类型、标签、资产名、普通字段(后四位/短前缀)、关系边、账单金额与日期 | 可见 | 默认不可见 |
| L2 聚合层 | 计数、分类汇总、金额区间(如"100–500 元")、月份分布 | 可见 | 可见(仍需用户逐次确认) |

- L0/L1 分界线 = `AssetFieldPolicy`(`lib/domain/asset_field_policy.dart`)。**不发明新的敏感度判断,复用现有正则**,保证"人工编辑不允许存的"和"AI 看不到的"是同一条线,永不漂移。
- L1/L2 分界是金额与具体资产名,可配置,默认从严:云端只拿 L2。

## 三、架构与数据流

```
SQLCipher 加密库
   │  (解密仅发生在 vault/data 层)
   ▼
AssetRepository ─── 封缄字段只进不出(详情页手动查看)
   │
   │  AssistantProjection(唯一出口,白名单字段 + 复用 FieldPolicy)
   ▼
AssetSummary(DTO:无封缄、无完整凭证、金额可降级为区间)
   │
   │  ToolRegistry(显式注册的只读工具,返回 Summary 类型)
   ▼
AssistantSession(内存态,绑定解锁状态,锁定即销毁)
   │
   ├── 端内模型:直接消费 L1
   └── 云端模型:再降级到 L2 → UI 展示 payload 预览 → 用户确认 → 发送
```

### 目录规划

```
lib/assistant/
  projection.dart    # AssetSummary 投影 + DisclosureLevel 降级
  tools.dart         # 工具白名单注册表
  session.dart       # 会话生命周期,监听 vault lock 状态
  intent.dart        # EditIntent 定义(写路径的结构化提议)
  model/             # 模型适配层:on_device.dart / cloud.dart / fake.dart
```

### 组件职责

**1. 投影层(最核心)**

`AssistantProjection.toSummary(Asset asset, {DisclosureLevel level})` 是所有喂给模型数据的唯一出口:

- 白名单式拷贝字段,而非黑名单式剔除——新增敏感字段默认不可见,不会漏。
- 普通字段再跑一遍 `AssetFieldPolicy.sensitivePlainTextError`,拦住用户硬塞进备注的凭证。
- `DisclosureLevel.l1` 保留金额;`.l2` 把金额映射为区间、资产名截断。

**2. 工具白名单**

不把 Repository 接口暴露给模型,显式定义少量语义工具,全部返回 `AssetSummary`:

- `listSubscriptionCosts({range})` — 各订阅月/年成本
- `upcomingBills({withinDays})` — 即将到期的账单
- `findAssets({type, tag})` — 按类型/标签检索
- `graphNeighbors({assetId})` — 某资产的关联资产(图谱查询)

工具少而结构化,较弱的端内模型也能可靠完成任务——这直接决定能否不上云。

**3. 写路径:intent + 人工确认**

模型没有执行权。与通用 agent 框架的最大分野:保险库场景里 agent 直接写库不可接受。

```
用户:"帮我把 ChatGPT 订阅标记成已取消"
  → 模型产出 EditIntent{assetId, patch: {status: cancelled}}
  → UI 渲染 diff("将 订阅状态:生效 → 已取消")
  → 用户点确认
  → 走现有 saveAsset 校验链(FieldPolicy 照常拦截)
```

模型永远产不出 SQL、调不了 Repository,只能产出结构化意图;执行入口与人工编辑相同,校验规则零新增。

**4. 会话生命周期与锁联动**

`AssistantSession` 持有投影缓存(内存中的 L1 明文)。监听 `lib/vault/auto_lock.dart`:锁定时清空会话上下文与投影缓存,助手界面回到锁定态;解锁后重新投影,不复用旧缓存。

**5. 模型选择:先端内,后云端**

| | 端内模型 | 云端模型 |
|---|---|---|
| 可见层 | L1(含金额) | L2(聚合) |
| 外发数据 | 无 | 有(架构上首次出现外发通道) |
| 能力 | 弱,依赖工具层设计 | 强 |
| 与产品定位 | 完全一致("本地优先") | 需显式开关 + 逐次确认 |

Android-only 是优势:Gemini Nano(AICore)或 MediaPipe 跑 Gemma 小模型,覆盖"哪个订阅最贵""这个月有什么账单"类查询。第一个版本只做端内,产品可继续承诺"零数据外发";云端作为后期可选增强,开启时设置页展示"将发送内容的示例"。

`model/fake.dart`(规则匹配假模型)先行,把投影、工具、确认流全部走通并测好——加密红线相关架构在没有任何 LLM 时就已定型并受测试保护。

## 四、攻击面防护

**提示注入**:资产名、备注是用户自己写的,风险低;未来若加"导入备份""OCR 识别账单",外部文本进入 L1,可能夹带注入指令。防护两条:

1. prompt 中所有投影数据明确标注为不可信数据;
2. 工具层只读 + intent 确认制——注入最多骗模型产出错误 intent,过不了人工确认这一关。用架构把注入破坏面压到零,不靠 prompt 求模型别上当。

**日志**:assistant 模块只允许记 `(toolName, args, 时间)`,不记返回值、不记 prompt 全文。投影数据可记(本就是脱敏的),封缄路径物理上不经过这里。

## 五、测试与护栏清单

1. **投影零泄露测试**:对 `lib/data/demo_data.dart` 全量资产跑投影,断言输出不含任何封缄明文,且 `AssetFieldPolicy.sensitivePlainTextError` 对输出每一段都返回 null(复用现有正则做扫描器)。
2. **类型系统隔离**:`AssetSummary` 不含 `sealedContent` 字段;assistant 模块 import 不到 `Asset` 的封缄访问器。
3. **锁定清除测试**:模拟 auto-lock 触发,断言会话上下文与投影缓存被清空。
4. **intent 确认测试**:intent 未确认前数据库无变更;确认后经过完整校验链。
5. **云端默认关闭**:首次开启展示脱敏样例 payload。

## 六、演进路线

1. **阶段一(纯本地,无模型)**:projection + tools + fake 模型 + 确认流,全部测试覆盖——已有可演示的"指令式 UI",红线架构定型。
2. **阶段二(端内模型)**:接 Gemini Nano / MediaPipe,查询类能力上线,仍承诺零外发。
3. **阶段三(可选云端)**:L2 聚合 + 逐次确认的云端增强,默认关闭。

每一步都没有不可逆决定,加密体系零改动——AI 是加在保险库外面的"隔窗观察员",不是给它钥匙。
