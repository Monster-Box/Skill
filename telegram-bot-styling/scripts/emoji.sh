#!/usr/bin/env bash
# tg-emoji-hub 直连查询（MCP 未接入时的兜底方案）
#
#   ./emoji.sh "fire"              # 关键词搜索
#   ./emoji.sh "🔥" 5              # emoji 字符 + 限制条数
#   ./emoji.sh "cat" 10 LoveIcons  # 限定包
#   ./emoji.sh --id 5368324170671202286
#   ./emoji.sh --packs
#
# 依赖：curl；格式化输出需要 node（没有则打印原始 JSON）

set -euo pipefail

ENDPOINT="https://ehub.tg/mcp"
PROTO="2025-06-18"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }
command -v curl >/dev/null || die "需要 curl"

post() {
  local body="$1" sid="${2:-}"
  local args=(-sS -m 30 -X POST "$ENDPOINT"
    -H "Content-Type: application/json"
    -H "Accept: application/json, text/event-stream")
  [ -n "$sid" ] && args+=(-H "mcp-session-id: $sid")
  curl "${args[@]}" -d "$body"
}

SID=$(curl -sS -m 30 -D - -o /dev/null -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"$PROTO\",\"capabilities\":{},\"clientInfo\":{\"name\":\"emoji.sh\",\"version\":\"1.0\"}}}" \
  | grep -i '^mcp-session-id:' | tr -d '\r' | cut -d' ' -f2)

[ -n "$SID" ] || die "握手失败，端点是 $ENDPOINT"

post '{"jsonrpc":"2.0","method":"notifications/initialized"}' "$SID" >/dev/null

case "${1:-}" in
  ""|-h|--help)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 0 ;;
  --packs)
    TOOL="list_packs"; ARGS='{}' ;;
  --id)
    [ -n "${2:-}" ] || die "--id 需要 custom_emoji_id"
    TOOL="get_emoji_by_id"; ARGS="{\"custom_emoji_id\":\"$2\"}" ;;
  *)
    TOOL="search_emoji"
    Q="${1}"
    LIM="${2:-20}"
    if [ -n "${3:-}" ]; then
      ARGS=$(printf '{"query":"%s","limit":%s,"pack":"%s"}' "$Q" "$LIM" "$3")
    else
      ARGS=$(printf '{"query":"%s","limit":%s}' "$Q" "$LIM")
    fi ;;
esac

CALL=$(printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"%s","arguments":%s}}' "$TOOL" "$ARGS")
RAW=$(post "$CALL" "$SID")

if ! command -v node >/dev/null; then
  printf '%s\n' "$RAW"
  exit 0
fi

printf '%s' "$RAW" | node -e '
let s = "";
process.stdin.on("data", d => s += d);
process.stdin.on("end", () => {
  let r;
  try { r = JSON.parse(s); } catch { console.error("非 JSON 响应：\n" + s); process.exit(1); }
  if (r.error) { console.error("MCP error: " + JSON.stringify(r.error)); process.exit(1); }
  const text = r.result?.content?.[0]?.text ?? "";
  let data;
  try { data = JSON.parse(text); } catch { console.log(text); return; }

  const items = data.items ?? (Array.isArray(data) ? data : [data]);
  if (!items.length) { console.log("没有匹配的表情"); return; }

  // list_packs 返回的是包信息，字段与 emoji 项不同
  if (items[0].short_name !== undefined && items[0].custom_emoji_id === undefined) {
    for (const p of items) {
      const flag = p.is_featured ? "★" : " ";
      console.log(`${flag} ${String(p.sticker_count ?? "?").padStart(4)}  ${p.short_name}  ${p.title ?? ""}`);
    }
    console.log(`\ntotal: ${data.total ?? items.length}`);
    return;
  }

  for (const it of items) {
    const id = it.custom_emoji_id ?? it.formats?.id ?? "-";
    const alt = it.alt ?? "?";
    const pack = it.pack?.short_name ?? "-";
    const tags = [it.is_animated ? "animated" : "static", it.is_free ? "free" : "premium"]
      .filter(Boolean).join(",");
    console.log(`${alt}  ${id}  [${pack}] ${tags}`);
    console.log(`    ${it.formats?.html ?? `<tg-emoji emoji-id="${id}">${alt}</tg-emoji>`}`);
    if (it.keywords) console.log(`    keywords: ${String(it.keywords).slice(0, 120)}`);
  }
  if (data.total !== undefined) console.log(`\ntotal: ${data.total}`);
});
'
