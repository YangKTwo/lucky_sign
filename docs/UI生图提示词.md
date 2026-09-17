# 今日幸运签 UI 生图提示词

以下提示词用于高保真视觉方向探索，不可直接作为开发规范。图中的中文文字可能不完全准确；开发时以 `UI_UX_重新设计方案.md` 的信息结构、组件规格和真实文案为准。

## 推荐方向：今日签行动页

```text
Use case: ui-mockup
Asset type: high-fidelity Android/iOS adaptive mobile app screen, 9:16 portrait
Primary request: A polished Chinese mobile app screen for a private small-group daily habit app called “今日幸运签”. The screen must make one task easy to understand and complete today, not look like a generic game or social feed.
Scene/backdrop: Quiet evening desk mood translated into an interface, stable deep forest-teal top area and calm porcelain-white reading surface, no physical desk objects.
Subject: Daily task home screen. Top safe area with date. Deep teal “today fortune” panel with a compact square seal showing difficulty A, a small lucky-star reward marker, one short fortune sentence, and a precise countdown. Below it, a clean white task section with a long Chinese task sentence, reward points, streak indicator, a slim title-progress line, three quiet supporting stats, and one prominent full-width vermilion primary action button.
Style/medium: Realistic production-ready product UI, Material 3-informed, Chinese typography with system sans serif, high readability, restrained tonal elevation, sparse dividers rather than stacked cards.
Composition/framing: Single full smartphone screen, 393 by 852-like portrait ratio, safe areas visible, 20dp side padding, bottom navigation with four destinations “今日”, “社区”, “排行”, “我的”; 今日 selected. Clear hierarchy, no device frame.
Color palette: deep forest teal #102B2A, porcelain #FCFCF8, white #FFFFFF, vermilion #C8422E only for primary action, community teal #117C82, reward gold #D8A635, muted text #536866.
Text (verbatim): “今日幸运签”, “A · 稳步前行”, “把今天最重要的一件小事做完。”, “距结算 5小时 24分”, “今日任务”, “完成一个拖延已久的小任务，并写下完成后的感受。”, “完成可得 20 分”, “连续 12 天”, “下一称号还差 3 天”, “完成并分享”, “今日”, “社区”, “排行”, “我的”
Constraints: Practical tap targets and spacing, no gradients, no glass panels, no oversized rounded cards, no illustration, no emoji as interface icons, no stock photography, no logos, no watermark, no extra text.
Avoid: beige/cream theme, fantasy fortune-telling clichés, red-and-gold Chinese New Year styling, gaming dashboard, generic card grid, decorative charts.
```

## 备选方向：社区未读与 @我

```text
Use case: ui-mockup
Asset type: high-fidelity Android/iOS adaptive mobile app screen, 9:16 portrait
Primary request: A polished Chinese group-chat screen for a small private daily habit community. It should prioritize new messages that need a response, distinguish @mentions from ordinary unread items, and include a visible check-in activity in the conversation.
Scene/backdrop: A calm porcelain-white conversation surface with a narrow deep forest-teal top app bar; quiet, focused, social but not noisy.
Subject: Chat screen titled “石桥头小圈子”. Under the header, a compact teal actionable strip says there are two messages mentioning the user. Timeline has date dividers, three ordinary messages, one highlighted @mention with a clear @我 label, one check-in activity row showing task completion and rating progress, and one recalled message rendered as muted text. Fixed bottom composer with @ icon, text field and send icon button. Add a small floating chip that jumps to unread messages.
Style/medium: Realistic production-ready product UI, Material 3-informed, Chinese system sans serif, dense but calm timeline, 48dp tap targets, practical controls.
Composition/framing: Single full mobile screen, 393 by 852-like portrait ratio, safe area, no device frame. Community tab selected in bottom navigation with a numeric unread badge.
Color palette: porcelain #FCFCF8, white #FFFFFF, deep forest teal #102B2A, community teal #117C82, warm reward gold #D8A635, muted #536866, action vermilion #C8422E only for destructive confirmation indications.
Text (verbatim): “石桥头小圈子”, “2 条消息 @了你”, “查看”, “今天”, “@你 这个方法很有用，晚点能分享一下吗？”, “小明完成了 A 级任务”, “评分进度 2 / 4”, “这条消息已撤回”, “输入消息”, “今日”, “社区”, “排行”, “我的”
Constraints: Practical message layout, visible unread hierarchy, message bubble styles must not use excessive rounding, no gradients, no glass panels, no decorative illustrations, no logos, no watermark, no extra text.
Avoid: Discord clone, WeChat clone, neon cyberpunk, chat bubbles with huge shadows, generic card grid.
```

## 可用于后续实现的总提示词

```text
你是一名有 15 年移动端产品经验的高级 UI/UX 设计师。请为 Flutter 跨端产品“今日幸运签”设计可直接交付开发的移动端界面系统。用户是需要轻量监督和互相鼓励的小圈子成员；核心任务是每天查看一个幸运签任务、提交文字或照片凭证、在社区中处理未读和 @我、为同伴打卡评分。

请遵循：
1. 先保证 10 秒内看懂“今天任务、截止时间、如何完成”，再做视觉表达。
2. 使用深墨绿 #102B2A、瓷白 #FCFCF8、朱红 #C8422E、社区青 #117C82、奖励金 #D8A635；朱红只用于主操作和风险操作。
3. 采用系统无衬线和 Material 3 组件语义；手机最小触控目标 48dp，iOS 为 44pt；支持大字号和减少动态效果。
4. 取消暖白渐变、大圆角卡片堆叠、无意义奖杯/表情、国潮玄学装饰和游戏化仪表盘。
5. 用“夜间签册”作为隐喻：沉静、有行动方向、可长期使用；不要画成真实书桌或插画场景。
6. 设计今日、社区、排行、我的四个一级页面，并给出默认、加载、空、错误、已完成、未读/@我、消息撤回、管理员删除等状态。
7. 输出页面信息架构、组件规格、状态和交互说明，并针对 Flutter Material 3 标注可复用组件。
```
