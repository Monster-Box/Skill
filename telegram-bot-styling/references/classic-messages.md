# 传统消息格式化参考

用于普通 `sendMessage` / `editMessageText` 等方法的 `parse_mode`（`HTML` / `MarkdownV2`）。

## HTML 模式标签表

```
<b>粗体</b>          <strong>粗体</strong>
<i>斜体</i>          <em>斜体</em>
<u>下划线</u>        <ins>下划线</ins>
<s>删除线</s>        <strike>删除线</strike>   <del>删除线</del>
<span class="tg-spoiler">剧透</span>   <tg-spoiler>剧透</tg-spoiler>
<a href="http://www.example.com/">内联链接</a>
<a href="tg://user?id=123456789">提到用户</a>
<tg-emoji emoji-id="5368324170671202286">🔥</tg-emoji>          ★ 会员表情
<tg-time unix="1647531900" format="wDT">22:45 tomorrow</tg-time> ★ 时间
<code>行内等宽</code>
<pre>代码块</pre>
<pre><code class="language-python">带语言高亮的代码块</code></pre>
<blockquote>引用</blockquote>
<blockquote expandable>默认折叠的引用</blockquote>
```

嵌套示例（实体可嵌套，但 pre/code 与其他实体互斥）：

```html
<b>粗体 <i>粗斜体 <s>加删除线 <span class="tg-spoiler">再加剧透</span></s> <u>下划线粗斜体</u></i> 粗体</b>
```

注意事项：

- 只支持上表列出的标签
- 非标签、非实体的 `<` `>` `&` 必须转义为 `&lt;` `&gt;` `&amp;`
- 命名实体只支持 `&lt; &gt; &amp; &quot;`，数字实体全部支持
- 代码语言用嵌套 `<pre><code>` 指定，单独的 `<code>` 无法指定语言
- `<tg-emoji>` 标签体内**必须是合法 emoji**，它会在无法显示自定义表情的场合（系统通知、非会员转发）替代显示

## MarkdownV2 模式

```
*bold \*text*
_italic \*text_
__underline__
~strikethrough~
||spoiler||
[inline URL](http://www.example.com/)
[inline mention of a user](tg://user?id=123456789)
![👍](tg://emoji?id=5368324170671202286)      ★ 会员表情
`inline fixed-width code`
```pre-formatted fixed-width code block```
```python
pre-formatted fixed-width code block
```
>blockquote
>expandable blockquote||
```

**MarkdownV2 必须转义**：`_ * [ ] ( ) ~ ` > # + - = | { } . !`

```python
import re
def escape_md2(s: str) -> str:
    return re.sub(r'([_*\[\]()~`>#+\-=|{}.!])', r'\\\1', s)
```

## Markdown（legacy）

仅为向后兼容保留。**不支持** underline、strikethrough、spoiler、blockquote、expandable_blockquote、custom_emoji、date_time——这些一律用 MarkdownV2 或 HTML。实体不可嵌套。

转义：在实体外，`_ * ` [` 前加 `\`。实体内部不能转义，需闭合后重开，例如 `_snake_\__case_`、`*2*\**2=4*`。

## 实体嵌套规则

- 两个实体若有公共字符，其中一个必须**完整包含**在另一个之内
- bold / italic / underline / strikethrough / spoiler 可包含、也可被任何其他实体包含——但**不含 pre 和 code**
- blockquote 与 expandable_blockquote **不能互相嵌套**
- 其余实体之间**不能互相包含**

## MessageEntity

| 字段 | 说明 |
|---|---|
| `type` | `mention` `hashtag` `cashtag` `bot_command` `url` `email` `phone_number` `bold` `italic` `underline` `strikethrough` `spoiler` `blockquote` `expandable_blockquote` `code` `pre` `text_link` `text_mention` `custom_emoji` `date_time` |
| `offset` | 偏移，单位 **UTF-16 code unit** |
| `length` | 长度，UTF-16 code unit |
| `url` | 仅 `text_link` |
| `user` | 仅 `text_mention` |
| `language` | 仅 `pre` |
| `custom_emoji_id` | 仅 `custom_emoji` |
| `unix_time` / `date_time_format` | 仅 `date_time` |

**投票（poll）的题目和选项只允许 custom emoji 实体。** 清单任务（`InputChecklistTask`）只允许 bold / italic / underline / strikethrough / spoiler / custom_emoji / date_time。

成员提到（`tg://user?id=`）**只在**内联链接或内联键盘按钮里生效，直接写在正文中无效。

## InlineKeyboardButton 全字段

`text`、`icon_custom_emoji_id`、`style` 之外的字段**有且只有一个**。

| 字段 | 类型 | 说明 |
|---|---|---|
| `text` | String | 按钮文字 |
| `icon_custom_emoji_id` | String | 文字前的会员表情 id。仅限 Fragment 买过额外用户名的 Bot，或 Bot 所有者有 Premium 时 Bot 直接发往私聊/群/超级群 |
| `style` | String | `danger`(红) / `success`(绿) / `primary`(蓝)，省略则客户端自选 |
| `url` | String | HTTP 或 `tg://` 链接；`tg://user?id=<user_id>` 可在隐私允许时提到用户 |
| `callback_data` | String | 回调数据，**1-64 字节** |
| `web_app` | WebAppInfo | Mini App，仅私聊；不支持商业账号消息 |
| `login_url` | LoginUrl | 免密登录，可替代 Login Widget；**不支持临时消息** |
| `switch_inline_query` | String | 选会话后填入 inline query；不支持频道直聊和商业账号 |
| `switch_inline_query_current_chat` | String | 当前会话填入 inline query；不支持频道、频道直聊、商业账号 |
| `switch_inline_query_chosen_chat` | SwitchInlineQueryChosenChat | 限定会话类型 |
| `copy_text` | CopyTextButton | 复制文本到剪贴板 |
| `callback_game` | CallbackGame | 游戏，**必须放第一行第一个** |
| `pay` | Boolean | 支付按钮，**必须放第一行第一个**，仅账单消息；`text` 里的 `⭐` 和 `XTR` 会被替换成 Stars 图标 |
| `disabled` | DisabledButton | 禁用，点了没反应 |

## 组合示例

```python
keyboard = {
    "inline_keyboard": [
        [
            {"text": "立即购买", "callback_data": "buy:pro",
             "icon_custom_emoji_id": "5814592786216787398", "style": "success"},
            {"text": "查看详情", "callback_data": "detail",
             "icon_custom_emoji_id": "6247021793068981563", "style": "primary"},
        ],
        [
            {"text": "取消", "callback_data": "cancel",
             "icon_custom_emoji_id": "5271934564699226262", "style": "danger"},
        ],
    ]
}

text = (
    '<tg-emoji emoji-id="5999246912174166759">🔥</tg-emoji> <b>Pro 会员</b>\n\n'
    "<blockquote>解锁全部高级功能</blockquote>\n"
    "价格：<b>$9.9</b> / 月"
)
```

## 自动识别

Plain URL、邮箱、`@username`、`#hashtag`、`$CASH`、`/botcommand`、电话号码会自动转成实体。

`tg://user?id=` 提到用户的前置条件：用户在该会话内、或曾私聊过 Bot、或点过 Bot 的内联按钮，且未对该 Bot 开启「转发消息」隐私限制。
