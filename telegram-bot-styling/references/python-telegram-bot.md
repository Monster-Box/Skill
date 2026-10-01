# Python：python-telegram-bot

**Python 项目一律用 python-telegram-bot（PTB）**，不用裸 HTTP 请求、不用其它封装库。

```bash
pip install "python-telegram-bot>=22.7"
```

**必须 ≥ 22.7**——`style` 和 `icon_custom_emoji_id` 是 22.7 才加入的。当前最新 22.8（2026-06-12）。

## 能力边界（先看这张表，别写完才发现用不了）

| 特性 | Bot API 引入 | PTB 22.8 |
|---|---|---|
| `InlineKeyboardButton.style` | — | ✅ 22.7+ |
| `InlineKeyboardButton.icon_custom_emoji_id` | — | ✅ 22.7+ |
| `<tg-emoji>` 会员表情 | 9.x | ✅ |
| `copy_text` | — | ✅ 21.7+ |
| `disabled` 按钮 | 10.0 | ❌ 无原生参数 |
| **Rich Message**（`sendRichMessage` / `InputRichMessage`） | **10.1** | ❌ **未支持** |

PTB 22.8 对应 **Bot API 10.0**，而富文本要 10.1。截止 2026-10-01 官方仍未跟进，`telegram.InputRichMessage` 不存在（访问类文档 404）。

> `style` 是客户端渲染特性，**只在 2026-02-09 之后发布的 Telegram 版本上生效**，旧客户端只是忽略它——所以不会有兼容性报错。

**Python 要用富文本，必须走 `do_api_request` 逃生舱**（见下）。

## 按钮写法

```python
from telegram import InlineKeyboardButton, InlineKeyboardMarkup
from telegram.constants import ParseMode

keyboard = InlineKeyboardMarkup([
    [
        InlineKeyboardButton(
            text="立即购买",
            callback_data="buy:pro",
            icon_custom_emoji_id="5814592786216787398",   # ✅
            style="success",                               # 22.7+
        ),
        InlineKeyboardButton(
            text="查看详情",
            callback_data="detail",
            icon_custom_emoji_id="6247021793068981563",   # ➡️
            style="primary",
        ),
    ],
    [
        InlineKeyboardButton(
            text="取消",
            callback_data="cancel",
            icon_custom_emoji_id="5271934564699226262",   # ❌
            style="danger",
        ),
    ],
])

text = (
    '<tg-emoji emoji-id="5999246912174166759">🔥</tg-emoji> <b>Pro 会员</b>\n\n'
    "<blockquote>解锁全部高级功能</blockquote>\n"
    "价格：<b>$9.9</b> / 月"
)

await message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=keyboard)
```

参数名是 **`icon_custom_emoji_id`**，不是 `icon_emoji`。PTB 会在本地校验「除 `text` / `icon_custom_emoji_id` / `style` 外有且只有一个类型字段」，多个同时传会直接抛 `TypeError`。

## `disabled` 按钮的绕法

PTB 没有 `disabled` 参数，但 `InlineKeyboardButton` 接受 `api_kwargs` 透传：

```python
InlineKeyboardButton(text="已售罄", callback_data="noop", api_kwargs={"disabled": {}})
```

> 这条**未经实测验证**（依赖 PTB 的 api_kwargs 透传行为）。上线前先发一条真消息确认。

## 富文本：`do_api_request`

PTB 官方为「尚未支持的 API 方法」提供了公开通道：

```python
async def send_rich(update, context):
    await context.bot.do_api_request(
        "send_rich_message",              # 下划线或驼峰都行，内部会转成 sendRichMessage
        {
            "chat_id": update.effective_chat.id,
            "rich_message": {
                "html": (
                    "<h2>订单确认</h2>"
                    "<p>感谢购买 <tg-emoji emoji-id=\"5814592786216787398\">✅</tg-emoji></p>"
                    "<table bordered><tr><th>项目</th><th>金额</th></tr>"
                    "<tr><td>Pro 年费</td><td align=\"right\">$99</td></tr></table>"
                    "<blockquote expandable>点开查看完整条款…</blockquote>"
                    "<p><tg-button type=\"callback_data\" style=\"success\" data=\"pay:ok\">"
                    "确认<tg-emoji emoji-id=\"5814592786216787398\">✅</tg-emoji></tg-button></p>"
                )
            },
        },
    )
```

签名：

```python
Bot.do_api_request(
    endpoint: str,
    api_kwargs: dict | None = None,
    return_type: type[TelegramObject] | None = None,
    *,
    read_timeout=..., write_timeout=..., connect_timeout=..., pool_timeout=...,
) -> Any
```

要点：

- 返回**原始 dict**（不传 `return_type` 时）
- 嵌套 dict 直接传，PTB 会原样序列化
- 方法不存在时抛 `EndPointNotFound`，别当成网络错误
- 传 `telegram` 模块里的对象也可以；但**上传文件必须传 `InputFile` 实例**，路径会失败
- `Defaults` 的默认值填充**不生效**（`tzinfo` 除外）
- 端点名若与已实现的方法重名，会发警告——用 `send_rich_message` 不会有这个问题

流式场景用 `send_rich_message_draft`（同样走 `do_api_request`），定稿后仍要再调 `send_rich_message` 落盘。

## MarkdownV2 转义

PTB 不会替你转义。用 `ParseMode.HTML` 能省掉大半麻烦；非要用 MarkdownV2 就自己转：

```python
import re

def escape_md2(s: str) -> str:
    return re.sub(r"([_*\[\]()~`>#+\-=|{}.!])", r"\\\1", s)
```

## 完整骨架

```python
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.constants import ParseMode
from telegram.ext import Application, CommandHandler, ContextTypes

TOKEN = "..."

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    kb = InlineKeyboardMarkup([[
        InlineKeyboardButton(text="开始", callback_data="go",
                             icon_custom_emoji_id="5814592786216787398",
                             style="success"),
    ]])
    await update.message.reply_text(
        '<tg-emoji emoji-id="5816920748685533396">🚀</tg-emoji> <b>欢迎</b>',
        parse_mode=ParseMode.HTML,
        reply_markup=kb,
    )

def main() -> None:
    Application.builder().token(TOKEN).build() \
        .add_handler(CommandHandler("start", start)) \
        .run_polling()

if __name__ == "__main__":
    main()
```

## 与技能其它部分的衔接

- 所有 `custom_emoji_id` 都要经 `tg-emoji-hub` 查真实值，见 `emoji-hub.md`
- 富文本能表达的排版一律用富文本（`do_api_request`），别退化成纯文本
- 需要 Rich Message 的完整标签表时看 `rich-messages.md`
