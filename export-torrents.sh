#!/bin/sh
# export-torrents.sh — 按 Tracker 批量导出 Transmission / qBittorrent 的 .torrent 种子文件
# 交互式：选择客户端 → 输入地址/端口/认证 → 选 Tracker 或全部导出 → 导出后自动打包 zip。
# 适用：Docker / QNAP Container Station 终端等无 SSH 场景，或任意能访问 Web API 的环境。

echo "===== 种子导出工具 (Transmission / qBittorrent) ====="
echo

# ============================================================
# 0. 选择客户端
# ============================================================
echo "【选择客户端】"
echo "   1) Transmission"
echo "   2) qBittorrent"
printf "选择序号 (留空=默认 1): "
read CLIENT_INPUT
case "$CLIENT_INPUT" in
  2) CLIENT="qb" ;;
  *) CLIENT="tr" ;;
esac
[ "$CLIENT" = "qb" ] && echo "  → qBittorrent" || echo "  → Transmission"
echo

# ============================================================
# 1. 地址 + 端口
# ============================================================
echo "【Web 地址】"
echo "  常见主机预设："
echo "   1) 127.0.0.1   (容器内本机，最常用)"
echo "   2) localhost"
echo "   3) 自定义 IP / 域名  (例如 NAS 局域网 IP，从容器外访问)"
printf "选择序号或直接输入主机 (留空=默认 1): "
read HOST_INPUT
case "$HOST_INPUT" in
  ""|1) HOST="127.0.0.1" ;;
  2)    HOST="localhost" ;;
  3)    printf "    请输入主机 IP/域名: "; read HOST ;;
  *)    HOST="$HOST_INPUT" ;;
esac

# 默认端口：Transmission=9091，qBittorrent=8080
if [ "$CLIENT" = "qb" ]; then DEFAULT_PORT="8080"; else DEFAULT_PORT="9091"; fi
printf "端口 (留空=默认 %s): " "$DEFAULT_PORT"
read PORT_INPUT
[ -z "$PORT_INPUT" ] && PORT_INPUT="$DEFAULT_PORT"

if [ "$CLIENT" = "qb" ]; then
  BASE="http://${HOST}:${PORT_INPUT}"
  API="$BASE/api/v2"
else
  RPC="http://${HOST}:${PORT_INPUT}/transmission/rpc"
fi
echo "  → 使用: ${RPC:-$BASE}"
echo

# ============================================================
# 2. 账号密码
# ============================================================
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

# ============================================================
# 3. 依赖
# ============================================================
command -v jq >/dev/null || {
  echo "正在安装 jq..."
  apk add --no-cache jq 2>/dev/null || { apt-get update >/dev/null 2>&1 && apt-get install -y jq >/dev/null 2>&1; }
}
command -v jq >/dev/null || { echo "❌ 无法安装 jq，请手动安装后重试"; exit 1; }

# cookie 文件 (qB 登录用)
COOKIE=$(mktemp)
trap 'rm -f "$COOKIE" /tmp/tr_find_*.txt' EXIT 2>/dev/null

# 工具函数: 在目录中是否存在匹配指定后缀且符合 hex 文件名的文件
#   has_hex_files <目录> <后缀> <期望hex长度(0=不校验长度)>
has_hex_files() {
  _dir="$1"; _suf="$2"; _len="$3"
  for f in "$_dir"/*."$_suf"; do
    [ -e "$f" ] || continue
    _b=$(basename "$f" ".$_suf")
    [ "$_len" = "0" ] && return 0
    # 校验: 纯 hex 且长度匹配
    case "$_b" in
      *[!0-9a-fA-F]*) continue ;;
      *)
        [ ${#_b} -eq "$_len" ] && return 0
        ;;
    esac
  done
  return 1
}

# 工具函数: 用 find -exec + while read 安全地查找目录 (避免 for-in-find 在含空格路径上出错)
#   find_first_dir <目录名> <后缀> <期望hex长度(0=不校验)>
find_first_dir() {
  _name="$1"; _suf="$2"; _len="$3"
  find / -type d -name "$_name" 2>/dev/null > /tmp/tr_find_$$.txt
  while IFS= read -r _d; do
    [ -z "$_d" ] && continue
    if has_hex_files "$_d" "$_suf" "$_len"; then
      printf '%s' "$_d"; return 0
    fi
  done < /tmp/tr_find_$$.txt
  rm -f /tmp/tr_find_$$.txt
  return 1
}

# 工具函数: 在多个同名目录里，选出「最匹配种子 hash」的那个
#   find_best_resume_dir <目录名> <后缀> <候选hash1> [候选hash2] ...
# 逻辑: 遍历所有同名目录，统计能命中多少个候选 hash 的进度文件，返回命中数最多的目录
find_best_resume_dir() {
  _name="$1"; _suf="$2"; shift 2
  find / -type d -name "$_name" 2>/dev/null > /tmp/tr_find_$$.txt
  _best=""; _best_hit=0
  while IFS= read -r _d; do
    [ -z "$_d" ] && continue
    has_hex_files "$_d" "$_suf" 0 || continue
    _hit=0
    for _h in "$@"; do
      [ -n "$_h" ] && [ -e "$_d/${_h}.${_suf}" ] && _hit=$((_hit+1))
    done
    if [ "$_hit" -gt "$_best_hit" ]; then _best_hit=$_hit; _best=$_d; fi
  done < /tmp/tr_find_$$.txt
  rm -f /tmp/tr_find_$$.txt
  [ -n "$_best" ] && printf '%s' "$_best" && return 0
  return 1
}

# ============================================================
# 4. 连接 + 认证
# ============================================================
echo "正在连接..."

if [ "$CLIENT" = "tr" ]; then
  # Transmission: 拿 session-id
  SID=$(curl -s $AUTH -D - -o /dev/null "$RPC" | grep -i 'X-Transmission-Session-Id' | awk '{print $2}' | tr -d '\r')
  COUNT=$(curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
    -d '{"method":"torrent-get","arguments":{"fields":["id"]}}' | jq '.arguments.torrents|length' 2>/dev/null)
else
  # qBittorrent: 登录拿 SID cookie (需带 Referer 绕过 CSRF)
  if [ -n "$USER" ]; then
    LOGIN_BODY=$(curl -s -c "$COOKIE" -b "$COOKIE" -H "Referer: $BASE" \
      --data-urlencode "username=$USER" --data-urlencode "password=$PASS" \
      "$API/auth/login")
    if [ "$LOGIN_BODY" != "Ok." ]; then
      echo "❌ 登录失败: $LOGIN_BODY"; exit 1
    fi
  fi
  COUNT=$(curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" | jq 'length' 2>/dev/null)
fi

if ! echo "$COUNT" | grep -qE '^[0-9]+$'; then
  echo "❌ 连接失败，请检查地址 / 端口 / 账号 / 密码"; exit 1
fi
echo "✅ 连接成功，共 $COUNT 个种子"
echo

# ============================================================
# 5. 定位种子目录 (仅 Transmission 用磁盘方式；qB 用 API 导出，无需)
# ============================================================
TORRENTS_DIR=""
if [ "$CLIENT" = "tr" ]; then
  echo "正在定位种子目录..."
  TORRENTS_DIR=$(find_first_dir torrents torrent 40)
  if [ -z "$TORRENTS_DIR" ]; then
    printf "❌ 自动定位失败，请手动输入 torrents 目录路径 (留空取消): "
    read TORRENTS_DIR
    [ -z "$TORRENTS_DIR" ] && { echo "已取消"; exit 1; }
  fi
  echo "种子目录: $TORRENTS_DIR"
  echo
fi

# Transmission 的 resume 目录: 与 torrents 同级的 resume 目录(<hash>.resume)
TR_RESUME_DIR=""
if [ "$CLIENT" = "tr" ] && [ -n "$TORRENTS_DIR" ]; then
  TR_RESUME_DIR=$(dirname "$TORRENTS_DIR")/resume
  [ -d "$TR_RESUME_DIR" ] || TR_RESUME_DIR=""
fi
# qBittorrent 的进度目录定位推迟到第 7.5 步(需要种子 hash 才能反查多个 BT_backup)

# ============================================================
# 6. 列出 Tracker
# ============================================================
echo "===== Tracker 列表 (含种子数) ====="
# 统计每个 tracker 域名下的种子数量，输出两列: "域名<TAB>数量"
# 空 tracker 的种子用占位标记 __NONE__ 单独统计并显示为 "(无 tracker)"
# Transmission: 一个种子可能有多个 tracker，无任何 tracker 的种子计入 __NONE__
# qBittorrent: tracker 字段为空字符串的种子计入 __NONE__
if [ "$CLIENT" = "tr" ]; then
  curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
    -d '{"method":"torrent-get","arguments":{"fields":["trackers"]}}' \
    | jq -r '
        [ .arguments.torrents[]
          | (if (.trackers|length)==0 then "__NONE__"
             else (.trackers[].announce | sub("^https?://"; "") | sub("/.*$"; "")) end)
        ] | group_by(.)[] | "\(.[0])\t\(length)"
      ' 2>/dev/null
else
  curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
    | jq -r '
        [ .[]
          | (.tracker | sub("^https?://"; "") | sub("/.*$"; "")
             | if . == "" then "__NONE__" else . end)
        ] | group_by(.)[] | "\(.[0])\t\(length)"
      ' 2>/dev/null
fi | sort -t"	" -k1 > /tmp/tr_list.txt

# 显示列表: "  序号) 域名 (N 个种子)"，空 tracker 显示为 "(无 tracker)"
i=1
while IFS="	" read -r domain count; do
  [ -z "$domain" ] && continue
  [ "$domain" = "__NONE__" ] && domain="(无 tracker)"
  printf "  %s) %s (%s 个)\n" "$i" "$domain" "$count"
  i=$((i+1))
done < /tmp/tr_list.txt
ALL_N=$((i-1))
printf "  a) 全部导出 (%s 个)\n" "$COUNT"
echo

# ============================================================
# 7. 选择 Tracker
# ============================================================
# 留空不再默认"全部"，避免误触；必须显式输 a 才全部，输错则重新提示
while true; do
  printf "选择序号 / 关键字 / 输入 a 全部导出: "
  read SEL
  KEY=""
  if [ "$SEL" = "a" ] || [ "$SEL" = "A" ]; then
    echo "→ 全部导出"; break
  elif echo "$SEL" | grep -qE '^[0-9]+$'; then
    if [ "$SEL" -ge 1 ] && [ "$SEL" -le "$ALL_N" ]; then
      KEY=$(sed -n "${SEL}p" /tmp/tr_list.txt | cut -f1)
      if [ "$KEY" = "__NONE__" ]; then echo "→ 选择: (无 tracker)"
      else echo "→ 选择: $KEY"; fi
      break
    fi
    echo "  ⚠️ 序号超出范围 (1-$ALL_N)，请重新输入"
  elif [ -z "$SEL" ]; then
    echo "  ⚠️ 不能留空，输入序号 / 关键字 / a(全部)"
  else
    KEY="$SEL"; echo "→ 关键字: $KEY"; break
  fi
done
echo

# ---------- 7.5 定位 qB 进度目录 (用种子 hash 反查多个 BT_backup，选命中率最高的) ----------
QB_RESUME_DIR=""
if [ "$CLIENT" = "qb" ]; then
  # 取前若干个种子的 hash 作为样本，用于反查哪个 BT_backup 命中率最高
  # 用 ascii_downcase + contains 做大小写不敏感的纯字符串匹配(避免 KEY 含正则元字符)
  KEY_LOWER=$(printf '%s' "$KEY" | tr '[:upper:]' '[:lower:]')
  if [ -z "$KEY" ]; then
    SAMPLE_HASHES=$(curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
      | jq -r '.[0:5][].hash' 2>/dev/null)
  elif [ "$KEY" = "__NONE__" ]; then
    SAMPLE_HASHES=$(curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
      | jq -r '[.[] | select(.tracker == "")][0:5][].hash' 2>/dev/null)
  else
    SAMPLE_HASHES=$(curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
      | jq -r --arg k "$KEY_LOWER" '[.[] | select((.tracker|ascii_downcase)|contains($k))][0:5][].hash' 2>/dev/null)
  fi
  if [ -n "$SAMPLE_HASHES" ]; then
    QB_RESUME_DIR=$(find_best_resume_dir BT_backup fastresume $SAMPLE_HASHES)
  fi
  # 样本命中失败则退回到「文件最多的目录」
  if [ -z "$QB_RESUME_DIR" ]; then
    QB_RESUME_DIR=$(find_first_dir BT_backup fastresume 0)
  fi
fi

# ---------- 是否同时导出进度文件 ----------
EXPORT_RESUME="n"
if [ "$CLIENT" = "tr" ]; then
  PROGRESS_DESC="进度文件 (.resume，用于同版本 Transmission 迁移)"
  HAVE_DIR="$TR_RESUME_DIR"
else
  PROGRESS_DESC="进度文件 (.fastresume，用于 qBittorrent 迁移)"
  HAVE_DIR="$QB_RESUME_DIR"
fi
printf "【进度】是否同时导出 %s? (y/N): " "$PROGRESS_DESC"
read RESUME_INPUT
case "$RESUME_INPUT" in
  y|Y|yes|YES)
    if [ -z "$HAVE_DIR" ]; then
      printf "  ⚠️ 未自动定位到进度目录，请手动输入路径 (留空=跳过进度): "
      read HAVE_DIR
      [ -z "$HAVE_DIR" ] && { echo "  → 跳过进度导出"; HAVE_DIR=""; }
    fi
    EXPORT_RESUME="$HAVE_DIR"
    echo "  → 导出进度: $EXPORT_RESUME"
    ;;
  *)
    echo "  → 跳过进度导出"
    ;;
esac
echo

# ============================================================
# 8. 导出
# ============================================================
OUT="/config/export_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT" 2>/dev/null || OUT="./export_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT/torrents"
[ "$EXPORT_RESUME" != "n" ] && mkdir -p "$OUT/resume"

export AUTH SID RPC API BASE COOKIE CLIENT KEY OUT TORRENTS_DIR EXPORT_RESUME

if [ "$CLIENT" = "tr" ]; then
  # Transmission: 从磁盘复制 .torrent (+ 可选 .resume)
  curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
    -d '{"method":"torrent-get","arguments":{"fields":["name","hashString","trackers"]}}' \
  | jq -c '.arguments.torrents[]' | while read -r t; do
      MATCH=0
      if [ -z "$KEY" ]; then MATCH=1
      elif [ "$KEY" = "__NONE__" ]; then
        # 无 tracker 的种子: trackers 数组为空
        [ "$(echo "$t" | jq -r '.trackers|length')" = "0" ] && MATCH=1
      elif echo "$t" | jq -r '.trackers[].announce' | grep -qiF "$KEY"; then MATCH=1; fi
      if [ "$MATCH" = "1" ]; then
        name=$(echo "$t" | jq -r '.name')
        hash=$(echo "$t" | jq -r '.hashString')
        src="$TORRENTS_DIR/$hash.torrent"
        if [ -f "$src" ]; then
          cp "$src" "$OUT/torrents/${hash}.torrent"
          # 可选: 复制进度文件
          rlog=""
          if [ "$EXPORT_RESUME" != "n" ]; then
            rsrc="$EXPORT_RESUME/$hash.resume"
            if [ -f "$rsrc" ]; then cp "$rsrc" "$OUT/resume/${hash}.resume"; rlog=" +resume"
            else rlog=" [no-resume]"; fi
          fi
          printf "[OK]   %s%s\n" "$name" "$rlog"
        else
          printf "[MISS] %s\n" "$name"
        fi
      fi
    done
else
  # qBittorrent: 用 API 逐个导出 (+ 可选 .fastresume)
  curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" \
    | jq -c '.[]' | while read -r t; do
        name=$(echo "$t" | jq -r '.name')
        hash=$(echo "$t" | jq -r '.hash')
        tracker=$(echo "$t" | jq -r '.tracker')
        MATCH=0
        if [ -z "$KEY" ]; then MATCH=1
        elif [ "$KEY" = "__NONE__" ]; then
          # 无 tracker 的种子: tracker 字段为空
          [ -z "$tracker" ] && MATCH=1
        elif echo "$tracker" | grep -qiF "$KEY"; then MATCH=1; fi
        if [ "$MATCH" = "1" ]; then
          dst="$OUT/torrents/${hash}.torrent"
          http=$(curl -s -b "$COOKIE" -H "Referer: $BASE" -o "$dst" -w "%{http_code}" \
            "$API/torrents/export?hash=$hash")
          # 校验：成功的 .torrent 是 bencode，首字符为 'd'
          if [ "$http" = "200" ] && [ -s "$dst" ] && head -c1 "$dst" | grep -q 'd'; then
            # 可选: 复制进度文件
            rlog=""
            if [ "$EXPORT_RESUME" != "n" ]; then
              rsrc="$EXPORT_RESUME/$hash.fastresume"
              if [ -f "$rsrc" ]; then cp "$rsrc" "$OUT/resume/${hash}.fastresume"; rlog=" +resume"
              else rlog=" [no-resume]"; fi
            fi
            printf "[OK]   %s%s\n" "$name" "$rlog"
          else
            rm -f "$dst"
            printf "[FAIL] %s (HTTP %s，可能 qB 版本过旧不支持 export)\n" "$name" "$http"
          fi
        fi
      done
fi

echo
echo "===== 完成 ====="
echo "导出目录: $OUT"
# 用 glob 循环计数 (兼容路径含空格，且无匹配时不报错)
TOTAL=0
for _f in "$OUT/torrents/"*.torrent; do [ -e "$_f" ] && TOTAL=$((TOTAL+1)); done
echo "种子数量: $TOTAL 个"
if [ "$EXPORT_RESUME" != "n" ]; then
  RTOTAL=0
  for _f in "$OUT/resume/"*.resume "$OUT/resume/"*.fastresume; do
    [ -e "$_f" ] && RTOTAL=$((RTOTAL+1))
  done
  echo "进度文件: $RTOTAL 个"
fi

# ============================================================
# 9. 打包 zip
# ============================================================
if command -v zip >/dev/null; then
  BASE_NAME="${OUT##*/}"
  (cd "$(dirname "$OUT")" && zip -qr "${BASE_NAME}.zip" "$BASE_NAME")
  echo "已打包: $(dirname "$OUT")/${BASE_NAME}.zip"
  echo "→ 用文件管理器(FileStation 等)下载这一个 zip 文件即可，避免多选下载漏文件。"
else
  echo "提示: 未安装 zip，请在文件管理器中直接下载文件夹 $OUT"
  echo "     (若想打包: apk add zip 或 apt-get install zip)"
fi
