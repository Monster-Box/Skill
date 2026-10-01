---
name: telegram-bot-styling
description: 设计、编写或优化 Telegram Bot 的消息渲染与交互界面时使用——包括富文本消息（RichMessage / sendRichMessage）、传统 HTML/MarkdownV2 格式化、内联键盘按钮（InlineKeyboardButton 的 style 与 icon_custom_emoji_id）、以及通过 tg-emoji-hub MCP 查找并嵌入会员表情（custom emoji）。触发词：Telegram bot、tg bot、InlineKeyboardButton、reply_markup、parse_mode、custom_emoji、premium emoji、会员表情、按钮美化、sendRichMessage、RichText。
---

# Telegram Bot 界面美化

目标：让 Bot 的输出**有会员表情、按钮有图标和颜色、排版用富文本而不是一坨纯文本**。

## 铁律 0 —— 默认使用会员表情

面向用户的文本，能塞会员表情就塞：

- 每条消息的首行/标题 **必须** 至少 1 个 custom emoji
- 每个 InlineKeyboardButton **必须** 带 `icon_custom_emoji_id`
- 状态、字段名、单位后缀优先用 custom emoji，而不是裸文字或 Unicode emoji
- **禁止编造 emoji id**。所有 id 必须来自 `tg-emoji-hub` MCP 的真实查询结果

`custom_emoji_id` 是纯数字字符串（例：`5368324170671202286`）。编造或失效的 id 客户端不会渲染，只会显示乱码或降级为 alt 文本。

> 降级是安全的：custom emoji 自带 alt（`<tg-emoji emoji-id="X">🔥</tg-emoji>` 里的 `🔥`），非会员用户和系统通知里会显示 alt。所以放心用，不会崩。

## 铁律 1 —— 先用 MCP 查表情，再写代码

**不要**凭记忆写 id。每条要美化的消息，先按下面流程查：

1. 想好语义（"成功"、"警告"、"火焰"、"箭头"、"下载"…）
2. 调 `search_emoji`（**用英文或中文关键词，别传 emoji 字符**，见下）
3. 从返回的 `formats.html` 直接取整段标签，或从 `custom_emoji_id` 取 id
4. 塞进代码

> **实测坑（2026-10-01 验证）**：`search_emoji` 传 emoji 字符（`🔥` `✅` `🎁`）**一律返回 0 条**，尽管工具描述声称支持。必须传关键词：`fire` `check mark` `gift`，中文关键词（`火` `礼物`）也能命中。搜不到就换同义词、换语言、或放宽到 `category`。

MCP 未接入时，先看 `references/emoji-hub.md` 引导用户接入；急用可跑 `scripts/emoji.sh "<关键词>"` 直连查询。

查询工具速查（详见 `references/emoji-hub.md`）：

| 场景 | 工具 |
|---|---|
| 按关键词/emoji 字符找 | `search_emoji` |
| 按语义分类找 | `search_emoji` 带 `category` |
| 已知 id 查详情 | `get_emoji_by_id` |
| 某个包内搜 | `search_in_pack` |
| 浏览包内全部 | `list_pack_stickers` |
| 列出所有包 | `list_packs` |

## 铁律 2 —— 先选消息类型

| 需求 | 用什么 |
|---|---|
| 标题、列表、表格、折叠块、脚注、公式、内嵌媒体、多行按钮 | **Rich Message**（`sendRichMessage`） |
| 普通文本 + 内联键盘 | 传统 `sendMessage` + `parse_mode: "HTML"` |
| 流式输出（AI 逐字生成） | `sendRichMessageDraft` → 完成后 `sendRichMessage` |

**Rich Message 是首选**，它是 Bot API 10.1 引入的结构化消息，支持 `<h1>`~`<h6>`、`<table>`、`<details>`、`<blockquote expandable>`、`<tg-collage>`、`<tg-slideshow>`、脚注、LaTeX——传统模式全都做不到。

富文本两大限制（写之前先确认）：

- 正文 ≤ **32768** UTF-8 字符
- ≤ **500** 个块（含嵌套、列表项、表格行、引用块）
- 嵌套 ≤ **16** 层，媒体 ≤ **50** 个，表格 ≤ **20** 列

## 铁律 3 —— 按钮必须有 style + 图标

### 传统 InlineKeyboardButton

```python
{"text": "确认支付", "callback_data": "pay:ok",
 "icon_custom_emoji_id": "5814592786216787398", "style": "success"}
```

- `style`：只能是 `"danger"`(红) / `"success"`(绿) / `"primary"`(蓝)，省略则客户端自选
- `icon_custom_emoji_id`：按钮文字**前面**的会员表情
- `text`、`icon_custom_emoji_id`、`style` 不算按钮类型；其余字段**有且只能有一个**

### 富文本里的按钮（`<tg-button>`）

```html
<tg-button-row align="center">
  <tg-button type="callback_data" style="success" data="pay:ok">确认<tg-emoji emoji-id="5814592786216787398">✅</tg-emoji></tg-button>
  <tg-button type="callback_data" style="danger" data="pay:no">取消</tg-button>
</tg-button-row>
```

富文本按钮的 `style` **多一个 `"link"`**（无边框链接样式，**仅限 callback 按钮**），且富文本按钮的 `text` 支持内嵌 `tg-emoji` 和 `tg-time`。

### style 语义映射（照抄，别乱用）

| style | 用在哪 |
|---|---|
| `success` | 确认、提交、购买、启用、成功态 |
| `danger` | 删除、取消、解绑、危险操作、失败态 |
| `primary` | 主操作、下一步、查看详情 |
| `link`（仅富文本） | 次要的跳转式 callback，视觉弱化 |

一行里最多 1 个 `success`/`primary` 作主操，其余降级——满屏彩色按钮等于没有重点。

## 铁律 4 —— 排版不要退化成纯文本

- 分节用 heading，不要用「【】」凑
- 长引用用 `expandable` 引用块，不要堆成一大段
- 键值对用 `<table>` 或列表，不要用空格对齐
- 代码用 `<pre><code class="language-x">`，并指定语言
- 公式用 `<tg-math>` 或 `$...$`，不要贴图片

完整标签表和语法见 `references/rich-messages.md` 与 `references/classic-messages.md`。

## 铁律 5 —— Python 一律用 python-telegram-bot

**只要目标语言是 Python，就必须用 `python-telegram-bot`（PTB）库。** 不写裸 `requests` / `httpx` 调 API，不用其它第三方封装。

```bash
pip install "python-telegram-bot>=22.7"
```

**版本必须 ≥ 22.7**——`InlineKeyboardButton` 的 `style` 和 `icon_custom_emoji_id` 是 22.7 才加的。

**PTB 22.8 只支持到 Bot API 10.0，富文本（10.1）尚未支持。** `telegram.InputRichMessage` 不存在。Python 要用富文本，必须走官方逃生舱 `Bot.do_api_request("send_rich_message", {...})`：

```python
await context.bot.do_api_request(
    "send_rich_message",
    {"chat_id": chat_id, "rich_message": {"html": '<h2>标题</h2><p>正文</p>'}},
)
```

完整写法、版本边界表、`disabled` 按钮的 `api_kwargs` 绕法、MarkdownV2 转义，全在 `references/python-telegram-bot.md`——**写 Python 之前先读它**。

## 交付前自检

1. 每个按钮都有 `icon_custom_emoji_id` 吗？图标语义和按钮动作对得上吗？
2. 每个 id 都来自 MCP 真实查询，而不是抄的示例吗？
3. `icon_custom_emoji_id` 与 `style` 之外，按钮是不是**只有一个**类型字段？
4. 富文本是否超了 32768 字符 / 500 块？
5. 没用富文本时，`parse_mode` 里的 `<`、`>`、`&` 转义了吗？
6. `style` 是否只用了 `danger`/`success`/`primary`（富文本可加 `link`）？
7. Python 代码用的是 `python-telegram-bot` 且 ≥ 22.7 吗？要发富文本的话，走 `do_api_request` 了吗？

## 参考文件

- `references/emoji-hub.md` —— MCP 接入（Claude Code / Cursor / Codex）+ 工具详解 + 返回结构 + 实测坑
- `references/python-telegram-bot.md` —— **Python 必读**：PTB 版本要求、能力边界表、按钮写法、富文本 `do_api_request` 逃生舱
- `references/rich-messages.md` —— Rich Message 完整参考：`sendRichMessage` 参数、全部块类型、RichText 类型、按钮语法
- `references/classic-messages.md` —— 传统消息：HTML / MarkdownV2 标签表、MessageEntity、InlineKeyboardButton 全字段
- `scripts/emoji.sh` —— 不经 MCP 直连查询会员表情的兜底脚本
