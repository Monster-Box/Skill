---
name: telegram-session-identity
description: 用 Python（Telethon / OpenTele）操作 Telegram 用户账号（userbot、session 文件、账号巡检）时使用——随机生成一次客户端设备指纹并落盘，之后每次登录都复用同一份，避免同一账号在不同设备信息之间来回跳而触发平台风控。触发词：Telethon、OpenTele、session 文件、userbot、tg 账号、设备指纹、device_model、tdata、账号登录。
---

# Telegram 会话设备指纹

用 Telethon 操作 **用户账号**（而非 Bot）时，`initConnection` 里那组设备参数（`device_model` / `system_version` / `app_version` / `lang_pack`…）就是账号的"设备身份"。**同一账号每次连接必须给出完全相同的这组值**，否则在服务端看来是"同一个账号在设备之间反复横跳"。

本技能只做一件事：**随机生成一次，落盘，之后永远复用。**

## 铁律 1 —— 生成一次就落盘，之后只读记录

```
my.session          ← Telethon 会话
my.identity.json    ← 设备身份记录（首次运行时生成，之后只读）
```

- **记录不存在** → `Generate()` 随机生成一次，立即写盘
- **记录存在** → 无条件使用记录，**不再生成**

稳定性来自**记录文件**，不是来自生成算法。只要记录在，设备就永远是同一套；记录丢了才会换设备。

用 `scripts/device_identity.py`：

```
python device_identity.py my.session
```

```python
from device_identity import resolve, make_client

record, _ = resolve("my.session")        # 有记录读记录，没记录生成并落盘
client = make_client("my.session", record)
```

> **不要记录 `pid`。** OpenTele 的 `pid` 是进程内部的查找句柄，被临时塞进 `device_model` 参数传递，在 `CustomInitConnectionRequest` 里会被换回真实设备名——**它不会发到 Telegram**，记它没有意义。

## 铁律 2 —— 一个会话永远绑定同一套 api_id / api_hash

OpenTele 文档里的警告是硬性的：

> If the session was created using an official API, you must continue using official APIs for that session. Otherwise that account is at risk of getting banned.

**会话是用哪套 `api_id`/`api_hash` 授权出来的，就必须一直用那一套。** 混用（比如会话原本是 Android 客户端登录的，你却用 `TelegramDesktop` 模板去连）等于自曝。

所以设备记录里同时存 `template` / `api_id` / `api_hash`，下次原样读回来。

可选模板（`API.<模板>`）：

| 模板 | api_id | lang_pack |
|---|---|---|
| `TelegramDesktop` | 2040 | `tdesktop` |
| `TelegramAndroid` | 6 | `android` |
| `TelegramAndroidX` | 21724 | `android` |
| `TelegramIOS` | 10840 | `ios` |
| `TelegramMacOS` | 2834 | `macos` |
| `TelegramWeb_K` / `TelegramWeb_Z` / `Webogram` | 2496 | — |

> 浏览器系（`TelegramWeb_*`、`Webogram`）无法 `Generate()`，会直接抛 `NotImplementedError`。

## 铁律 3 —— OpenTele 已停更，先把版本锁死

- 最后一次提交：**2024-07-15**
- PyPI 最新：**1.15.1**
- `requirements.txt` 里 `telethon` **未锁版本**，还带 `pyqt5` 依赖
- Telethon 当前已到 **1.45.0**（2026-09）

不锁版本就可能拉到不兼容的组合。`opentele==1.15.1` 配 `telethon==1.45.0` 已实测可用，直接作为起点：

```
opentele==1.15.1
telethon==1.45.0
```

## 与 Telethon 的衔接

OpenTele 的客户端是 Telethon `TelegramClient` 的子类，**创建后可直接调用全部 Telethon 方法**（`get_me`、`is_user_authorized`、`get_entity`、`iter_dialogs`、自定义 `functions.*` 请求等）：

```python
from opentele.tl import TelegramClient

client = TelegramClient(session, api=build_api(record))
await client.connect()
me = await client.get_me()          # Telethon 原生方法
await client.disconnect()
```

`api=` 传 OpenTele 的 `APIData` 即可，**不要再传 `api_id`/`api_hash`**——`api` 里已经带了，重复传会被覆盖。

不传 `api` 时 OpenTele 会悄悄回落到 `TelegramDesktop` 模板，这正是铁律 2 的踩雷点：**永远显式传 `api`**。

详见 `references/opentele.md`。

## 交付前自检

1. 记录文件是否落盘？读取逻辑是否为「有则用、无则生成」？
2. 记录里的 `api_id` / `api_hash` / `template` 是否与该会话最初授权时一致？
3. 有没有把没用的 `pid` 也塞进记录？
4. 依赖是否锁了版本？

## 参考文件

- `references/opentele.md` —— OpenTele 内部机制：`Generate` 语义、`pid` 传递链路、模板全表、依赖风险
- `scripts/device_identity.py` —— 设备身份的生成与持久化（核心脚本）
