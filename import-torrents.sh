#!/bin/sh
# import-torrents.sh — 批量导入 .torrent 种子文件到 Transmission / qBittorrent
# 交互式 + 非交互式(命令行参数)；支持查重跳过、进度接续、导入报告、中英文切换。
# 与 export-torrents.sh 配套，互为镜像。
# 适用：Docker / QNAP Container Station 终端等无 SSH 场景，或任意能访问 Web API 的环境。

VERSION="1.0.0"
REPO_RAW="https://raw.githubusercontent.com/hizml/torrent-toolkit/main/import-torrents.sh"
REPO_API="https://api.github.com/repos/hizml/torrent-toolkit/releases/latest"

# ============================================================
# i18n
# ============================================================
set_lang() {
  case "$1" in
    en)
      T_TITLE="===== Torrent Importer (Transmission / qBittorrent) ====="
      T_CLIENT="Select client"; T_TR="Transmission"; T_QB="qBittorrent"
      T_CLIENT_PROMPT="Enter number (empty=1): "
      T_WEB="Web address"; T_HOST_PRESETS="Common host presets:"
      T_HOST1="127.0.0.1   (inside container, most common)"
      T_HOST2="localhost"; T_HOST3="Custom IP / domain (e.g. NAS LAN IP)"
      T_HOST_PROMPT="Choose number or enter host (empty=1): "
      T_HOST_INPUT="    Enter host IP/domain: "
      T_PORT_PROMPT="Port (empty=default %s): "
      T_AUTH="Auth"; T_USER_PROMPT="Username (empty=no auth): "
      T_PASS_PROMPT="Password: "; T_SKIP_AUTH="  -> skip auth"; T_USE="  -> using:"
      T_INSTALL_JQ="Installing jq..."
      T_JQ_FAIL="ERROR: cannot install jq, please install manually"
      T_CONNECTING="Connecting..."; T_CONNECT_OK="Connected, %s torrents in client"
      T_CONNECT_FAIL="ERROR: connection failed, check address/port/credentials"
      T_LOGIN_FAIL="ERROR: login failed:"
      T_LANG_TITLE="Language / 语言"; T_LANG_PROMPT="Enter number (empty=1): "
      T_SRC_TITLE="Source"; T_SRC_PROMPT="Enter the dir containing .torrent files: "
      T_SRC_NOTFOUND="ERROR: dir not found"; T_SRC_EMPTY="ERROR: no .torrent files in"
      T_SRC_AUTO="  -> using subdir:"; T_SRC_COUNT="Found %s .torrent files"
      T_RESUME_TITLE="Progress"; T_RESUME_PROMPT="Also restore progress files? (y/N): "
      T_RESUME_HINT="  (y = copy .resume/.fastresume back to client dir; restart client to take effect)"
      T_RESUME_YES="  -> restore progress"; T_RESUME_NO="  -> import torrents only"
      T_RESUME_TR_DIR="  Tr resume dir:"; T_RESUME_QB_DIR="  qB BT_backup dir:"
      T_SAVE_TITLE="Save path"; T_SAVE_PROMPT="Download/save dir (empty=client default): "
      T_SAVE_USE="  -> save path:"; T_SAVE_DEFAULT="  -> use client default"
      T_PATHS_FOUND="  -> paths.json found:"
      T_PATHS_OVERRIDE="  -> your input overrides paths.json records:"
      T_PATHS_RESTORE="  -> will auto-restore each torrent to its original path:"
      T_PATHS_UNIT="records"
      T_IMPORTING="Importing..."; T_OK="[OK]  "; T_FAIL="[FAIL]"
      T_DUP="[DUP] "; T_NO_RESUME=" [no-resume]"; T_RESUME_TAG=" +resume"
      T_DONE="===== Done ====="; T_IMPORT_OK="Imported: %s"
      T_IMPORT_FAIL="Failed: %s"; T_DUP_SKIPPED="Duplicates skipped: %s"
      T_COUNT_RESUME="Progress files restored: %s"
      T_NO_RESUME_FILES="No matching progress files copied"
      T_RESUME_NOTE="-- Restart the client to apply progress files"
      T_REPORT_TITLE="Import report"; T_REPORT_TIME="Time:"
      T_REPORT_CLIENT="Client:"; T_REPORT_SRC="Source:"; T_REPORT_SAVE="Save path:"
      T_REPORT_FAIL="Failed:"
      T_VERSION_CUR="Current version: %s"; T_VERSION_CHK="Checking for updates..."
      T_VERSION_LATEST="Latest: %s"
      T_VERSION_NEW="New version available! Run with --update to upgrade."
      T_VERSION_OK="Already up to date."
      T_VERSION_ERR="Update check failed (no network?), skipped."
      ;;
    *)
      T_TITLE="===== 种子导入工具 (Transmission / qBittorrent) ====="
      T_CLIENT="选择客户端"; T_TR="Transmission"; T_QB="qBittorrent"
      T_CLIENT_PROMPT="选择序号 (留空=默认 1): "
      T_WEB="Web 地址"; T_HOST_PRESETS="常见主机预设："
      T_HOST1="127.0.0.1   (容器内本机，最常用)"
      T_HOST2="localhost"; T_HOST3="自定义 IP / 域名  (例如 NAS 局域网 IP，从容器外访问)"
      T_HOST_PROMPT="选择序号或直接输入主机 (留空=默认 1): "
      T_HOST_INPUT="    请输入主机 IP/域名: "
      T_PORT_PROMPT="端口 (留空=默认 %s): "
      T_AUTH="认证"; T_USER_PROMPT="用户名 (无认证可留空): "
      T_PASS_PROMPT="密码: "; T_SKIP_AUTH="  → 跳过认证"; T_USE="  → 使用:"
      T_INSTALL_JQ="正在安装 jq..."
      T_JQ_FAIL="❌ 无法安装 jq，请手动安装后重试"
      T_CONNECTING="正在连接..."; T_CONNECT_OK="✅ 连接成功，客户端现有 %s 个种子"
      T_CONNECT_FAIL="❌ 连接失败，请检查地址 / 端口 / 账号 / 密码"
      T_LOGIN_FAIL="❌ 登录失败:"
      T_LANG_TITLE="语言 / Language"; T_LANG_PROMPT="选择序号 (留空=默认 1): "
      T_SRC_TITLE="来源"; T_SRC_PROMPT="请输入含 .torrent 文件的目录: "
      T_SRC_NOTFOUND="❌ 目录不存在"; T_SRC_EMPTY="❌ 目录里没有 .torrent 文件:"
      T_SRC_AUTO="  → 使用子目录:"; T_SRC_COUNT="找到 %s 个 .torrent 文件"
      T_RESUME_TITLE="进度"; T_RESUME_PROMPT="是否同时接续进度文件? (y/N): "
      T_RESUME_HINT="  (y = 把 .resume/.fastresume 复制回客户端目录；需重启客户端生效)"
      T_RESUME_YES="  → 接续进度"; T_RESUME_NO="  → 仅导入种子"
      T_RESUME_TR_DIR="  Tr resume 目录:"; T_RESUME_QB_DIR="  qB BT_backup 目录:"
      T_SAVE_TITLE="保存路径"; T_SAVE_PROMPT="下载/保存目录 (留空=客户端默认): "
      T_SAVE_USE="  → 保存路径:"; T_SAVE_DEFAULT="  → 用客户端默认"
      T_PATHS_FOUND="  → 发现 paths.json:"
      T_PATHS_OVERRIDE="  → 你输入的路径会覆盖 paths.json 记录，共"
      T_PATHS_RESTORE="  → 将按 paths.json 自动恢复每个种子的原路径，共"
      T_PATHS_UNIT="条"
      T_IMPORTING="正在导入..."; T_OK="[OK]  "; T_FAIL="[FAIL]"
      T_DUP="[DUP] "; T_NO_RESUME=" [no-resume]"; T_RESUME_TAG=" +resume"
      T_DONE="===== 完成 ====="; T_IMPORT_OK="导入成功: %s 个"
      T_IMPORT_FAIL="导入失败: %s 个"; T_DUP_SKIPPED="重复跳过: %s 个"
      T_COUNT_RESUME="进度文件已复制: %s 个"
      T_NO_RESUME_FILES="没有匹配到可复制的进度文件"
      T_RESUME_NOTE="-- 重启客户端后进度文件才会生效"
      T_REPORT_TITLE="导入报告"; T_REPORT_TIME="导入时间:"
      T_REPORT_CLIENT="客户端:"; T_REPORT_SRC="来源目录:"; T_REPORT_SAVE="保存路径:"
      T_REPORT_FAIL="导入失败:"
      T_VERSION_CUR="当前版本: %s"; T_VERSION_CHK="正在检查更新..."
      T_VERSION_LATEST="最新版本: %s"
      T_VERSION_NEW="发现新版本！用 --update 升级。"
      T_VERSION_OK="已是最新版本。"
      T_VERSION_ERR="检查更新失败 (无网络?)，已跳过。"
      ;;
  esac
}

# ============================================================
# 参数解析
# ============================================================
P_LANG=""; P_CLIENT=""; P_HOST=""; P_PORT=""; P_USER=""
P_SRC=""; P_RESUME=""; P_SAVE=""; P_SKIPDUP="y"; P_UPDATE=0; P_HELP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --lang)        P_LANG="$2"; shift 2 ;;
    --lang=*)      P_LANG="${1#--lang=}"; shift ;;
    --client)      P_CLIENT="$2"; shift 2 ;;
    --client=*)    P_CLIENT="${1#--client=}"; shift ;;
    --host)        P_HOST="$2"; shift 2 ;;
    --host=*)      P_HOST="${1#--host=}"; shift ;;
    --port)        P_PORT="$2"; shift 2 ;;
    --port=*)      P_PORT="${1#--port=}"; shift ;;
    --user)        P_USER="$2"; shift 2 ;;
    --user=*)      P_USER="${1#--user=}"; shift ;;
    --src)         P_SRC="$2"; shift 2 ;;
    --src=*)       P_SRC="${1#--src=}"; shift ;;
    --resume)      P_RESUME="y"; shift ;;
    --no-resume)   P_RESUME="n"; shift ;;
    --save-path)   P_SAVE="$2"; shift 2 ;;
    --save-path=*) P_SAVE="${1#--save-path=}"; shift ;;
    --no-skip-dup) P_SKIPDUP="n"; shift ;;
    --skip-dup)    P_SKIPDUP="y"; shift ;;
    --update)      P_UPDATE=1; shift ;;
    --help|-h)     P_HELP=1; shift ;;
    *) echo "Unknown option: $1" >&2; P_HELP=1; shift ;;
  esac
done

if [ "$P_HELP" = "1" ]; then
  cat <<USAGE
import-torrents.sh v$VERSION
Usage: sh import-torrents.sh [OPTIONS]
  Interactive mode by default; options skip corresponding prompts.

Options:
  --lang zh|en        Language (zh=Chinese, en=English)
  --client tr|qb      Client: tr=Transmission, qb=qBittorrent
  --host HOST         Web host (e.g. 127.0.0.1)
  --port PORT         Web port (default: tr=9091, qb=8080)
  --user USER:PASS    Auth credentials (user:password)
  --src DIR           Source dir containing .torrent files
  --resume            Also restore progress files (.resume/.fastresume)
  --no-resume         Import torrents only (default)
  --save-path DIR     Download/save directory (empty=client default)
  --no-skip-dup       Do not skip duplicate torrents
  --skip-dup          Skip duplicates (default)
  --update            Update this script to the latest release
  --help              Show this help
USAGE
  exit 0
fi

# --update: 自更新
if [ "$P_UPDATE" = "1" ]; then
  set_lang "${P_LANG:-zh}"
  printf "$T_VERSION_CUR\n" "$VERSION"
  echo "$T_VERSION_CHK"
  LATEST=$(curl -fsSL "$REPO_API" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null)
  if [ -z "$LATEST" ]; then echo "$T_VERSION_ERR"; exit 0; fi
  LATEST=${LATEST#v}
  printf "$T_VERSION_LATEST\n" "$LATEST"
  if [ "$LATEST" != "$VERSION" ]; then
    echo "$T_VERSION_NEW"
    SCRIPT_PATH="$0"
    [ "$SCRIPT_PATH" = "sh" ] && SCRIPT_PATH=""
    if [ -n "$SCRIPT_PATH" ] && [ -w "$SCRIPT_PATH" ]; then
      cp "$SCRIPT_PATH" "${SCRIPT_PATH}.bak"
      if curl -fsSL "$REPO_RAW" -o "$SCRIPT_PATH" 2>/dev/null; then
        echo "Updated: $SCRIPT_PATH (backup: ${SCRIPT_PATH}.bak)"
      else
        cp "${SCRIPT_PATH}.bak" "$SCRIPT_PATH"; echo "Download failed, restored."
      fi
    else
      echo "Run: curl -fsSL $REPO_RAW -o import-torrents.sh"
    fi
  else
    echo "$T_VERSION_OK"
  fi
  exit 0
fi

# ============================================================
# 0. 选语言
# ============================================================
echo "$T_TITLE"
echo
if [ -z "$P_LANG" ]; then
  echo "$T_LANG_TITLE"
  echo "   1) 中文"
  echo "   2) English"
  printf "$T_LANG_PROMPT"
  read LANG_INPUT
  case "$LANG_INPUT" in
    2|en|EN) P_LANG="en" ;;
    *)       P_LANG="zh" ;;
  esac
fi
set_lang "$P_LANG"
echo

# ============================================================
# 1. 选客户端
# ============================================================
if [ -z "$P_CLIENT" ]; then
  echo "【$T_CLIENT】"
  echo "   1) $T_TR"
  echo "   2) $T_QB"
  printf "$T_CLIENT_PROMPT"
  read CLIENT_INPUT
  case "$CLIENT_INPUT" in
    2|qb|QB) CLIENT="qb" ;;
    *)       CLIENT="tr" ;;
  esac
else
  case "$P_CLIENT" in
    qb|QB|2) CLIENT="qb" ;;
    *)       CLIENT="tr" ;;
  esac
fi
[ "$CLIENT" = "qb" ] && echo "  → $T_QB" || echo "  → $T_TR"
echo

# ============================================================
# 2. 地址 + 端口
# ============================================================
if [ -z "$P_HOST" ]; then
  echo "【$T_WEB】"
  echo "  $T_HOST_PRESETS"
  echo "   1) $T_HOST1"
  echo "   2) $T_HOST2"
  echo "   3) $T_HOST3"
  printf "$T_HOST_PROMPT"
  read HOST_INPUT
  case "$HOST_INPUT" in
    ""|1) HOST="127.0.0.1" ;;
    2)    HOST="localhost" ;;
    3)    printf "$T_HOST_INPUT"; read HOST ;;
    *)    HOST="$HOST_INPUT" ;;
  esac
else
  HOST="$P_HOST"
fi

if [ "$CLIENT" = "qb" ]; then DEFAULT_PORT="8080"; else DEFAULT_PORT="9091"; fi
if [ -z "$P_PORT" ]; then
  printf "$T_PORT_PROMPT" "$DEFAULT_PORT"
  read PORT_INPUT
  [ -z "$PORT_INPUT" ] && PORT_INPUT="$DEFAULT_PORT"
else
  PORT_INPUT="$P_PORT"
fi

if [ "$CLIENT" = "qb" ]; then
  BASE="http://${HOST}:${PORT_INPUT}"; API="$BASE/api/v2"
else
  RPC="http://${HOST}:${PORT_INPUT}/transmission/rpc"
fi
echo "$T_USE ${RPC:-$BASE}"
echo

# ============================================================
# 3. 账号密码
# ============================================================
if [ -z "$P_USER" ]; then
  printf "【$T_AUTH】$T_USER_PROMPT"
  read USER
  if [ -n "$USER" ]; then
    printf "$T_PASS_PROMPT"
    stty -echo 2>/dev/null
    read PASS
    stty echo 2>/dev/null
    echo
    AUTH="-u ${USER}:${PASS}"
  else
    AUTH=""; echo "$T_SKIP_AUTH"
  fi
else
  USER="$P_USER"; PASS="${P_USER#*:}"; USER="${P_USER%%:*}"
  [ "$USER" = "$PASS" ] && PASS=""
  AUTH="-u ${USER}:${PASS}"
fi

# ============================================================
# 4. 依赖
# ============================================================
command -v jq >/dev/null || {
  echo "$T_INSTALL_JQ"
  apk add --no-cache jq 2>/dev/null || { apt-get update >/dev/null 2>&1 && apt-get install -y jq >/dev/null 2>&1; }
}
command -v jq >/dev/null || { echo "$T_JQ_FAIL"; exit 1; }

COOKIE=$(mktemp)
trap 'rm -f "$COOKIE" /tmp/tr_find_*.txt' EXIT 2>/dev/null

# ============================================================
# 5. 连接 + 认证 + 拿现有 hash 集合(用于查重)
# ============================================================
echo "$T_CONNECTING"

if [ "$CLIENT" = "tr" ]; then
  SID=$(curl -s $AUTH -D - -o /dev/null "$RPC" | grep -i 'X-Transmission-Session-Id' | awk '{print $2}' | tr -d '\r')
  EXIST_HASHES=$(curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
    -d '{"method":"torrent-get","arguments":{"fields":["hashString"]}}' | jq -r '.arguments.torrents[].hashString' 2>/dev/null)
else
  if [ -n "$USER" ]; then
    LOGIN_BODY=$(curl -s -c "$COOKIE" -b "$COOKIE" -H "Referer: $BASE" \
      --data-urlencode "username=$USER" --data-urlencode "password=$PASS" \
      "$API/auth/login")
    if [ "$LOGIN_BODY" != "Ok." ]; then
      echo "$T_LOGIN_FAIL $LOGIN_BODY"; exit 1
    fi
  fi
  EXIST_HASHES=$(curl -s -b "$COOKIE" -H "Referer: $BASE" "$API/torrents/info" | jq -r '.[].hash' 2>/dev/null)
fi

# 现有数量
EXIST_COUNT=$(printf '%s\n' "$EXIST_HASHES" | grep -cE '^[0-9a-fA-F]+$' 2>/dev/null)
if [ -z "$EXIST_COUNT" ]; then
  echo "$T_CONNECT_FAIL"; exit 1
fi
printf "$T_CONNECT_OK\n" "$EXIST_COUNT"
echo

# ============================================================
# 工具函数
# ============================================================
has_hex_files() {
  _dir="$1"; _suf="$2"; _len="$3"
  for f in "$_dir"/*."$_suf"; do
    [ -e "$f" ] || continue
    _b=$(basename "$f" ".$_suf")
    [ "$_len" = "0" ] && return 0
    case "$_b" in
      *[!0-9a-fA-F]*) continue ;;
      *) [ ${#_b} -eq "$_len" ] && return 0 ;;
    esac
  done
  return 1
}

find_first_dir() {
  _name="$1"; _suf="$2"; _len="$3"
  find / -type d -name "$_name" 2>/dev/null > /tmp/tr_find_$$.txt
  while IFS= read -r _d; do
    [ -z "$_d" ] && continue
    has_hex_files "$_d" "$_suf" "$_len" && { printf '%s' "$_d"; return 0; }
  done < /tmp/tr_find_$$.txt
  rm -f /tmp/tr_find_$$.txt
  return 1
}

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
    [ "$_hit" -gt "$_best_hit" ] && { _best_hit=$_hit; _best=$_d; }
  done < /tmp/tr_find_$$.txt
  rm -f /tmp/tr_find_$$.txt
  [ -n "$_best" ] && printf '%s' "$_best" && return 0
  return 1
}

# 查重: hash 是否在客户端现有集合里
is_dup() {
  case "$EXIST_HASHES" in *"$1"*) return 0 ;; esac
  return 1
}

# ============================================================
# 6. 选种子来源目录
# ============================================================
if [ -z "$P_SRC" ]; then
  printf "【$T_SRC_TITLE】$T_SRC_PROMPT"
  read SRC
else
  SRC="$P_SRC"
fi
if [ ! -d "$SRC" ]; then
  echo "$T_SRC_NOTFOUND"; exit 1
fi
# 兼容导出脚本结构: 若 SRC 下有 torrents/ 子目录，自动用它
if [ -d "$SRC/torrents" ]; then
  echo "$T_SRC_AUTO $SRC/torrents"
  SRC="$SRC/torrents"
fi
# 统计 .torrent 数量
SRC_COUNT=0
for _f in "$SRC"/*.torrent; do [ -e "$_f" ] && SRC_COUNT=$((SRC_COUNT+1)); done
if [ "$SRC_COUNT" = "0" ]; then
  echo "$T_SRC_EMPTY $SRC"; exit 1
fi
printf "$T_SRC_COUNT\n" "$SRC_COUNT"
echo

# ============================================================
# 7. 选进度策略
# ============================================================
if [ -z "$P_RESUME" ]; then
  printf "【$T_RESUME_TITLE】$T_RESUME_PROMPT"
  echo "$T_RESUME_HINT"
  read RESUME_INPUT
  case "$RESUME_INPUT" in
    y|Y|yes|YES) P_RESUME="y" ;;
    *)           P_RESUME="n" ;;
  esac
fi

# 定位进度文件来源目录(导出脚本的 resume/ 子目录)和客户端进度目录
RESUME_SRC=""; CLIENT_RESUME_DIR=""
if [ "$P_RESUME" = "y" ]; then
  # 来源: 与 SRC 同级的 resume 目录
  _parent=$(dirname "$SRC")
  [ -d "$_parent/resume" ] && RESUME_SRC="$_parent/resume"
  # 客户端进度目录
  if [ "$CLIENT" = "tr" ]; then
    # Tr: resume 与 torrents 同级
    CLIENT_RESUME_DIR=$(dirname "$(find_first_dir torrents torrent 40 2>/dev/null)" 2>/dev/null)/resume
    [ -d "$CLIENT_RESUME_DIR" ] || CLIENT_RESUME_DIR=""
    echo "$T_RESUME_TR_DIR ${CLIENT_RESUME_DIR:-(未定位)}"
  else
    # qB: BT_backup (用样本 hash 反查)
    _sample=""
    for _f in "$SRC"/*.torrent; do
      [ -e "$_f" ] || continue
      _sample="$_sample $(basename "$_f" .torrent)"
      _n=$(printf '%s' "$_sample" | wc -w)
      [ "$_n" -ge 5 ] && break
    done
    CLIENT_RESUME_DIR=$(find_best_resume_dir BT_backup fastresume $_sample 2>/dev/null)
    [ -z "$CLIENT_RESUME_DIR" ] && CLIENT_RESUME_DIR=$(find_first_dir BT_backup fastresume 0 2>/dev/null)
    echo "$T_RESUME_QB_DIR ${CLIENT_RESUME_DIR:-(未定位)}"
  fi
  echo "$T_RESUME_YES"
else
  echo "$T_RESUME_NO"
fi
echo

# ============================================================
# 8. 选保存路径
# ============================================================
if [ -z "$P_SAVE" ]; then
  printf "【$T_SAVE_TITLE】$T_SAVE_PROMPT"
  read SAVE_INPUT
  SAVE_PATH="$SAVE_INPUT"
else
  SAVE_PATH="$P_SAVE"
fi
if [ -n "$SAVE_PATH" ]; then echo "$T_SAVE_USE $SAVE_PATH"
else echo "$T_SAVE_DEFAULT"; fi

# 加载 paths.json (导出脚本生成，记录每个种子原始下载路径)
PATHS_JSON=$(dirname "$SRC")/paths.json
if [ -f "$PATHS_JSON" ]; then
  echo "$T_PATHS_FOUND $PATHS_JSON"
  PATHS_COUNT=$(jq 'length' "$PATHS_JSON" 2>/dev/null)
  if [ -n "$SAVE_PATH" ]; then
    # 用户输入了路径: 提示会覆盖 paths.json
    printf "%s %s %s\n" "$T_PATHS_OVERRIDE" "$PATHS_COUNT" "$T_PATHS_UNIT"
  else
    # 用户没输: 提示用 paths.json 自动恢复
    printf "%s %s %s\n" "$T_PATHS_RESTORE" "$PATHS_COUNT" "$T_PATHS_UNIT"
  fi
else
  PATHS_JSON=""
fi
echo

# ============================================================
# 9. 导入
# ============================================================
echo "$T_IMPORTING"

STAT_OK="/tmp/tr_stat_ok_$$"; STAT_FAIL="/tmp/tr_stat_fail_$$"
STAT_DUP="/tmp/tr_stat_dup_$$"; STAT_RSUME="/tmp/tr_stat_rsume_$$"
: > "$STAT_OK"; : > "$STAT_FAIL"; : > "$STAT_DUP"; : > "$STAT_RSUME"
export T_OK T_FAIL T_DUP T_NO_RESUME T_RESUME_TAG STAT_OK STAT_FAIL STAT_DUP STAT_RSUME
export P_SKIPDUP EXIST_HASHES CLIENT_RESUME_DIR RESUME_SRC P_RESUME P_SAVE PATHS_JSON
export AUTH SID RPC API BASE COOKIE CLIENT SAVE_PATH

# 把保存路径转成 jq 可用的转义字符串(处理路径中的特殊字符和反斜杠)
esc_json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

for _f in "$SRC"/*.torrent; do
  [ -e "$_f" ] || continue
  _hash=$(basename "$_f" .torrent)

  # 查重
  if [ "$P_SKIPDUP" = "y" ] && is_dup "$_hash"; then
    printf "%s %s\n" "$T_DUP" "$_hash"; echo "$_hash" >> "$STAT_DUP"; continue
  fi

  # 解析保存路径(优先级): 1.用户输入的 --save-path  2.paths.json 记录  3.客户端默认
  _save="$SAVE_PATH"
  if [ -z "$_save" ] && [ -n "$PATHS_JSON" ]; then
    _save=$(jq -r --arg h "$_hash" '.[$h] // empty' "$PATHS_JSON" 2>/dev/null)
  fi

  if [ "$CLIENT" = "tr" ]; then
    # Transmission: torrent-add 用 filename 本地路径
    if [ -n "$_save" ]; then
      _dd=$(esc_json "$_save")
      _body=$(curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
        -d "{\"method\":\"torrent-add\",\"arguments\":{\"filename\":\"$(esc_json "$_f")\",\"download-dir\":\"$_dd\",\"paused\":false}}")
    else
      _body=$(curl -s $AUTH -H "X-Transmission-Session-Id: $SID" "$RPC" \
        -d "{\"method\":\"torrent-add\",\"arguments\":{\"filename\":\"$(esc_json "$_f")\",\"paused\":false}}")
    fi
    _result=$(printf '%s' "$_body" | jq -r '.result // empty' 2>/dev/null)
    if [ "$_result" = "success" ]; then
      printf "%s %s\n" "$T_OK" "$_hash"; echo x >> "$STAT_OK"
    elif printf '%s' "$_result" | grep -qi "duplicate"; then
      printf "%s %s\n" "$T_DUP" "$_hash"; echo "$_hash" >> "$STAT_DUP"
    else
      printf "%s %s (%s)\n" "$T_FAIL" "$_hash" "$_result"; echo "$_hash ($_result)" >> "$STAT_FAIL"
    fi
  else
    # qBittorrent: torrents/add multipart 上传
    if [ -n "$_save" ]; then
      _resp=$(curl -s -b "$COOKIE" -H "Referer: $BASE" \
        -F "torrents=@$_f" -F "savepath=$_save" -F "paused=false" \
        "$API/torrents/add")
    else
      _resp=$(curl -s -b "$COOKIE" -H "Referer: $BASE" \
        -F "torrents=@$_f" -F "paused=false" \
        "$API/torrents/add")
    fi
    case "$_resp" in
      Ok.*)
        # 可选: 复制进度文件
        _rlog=""
        if [ "$P_RESUME" = "y" ] && [ -n "$CLIENT_RESUME_DIR" ]; then
          if [ -f "$RESUME_SRC/${_hash}.fastresume" ]; then
            cp "$RESUME_SRC/${_hash}.fastresume" "$CLIENT_RESUME_DIR/${_hash}.fastresume"
            _rlog="$T_RESUME_TAG"; echo x >> "$STAT_RSUME"
          else
            _rlog="$T_NO_RESUME"
          fi
        fi
        printf "%s%s %s\n" "$T_OK" "$_rlog" "$_hash"; echo x >> "$STAT_OK"
        ;;
      *)
        printf "%s %s (%s)\n" "$T_FAIL" "$_hash" "$_resp"; echo "$_hash ($_resp)" >> "$STAT_FAIL"
        ;;
    esac
  fi
done

# Transmission 的进度文件复制(在导入循环外做，因为 Tr 的 .resume 需重启才加载)
if [ "$CLIENT" = "tr" ] && [ "$P_RESUME" = "y" ] && [ -n "$CLIENT_RESUME_DIR" ] && [ -n "$RESUME_SRC" ]; then
  for _f in "$SRC"/*.torrent; do
    [ -e "$_f" ] || continue
    _hash=$(basename "$_f" .torrent)
    if [ -f "$RESUME_SRC/${_hash}.resume" ]; then
      cp "$RESUME_SRC/${_hash}.resume" "$CLIENT_RESUME_DIR/${_hash}.resume" && echo x >> "$STAT_RSUME"
    fi
  done
fi

N_OK=$(wc -l < "$STAT_OK"); N_FAIL=$(wc -l < "$STAT_FAIL")
N_DUP=$(wc -l < "$STAT_DUP"); N_RSUME=$(wc -l < "$STAT_RSUME")
rm -f "$STAT_OK" "$STAT_FAIL" "$STAT_DUP" "$STAT_RSUME"

# ============================================================
# 10. 完成 + 报告
# ============================================================
echo
echo "$T_DONE"
printf "$T_IMPORT_OK\n" "$N_OK"
if [ "$N_DUP" -gt 0 ]; then printf "$T_DUP_SKIPPED\n" "$N_DUP"; fi
if [ "$N_FAIL" -gt 0 ]; then printf "$T_IMPORT_FAIL\n" "$N_FAIL"; fi
if [ "$P_RESUME" = "y" ]; then
  if [ "$N_RSUME" -gt 0 ]; then printf "$T_COUNT_RESUME\n" "$N_RSUME"
  else echo "$T_NO_RESUME_FILES"; fi
  echo "$T_RESUME_NOTE"
fi

# 报告写入来源目录同级
REPORT_DIR=$(dirname "$SRC")
REPORT="$REPORT_DIR/import_report.txt"
{
  echo "$T_REPORT_TITLE"
  echo "$T_REPORT_TIME $(date '+%Y-%m-%d %H:%M:%S')"
  if [ "$CLIENT" = "tr" ]; then echo "$T_REPORT_CLIENT Transmission ($RPC)"
  else echo "$T_REPORT_CLIENT qBittorrent ($BASE)"; fi
  echo "$T_REPORT_SRC $SRC"
  if [ -n "$SAVE_PATH" ]; then echo "$T_REPORT_SAVE $SAVE_PATH"
  else echo "$T_REPORT_SAVE (client default)"; fi
  echo "----------------------------------------"
  printf "$T_IMPORT_OK\n" "$N_OK"
  [ "$N_DUP" -gt 0 ] && printf "$T_DUP_SKIPPED\n" "$N_DUP"
  [ "$N_FAIL" -gt 0 ] && printf "  $T_REPORT_FAIL %s\n" "$N_FAIL"
  if [ "$P_RESUME" = "y" ] && [ "$N_RSUME" -gt 0 ]; then printf "$T_COUNT_RESUME\n" "$N_RSUME"; fi
} > "$REPORT" 2>/dev/null
echo "report.txt: $REPORT"
