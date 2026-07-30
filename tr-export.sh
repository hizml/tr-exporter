#!/bin/sh
# tr-export.sh — Transmission 按 Tracker 批量导出种子
# 交互式：引导输入 RPC 地址、账号密码、选择 Tracker 或全部导出，导出后自动打包 zip。
# 适用：Docker / QNAP Container Station 终端等无 SSH 场景，或任意能访问 Transmission RPC 的环境。

echo "===== Transmission 种子导出 ====="
echo

# ---------- 1. RPC 地址 ----------
echo "【RPC 地址】"
echo "  常见预设："
echo "   1) http://127.0.0.1:9091/transmission/rpc   (容器内本机，最常用)"
echo "   2) http://localhost:9091/transmission/rpc"
echo "   3) http://NAS_IP:9091/transmission/rpc       (从容器外访问 NAS)"
echo "   4) 自定义输入"
printf "选择序号或直接输入地址 (留空=默认 1): "
read RPC_INPUT
case "$RPC_INPUT" in
  ""|1) RPC="http://127.0.0.1:9091/transmission/rpc" ;;
  2)    RPC="http://localhost:9091/transmission/rpc" ;;
  3)    printf "    请输入 NAS 的 IP: "; read NAS_IP
        RPC="http://${NAS_IP}:9091/transmission/rpc" ;;
  *)    RPC="$RPC_INPUT" ;;
esac
echo "  → 使用: $RPC"
echo

# ---------- 2. 账号密码 ----------
printf "【认证】用户名 (无认证可留空): "
read USER
if [ -n "$USER" ]; then
  printf "密码: "
  stty -echo 2>/dev/null
  read PASS
  stty echo 2>/dev/null
  echo
  AUTH="-u ${USER}:${PASS}"
else
  AUTH=""
  echo "  → 跳过认证"
fi

# ---------- 3. 依赖 jq ----------
command -v jq >/dev/null || {
  echo "正在安装 jq..."
  apk add --no-cache jq 2>/dev/null || { apt-get update >/dev/null 2>&1 && apt-get install -y jq >/dev/null 2>&1; }
}
command -v jq >/dev/null || { echo "❌ 无法安装 jq，请手动安装后重试"; exit 1; }

# ---------- 4. 连接 + 拿 session-id ----------
echo "正在连接 Transmission..."
SID=$(curl -s $AUTH -D - -o /dev/null "$RPC" | grep -i 'X-Transmission-Session-Id' | awk '{print $2}' | tr -d '\r')
COUNT=$(curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
  -d '{"method":"torrent-get","arguments":{"fields":["id"]}}' | jq '.arguments.torrents|length' 2>/dev/null)
if ! echo "$COUNT" | grep -qE '^[0-9]+$'; then
  echo "❌ 连接失败，请检查 RPC 地址 / 账号 / 密码"; exit 1
fi
echo "✅ 连接成功，共 $COUNT 个种子"
echo

# ---------- 5. 定位真正的 torrents 目录 ----------
# 排除 /kettu/templates/torrents 等「假目录」：只认含 40 位 hex .torrent 文件的目录
echo "正在定位种子目录..."
TORRENTS_DIR=""
for d in $(find / -type d -name torrents 2>/dev/null); do
  if ls "$d"/*.torrent >/dev/null 2>&1 && ls "$d" | grep -qE '^[0-9a-fA-F]{40}\.torrent$'; then
    TORRENTS_DIR="$d"; break
  fi
done
if [ -z "$TORRENTS_DIR" ]; then
  printf "❌ 自动定位失败，请手动输入 torrents 目录路径: "
  read TORRENTS_DIR
  [ -z "$TORRENTS_DIR" ] && { echo "已取消"; exit 1; }
fi
echo "种子目录: $TORRENTS_DIR"
echo

# ---------- 6. 列出 Tracker ----------
echo "===== Tracker 列表 ====="
curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
  -d '{"method":"torrent-get","arguments":{"fields":["trackers"]}}' \
  | jq -r '.arguments.torrents[].trackers[].announce' \
  | sed -E 's#https?://([^/]+).*#\1#' | sort -u > /tmp/tr_list.txt
i=1
while read -r line; do
  printf "  %s) %s\n" "$i" "$line"
  i=$((i+1))
done < /tmp/tr_list.txt
ALL_N=$i
printf "  %s) 全部导出\n" "$ALL_N"
echo

# ---------- 7. 选择 ----------
printf "选择序号，或直接输入关键字(留空=全部): "
read SEL
KEY=""
if echo "$SEL" | grep -qE '^[0-9]+$'; then
  if [ "$SEL" -eq "$ALL_N" ]; then KEY=""; echo "→ 全部导出"
  else KEY=$(sed -n "${SEL}p" /tmp/tr_list.txt); echo "→ 选择: $KEY"; fi
elif [ -z "$SEL" ]; then
  echo "→ 全部导出"
else
  KEY="$SEL"; echo "→ 关键字: $KEY"
fi
echo

# ---------- 8. 导出 ----------
OUT="/config/export_$(date +%Y%m%d_%H%M%S)"
# 如果 /config 不存在(非容器环境)，退回到当前目录
mkdir -p "$OUT" 2>/dev/null || OUT="./export_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"
OK=0; MISS=0
curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
  -d '{"method":"torrent-get","arguments":{"fields":["name","hashString","trackers"]}}' \
| jq -c '.arguments.torrents[]' | while read -r t; do
    MATCH=0
    if [ -z "$KEY" ]; then MATCH=1
    elif echo "$t" | jq -r '.trackers[].announce' | grep -qi "$KEY"; then MATCH=1; fi
    if [ "$MATCH" = "1" ]; then
      name=$(echo "$t" | jq -r '.name')
      hash=$(echo "$t" | jq -r '.hashString')
      src="$TORRENTS_DIR/$hash.torrent"
      if [ -f "$src" ]; then
        cp "$src" "$OUT/${hash}.torrent"
        printf "[OK]   %s\n" "$name"
      else
        printf "[MISS] %s\n" "$name"
      fi
    fi
done

echo
echo "===== 完成 ====="
echo "导出目录: $OUT"
TOTAL=$(ls -1 "$OUT" 2>/dev/null | grep -c '\.torrent$')
echo "导出数量: $TOTAL 个"

# ---------- 9. 打包 zip 便于下载 ----------
if command -v zip >/dev/null; then
  BASE="${OUT##*/}"
  (cd "$(dirname "$OUT")" && zip -qr "${BASE}.zip" "$BASE")
  echo "已打包: $(dirname "$OUT")/${BASE}.zip"
  echo "→ 用文件管理器(FileStation 等)下载这一个 zip 文件即可，避免多选下载漏文件。"
else
  echo "提示: 未安装 zip，请在文件管理器中直接下载文件夹 $OUT"
  echo "     (若想打包: apk add zip 或 apt-get install zip)"
fi
