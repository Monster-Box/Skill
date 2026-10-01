# Rich Message 参考（Bot API 10.1+，当前 10.3）

富文本消息：支持标题、列表、表格、媒体、折叠块、脚注、公式、内嵌按钮。指定内容三选一——`markdown` / `html` / `blocks`。

## sendRichMessage

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `chat_id` | Integer \| String | 是 | 目标会话 |
| `rich_message` | `InputRichMessage` | 是 | 要发的消息 |
| `business_connection_id` | String | 否 | 以商业账号身份发送 |
| `message_thread_id` | Integer | 否 | 论坛主题 |
| `direct_messages_topic_id` | Integer | 否 | 直聊话题 |
| `ephemeral_message_parameters` | `EphemeralMessageParameters` | 否 | 临时消息参数 |
| `disable_notification` | Boolean | 否 | 静默发送 |
| `protect_content` | Boolean | 否 | 禁止转发/保存 |
| `allow_paid_broadcast` | Boolean | 否 | 付费提速至 1000 条/秒（0.1 Stars/条） |
| `message_effect_id` | String | 否 | 消息特效（仅私聊） |
| `suggested_post_parameters` | `SuggestedPostParameters` | 否 | 建议帖（仅直聊） |
| `reply_parameters` | `ReplyParameters` | 否 | 回复目标 |
| `reply_markup` | `InlineKeyboardMarkup` 等 | 否 | 附加键盘 |

配套方法：

- `sendRichMessageDraft` —— 流式发送**部分**富文本，30 秒临时预览；定稿后**必须**再调 `sendRichMessage` 落盘
- `sendMessageDraft` —— 流式发送普通消息草稿

## InputRichMessage

`html` / `markdown` / `blocks` **三选一**。

| 字段 | 类型 | 说明 |
|---|---|---|
| `html` | String | HTML 风格内容 |
| `markdown` | String | Markdown 风格内容 |
| `blocks` | Array of `InputRichBlock` | 显式块结构 |
| `media` | Array of `InputRichMessageMedia` | 显式指定 markdown/html 里用到的媒体 |

## 限制

- 正文 ≤ **32768** UTF-8 字符（含 custom emoji 的 alt 和公式源码）
- ≤ **500** 块（含嵌套块、列表项、有序列表项、表格行、引用块、折叠块）
- 嵌套 ≤ **16** 层
- 媒体 ≤ **50** 个
- 表格 ≤ **20** 列

## Markdown 风格语法

```
**粗体**          __粗体__
*斜体*            _斜体_
~~删除线~~
`行内代码`
==标记文本==
||剧透||
[链接](https://t.me/)
[邮箱](mailto:user@example.com)
[电话](tel:+123456789)
[提到用户](tg://user?id=123456789)
![](tg://emoji?id=5368324170671202286)      ← 内嵌会员表情
![22:45 tomorrow](tg://time?unix=1647531900&format=wDT)   ← 时间
$x^2 + y^2$                                  ← 行内公式
$$E = mc^2$$                                 ← 块级公式
# 标题1  ~  ###### 标题6
---
- 无序列表    1. 有序列表
- [ ] 任务    - [x] 已完成
> 引用
| 表头1 | 表头2 |
|:------|------:|
[^id1] 脚注引用      [^id1]: 脚注定义
```

媒体块（**必须单独成块**，只支持 HTTP/HTTPS，类型按 MIME 和扩展名判定）：

```
![](https://example.com/photo.jpg "图注")
![](https://example.com/video.mp4 "视频注")
![](https://example.com/audio.ogg "语音注")
![](https://example.com/animation.gif "动图注")
![](https://example.com/document.zip "文件注")
```

复用已上传文件：`tg://photo?id=...`、`tg://video?id=...`、`tg://document?id=...`、`tg://audio?id=...`

## HTML 风格标签表

### 行内

```
<a name="chapter-0"></a>                      锚点
<b>/<strong>                                  粗体
<i>/<em>                                      斜体
<u>/<ins>                                     下划线
<s>/<strike>/<del>                            删除线
<code>                                        行内等宽
<mark>                                        标记
<sub>/<sup>                                   下标/上标
<tg-spoiler>                                  剧透
<tg-emoji emoji-id="5368324170671202286"></tg-emoji>   ★ 会员表情
<tg-time unix="1647531900" format="wDT">      时间
<tg-math>x^2 + y^2</tg-math>                  行内公式
<a href="...">                                链接
<tg-reference name="note-1">                  被引用文本
```

### 块级

```
<h1>…<h6>                                     标题
<p>                                           段落
<pre> / <pre><code class="language-python">    代码块
<footer>                                      页脚
<hr/>
<ul><li> / <ol><li>                           列表
<ol start="3" type="a" reversed>              有序列表属性
<li value="7" type="i">                       指定序号
<input type="checkbox" checked>               任务列表
<blockquote>…<cite>作者</cite></blockquote>   引用
<blockquote expandable>                       可折叠引用
<aside>拉引<cite>作者</cite></aside>           拉引
<table bordered striped compact><caption>…    表格
<details open><summary>标题</summary>内容      折叠块
<tg-math-block>E = mc^2</tg-math-block>       块级公式
<tg-map lat="41.9" long="12.5" zoom="14"/>    地图
<tg-document src="https://..."></tg-document> 文件
<figure><img src="..." tg-spoiler/><figcaption>图注<cite>来源</cite></figcaption></figure>
<tg-collage>…</tg-collage>                    拼图
<tg-slideshow>…</tg-slideshow>                幻灯片
```

表格属性：`bordered`、`striped`、`compact`；单元格支持 `colspan` `rowspan` `align` `valign`。**表格单元格只能放行内格式。**

`sendRichMessageDraft` 额外支持：

```
<tg-thinking>Thinking...</tg-thinking>        生成中的占位块
```

## 富文本内的按钮

```html
<p>Inline buttons:
  <tg-button type="url" style="success" url="https://t.me">url</tg-button>
  <tg-button type="url" url="tg://user?id=777000">user</tg-button>
  <tg-button type="callback_data" style="link" data="callback">
    callback 里可以放 <tg-time unix="1647531900" format="wDT">22:45 tomorrow</tg-time>
    和会员表情 <tg-emoji emoji-id="5368324170671202286"></tg-emoji>
  </tg-button>
  <tg-button type="web_app" style="danger" url="https://telegram.org">Mini App（仅私聊）</tg-button>
  <tg-button type="login_url" url="https://t.me" forward-text="forward text" request-write-access>登录</tg-button>
  <tg-button type="switch_inline_query" style="primary" query="inline">inline</tg-button>
  <tg-button type="switch_inline_query_current_chat" query="inline 2">inline 2</tg-button>
  <tg-button type="switch_inline_query_chosen_chat" query="inline 3"
             allow-user-chats allow-bot-chats allow-group-chats allow-channel-chats>inline 3</tg-button>
  <tg-button type="copy_text" text="...copy">复制</tg-button>
  <tg-button type="disabled">禁用</tg-button>
</p>

<tg-button-row align="left">   <!-- left / center / right -->
  <tg-button type="url" url="https://t.me">url</tg-button>
  <tg-button type="callback_data" style="link" data="callback">callback</tg-button>
</tg-button-row>
```

**按钮 `text` 只允许纯文本、`RichTextCustomEmoji` 和 `RichTextDateTime` 三种内容。**

## RichMessageButton 对象

与 InlineKeyboardButton 的关键差异：

- `text` 是 **RichText** 而非 String
- `style` 多一个 `"link"`（无边框链接外观，**仅允许 callback 按钮**）
- `text` 和 `style` 之外，**有且只有一个**类型字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `text` | RichText | 按钮文本，仅纯文本 / custom emoji / date-time |
| `style` | String | `danger` / `success` / `primary` / `link` |
| `url` | String | 打开的链接 |
| `callback_data` | String | 回调数据，1-64 字节 |
| `web_app` | WebAppInfo | Mini App，仅私聊 |
| `login_url` | LoginUrl | 免密登录，**不支持临时消息** |
| `switch_inline_query` | String | 选择会话后填入 inline query |
| `switch_inline_query_current_chat` | String | 当前会话填入 inline query |
| `switch_inline_query_chosen_chat` | SwitchInlineQueryChosenChat | 限定会话类型 |
| `copy_text` | CopyTextButton | 复制文本 |
| `callback_game` | CallbackGame | 游戏，**必须放第一行第一个** |
| `pay` | Boolean | 支付按钮，**必须放第一行第一个**，且仅用于账单消息 |
| `disabled` | DisabledButton | 禁用按钮 |

## RichText 类型（用 blocks 时）

行内：`RichTextBold` `RichTextItalic` `RichTextUnderline` `RichTextStrikethrough` `RichTextSpoiler` `RichTextDateTime` `RichTextTextMention` `RichTextSubscript` `RichTextSuperscript` `RichTextMarked` `RichTextCode` **`RichTextCustomEmoji`** `RichTextMathematicalExpression` `RichTextUrl` `RichTextEmailAddress` `RichTextPhoneNumber` `RichTextBankCardNumber` `RichTextMention` `RichTextHashtag` `RichTextCashtag` `RichTextBotCommand` `RichTextAnchor` `RichTextAnchorLink` `RichTextReference` `RichTextReferenceLink`

块：`RichBlockCaption` `RichBlockTableCell` `RichBlockListItem` `RichBlockParagraph` `RichBlockSectionHeading` `RichBlockPreformatted` `RichBlockFooter` `RichBlockDivider` `RichBlockMathematicalExpression` `RichBlockAnchor` `RichBlockList` `RichBlockBlockQuotation` `RichBlockExpandableBlockQuotation` `RichBlockPullQuotation` `RichBlockCollage` `RichBlockSlideshow` `RichBlockTable` `RichBlockDetails` `RichBlockMap` `RichBlockAnimation` `RichBlockAudio` `RichBlockPhoto` `RichBlockVideo` `RichBlockVoiceNote` `RichBlockDocument` `RichBlockThinking` `RichBlockButtons`

`RichTextCustomEmoji` 字段：`type`（恒为 `custom_emoji`）、`custom_emoji_id`、`alternative_text`（降级用的 Unicode emoji）。

`Message` 对象上的富文本内容在 `rich_message`（类型 `RichMessage`）。

## 注意事项

- 富文本 Markdown 尽量兼容 GitHub Flavored Markdown，且**可以混入任意 HTML**
- Plain URL、邮箱、@用户名、#标签、$货币、电话、银行卡号会**自动识别**成实体；用 `skip_entity_detection: true` 关掉
- 客户端会在打开内联链接前弹「Open this link?」确认框
- 媒体**只能作为独立块**出现
- 公式源码按**裸 LaTeX** 处理
- 除 `<details>`、`<tg-collage>`、`<tg-slideshow>` 外，**块级 HTML 标签内不解析 Markdown**，只能用 HTML 标签
- 引号内只保留 bold / italic / underline / strikethrough / spoiler / custom_emoji / date_time
- HTML 里只有这些命名实体可用：`&lt; &gt; &amp; &quot; &apos; &nbsp; &hellip; &mdash; &ndash; &lsquo; &rsquo; &ldquo; &rdquo;`；数字实体全部支持

## 日期时间格式串

正则：`r|w?[dD]?[tT]?`

| 字符 | 含义 |
|---|---|
| `r` | 相对时间（不能与其他字符组合） |
| `w` | 星期（用户本地语言） |
| `d` / `D` | 短日期 `17.03.22` / 长日期 `March 17, 2022` |
| `t` / `T` | 短时间 `22:45` / 长时间 `22:45:00` |

空格式串则原样显示文本，但客户端仍可按本地格式取到日期。
