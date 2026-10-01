# tg-emoji-hub MCP 接入与使用

Telegram 会员表情（Premium custom emoji）搜索服务。让 AI 直接查到真实的 `custom_emoji_id`，而不是猜。

- 服务名：`tg-emoji-hub` v0.1.0
- 端点：`https://ehub.tg/mcp`
- 传输：**Streamable HTTP**（Anthropic 官方推荐；SSE 已弃用）
- MCP 协议版本：`2025-06-18`

## 一、接入

### Claude Code（命令行，最快）

```bash
claude mcp add --transport http tg-emoji-hub https://ehub.tg/mcp
```

验证：

```bash
claude mcp list
```

### Claude Code（配置文件）

写入 `~/.claude.json`（全局）或项目根目录 `.mcp.json`（可纳入版本管理）：

```json
{
  "mcpServers": {
    "tg-emoji-hub": {
      "type": "http",
      "url": "https://ehub.tg/mcp"
    }
  }
}
```

项目级 `.mcp.json` 首次使用会提示确认，属于正常行为。

### Cursor

在 `~/.cursor/mcp.json`（全局）或项目 `.cursor/mcp.json` 中加入：

```json
{
  "mcpServers": {
    "tg-emoji-hub": {
      "url": "https://ehub.tg/mcp"
    }
  }
}
```

### Codex

在 `~/.codex/config.toml` 中加入：

```toml
[mcp_servers.tg-emoji-hub]
url = "https://ehub.tg/mcp"
```

> Cursor / Codex 的字段名随版本变化，若客户端报「未知字段」，以该客户端当前文档为准。Claude Code 的两种方式已核实可用。

### 没有 MCP 时的兜底

`scripts/emoji.sh "<关键词>"` 直连 HTTP 端点查询，输出与 MCP 相同的 JSON。

## 二、工具清单

### search_emoji

按关键词或 emoji 字符搜索。

| 参数 | 必填 | 说明 |
|---|---|---|
| `query` | 否* | 关键词（`fire`）或 emoji 字符（`🔥`） |
| `category` | 否* | 按分类筛选 |
| `pack` | 否 | 限定包 short_name |
| `limit` | 否 | 默认 20 |

\* `query` / `pack` / `category` **至少给一个**。

返回每项包含 `custom_emoji_id` 及 4 种格式（`id` / `html` / `go_map` / `json`）。

### get_emoji_by_id

| 参数 | 必填 | 说明 |
|---|---|---|
| `custom_emoji_id` | 是 | 表情 id |

### list_packs

列出所有已收录的包。

| 参数 | 必填 | 说明 |
|---|---|---|
| `source` | 否 | `featured` / `manual` |

### list_pack_stickers

浏览某个包内的全部表情（animated 优先，其次 newest）。

| 参数 | 必填 | 说明 |
|---|---|---|
| `pack_short_name` | 是 | 包的 short_name |
| `limit` | 否 | 默认 100，上限 100 |

### search_in_pack

在指定包内搜索。

| 参数 | 必填 | 说明 |
|---|---|---|
| `pack_short_name` | 是 | 包的 short_name |
| `query` | 是 | 关键词 |
| `limit` | 否 | 默认 20，上限 100 |

## 三、返回结构

所有工具返回 `content[0].text`，里面是 **JSON 字符串**（需要再 parse 一次）。`search_emoji` 的结构：

```json
{
  "items": [
    {
      "alt": "🔥",
      "category": "",
      "custom_emoji_id": "5999246912174166759",
      "formats": {
        "id": "5999246912174166759",
        "html": "<tg-emoji emoji-id=\"5999246912174166759\">🔥</tg-emoji>",
        "go_map": "\"burning\": \"5999246912174166759\",",
        "json": {"alt": "🔥", "id": "5999246912174166759", "pack": "APKFMBOT"}
      },
      "is_animated": true,
      "is_free": false,
      "keywords": "burning,cartoon,emoji,fire,flame,卡通,火,火焰,燃烧,表情包,🔥",
      "media_url": "/emoji/5999246912174166759.tgs",
      "mime_type": "application/x-tgsticker",
      "pack": {"short_name": "APKFMBOT", "title": "@APKFM"},
      "thumbnail_url": "/thumbs/5999246912174166759.webp"
    }
  ],
  "total": 1
}
```

字段说明：

- `alt` —— 降级显示用的 Unicode emoji，**必须**填进 `<tg-emoji>` 标签体内
- `custom_emoji_id` —— 拿去填 `icon_custom_emoji_id` 或 `emoji-id`
- `formats.html` —— 传统 HTML 模式可直接粘贴的完整标签
- `is_free` —— `true` 表示免费表情（所有人可用），`false` 是会员表情
- `is_animated` —— 是否动图
- `media_url` / `thumbnail_url` —— 相对路径，预览时前面拼 `https://ehub.tg`

## 四、权限前提（重要）

会员表情有使用门槛，写代码前先确认，否则电报端不渲染：

> Custom emoji entities can only be used by bots that purchased additional usernames on Fragment **or** in the messages directly sent by the bot to private, group and supergroup chats **if the owner of the bot has a Telegram Premium subscription.**

也就是说，满足任一条即可：

1. Bot 在 Fragment 上买过额外用户名；或
2. **Bot 的所有者有 Telegram Premium**，且消息是 Bot 直接发往私聊/群/超级群

不满足时：`icon_custom_emoji_id` 与 `<tg-emoji>` 都不会显示成动图，只会显示 alt 文本——**不会报错**，所以线上问题通常是「看着没效果」而非「报错」。

## 五、实测踩坑（2026-10-01 验证）

**1. emoji 字符查询不可用。** 工具描述声称支持传 emoji 字符，但实测 `🔥` `😀` `✅` `🎁` `🚀` **全部返回 `total: 0`**。原样 UTF-8 和 `\u` 转义都试过，是服务端行为。→ **一律传关键词**，中英文均可（`fire` / `火` 都能命中）。

**2. 搜索是模糊相关度排序，不是精确匹配。** 搜 `cross` 会返回 💎，搜 `star` 会返回 😄。想拿准的：
- 用更具体的关键词（`red cross` 才能命中 ❌）
- 或先用 `list_packs` 找到合适的包，再用 `search_in_pack` 限定范围

**3. 结果要二次 parse。** `content[0].text` 本身是 **JSON 字符串**，不是对象。

**4. 表单里的 👍 就是个占位。** 网上教程常见的 `5368324170671202286` 实际是「点赞」表情，别拿它当通用图标。

### 常用语义种子 id（仅作示例与兜底，**优先实时查询**）

| 语义 | alt | custom_emoji_id | 包 |
|---|---|---|---|
| 确认 / 成功 | ✅ | `5814592786216787398` | BiaoQing77_103 |
| 取消 / 失败 | ❌ | `5271934564699226262` | IconsEmoji_JABA |
| 警告 | ❗️ | `6249123672754234724` | pack_41a15b83_by_stickerporter_bot |
| 下一步 / 箭头 | ➡️ | `6247021793068981563` | pack_41a15b83_by_stickerporter_bot |
| 礼物 / 奖励 | 🎁 | `6174734048913531742` | csok1 |
| 发布 / 提速 | 🚀 | `5816920748685533396` | BiaoQing77_101 |
| 热门 / 火焰 | 🔥 | `5999246912174166759` | APKFMBOT |
| 点赞 | 👍 | `5368324170671202286` | HandEmoji |
| 上升 | ⏫ | `5938437708635443119` | tgiosicons |
| 分类 | 🗂️ | `6190579742341600890` | hhbp21 |

这些 id 实测可用（`is_free: false`，即会员表情）。但表情包会被下架、id 会失效——**能查就查**。

## 六、诊断

```bash
# 握手，确认服务活着
curl -s -X POST https://ehub.tg/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"c","version":"1"}}}'
```

返回 `serverInfo.name == "tg-emoji-hub"` 即正常。响应头里的 `mcp-session-id` 是后续 `tools/list`、`tools/call` 必带的会话标识。
