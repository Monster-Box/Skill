#!/usr/bin/env python3
"""Telegram 会话设备身份：生成一次，落盘复用。

    python device_identity.py my.session

记录文件：<session 同目录>/<session 名>.identity.json

规则：
    记录存在 -> 直接使用记录
    记录不存在 -> 随机生成一次并落盘

一旦账号上线过，记录文件就不能再改（改了等于换设备）。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

RECORD_FIELDS = (
    "template",
    "api_id",
    "api_hash",
    "device_model",
    "system_version",
    "app_version",
    "lang_code",
    "system_lang_code",
    "lang_pack",
)


def identity_path(session_path: str | os.PathLike) -> Path:
    """<my.session> -> <my.identity.json>"""
    p = Path(session_path)
    if p.suffix == ".session":
        return p.with_name(p.stem + ".identity.json")
    return p.with_suffix(".identity.json")


def load_record(session_path: str | os.PathLike) -> dict | None:
    path = identity_path(session_path)
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if any(not data.get(f) for f in RECORD_FIELDS):
        return None
    return data


def save_record(session_path: str | os.PathLike, record: dict) -> Path:
    path = identity_path(session_path)
    path.write_text(json.dumps(record, indent=2, ensure_ascii=False), encoding="utf-8")
    return path


def generate_record(session_path: str | os.PathLike, template: str = "TelegramDesktop") -> dict:
    """随机生成一份设备身份。"""
    from opentele.api import API

    tmpl = getattr(API, template, None)
    if tmpl is None:
        raise ValueError(f"未知模板: {template}")

    api = tmpl.Generate()

    return {
        "template": template,
        "api_id": api.api_id,
        "api_hash": api.api_hash,
        "device_model": api.device_model,
        "system_version": api.system_version,
        "app_version": api.app_version,
        "lang_code": api.lang_code,
        "system_lang_code": api.system_lang_code,
        "lang_pack": api.lang_pack,
    }


def resolve(session_path: str | os.PathLike, template: str = "TelegramDesktop") -> tuple[dict, bool]:
    """返回 (记录, 是否新建)。记录优先。"""
    existing = load_record(session_path)
    if existing is not None:
        return existing, False
    record = generate_record(session_path, template=template)
    save_record(session_path, record)
    return record, True


def build_api(record: dict):
    """用记录里的值构造 OpenTele 的 APIData。"""
    from opentele.api import API

    api = getattr(API, record["template"])(record["api_id"], record["api_hash"])
    for field in RECORD_FIELDS:
        if field in ("template", "api_id", "api_hash"):
            continue
        value = record.get(field)
        if value:
            setattr(api, field, value)
    return api


def make_client(session_path: str | os.PathLike, record: dict, **kwargs):
    """构造 Telethon 客户端。api 已含全部设备与凭据，不要再传 api_id/api_hash。"""
    from opentele.tl import TelegramClient

    return TelegramClient(str(session_path), api=build_api(record), **kwargs)


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
        except (AttributeError, OSError):
            pass

    parser = argparse.ArgumentParser(description="生成/读取 Telegram 会话的设备身份记录")
    parser.add_argument("session", help="session 文件路径，例如 my.session")
    parser.add_argument("--template", default="TelegramDesktop", help="API 模板（默认 TelegramDesktop）")
    args = parser.parse_args()

    record, created = resolve(args.session, template=args.template)

    action = "已生成并写入" if created else "已从记录读取"
    print(f"{action}: {identity_path(args.session)}")
    print()
    print(json.dumps(record, indent=2, ensure_ascii=False))
    print(
        "\n使用：\n"
        "    from device_identity import resolve, make_client\n"
        f"    record, _ = resolve({args.session!r})\n"
        f"    client = make_client({args.session!r}, record)\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
