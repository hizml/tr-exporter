# torrent-toolkit

[![ShellCheck](https://github.com/hizml/torrent-toolkit/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/hizml/torrent-toolkit/actions/workflows/shellcheck.yml)
![version](https://img.shields.io/badge/version-1.4.0-blue)

[English](README_EN.md) | **中文**

> **EN:** A shell toolkit to batch **export / import** `.torrent` files for **Transmission** or **qBittorrent**, filtered by tracker. Designed for Docker clients on QNAP / Synology NAS — no SSH required.

Transmission / qBittorrent 的种子管理工具集——批量**导入 / 导出** `.torrent` 文件，支持按 Tracker 筛选。

特别适合 **QNAP / 群晖等 NAS 上的 Docker 版客户端**——无需 SSH，只需在 Container Station / 容器管理器的「终端」里运行即可。

## 工具一览

| 脚本 | 功能 | 状态 |
|------|------|------|
| `export-torrents.sh` | 按 Tracker 批量**导出**种子（含进度文件、增量、报告） | ✅ 可用 |
| `import-torrents.sh` | 批量**导入**种子到客户端（接续进度迁移） | 🔨 规划中 |

## 解决什么问题

Transmission / qBittorrent 自带界面都没有「按 Tracker 一键导出」功能。当你需要：

- 备份某个 PT 站点的全部种子
- 从某站点迁移到另一个客户端
- 统计 / 整理某 Tracker 下的种子

……就要手动一个个找、一个个导。本脚本通过 Transmission 的 RPC 接口，**一键筛出指定 Tracker（或全部）的种子并打包下载**。

## 特性

- 🖥 **纯交互式**：选择客户端、输入地址/端口/认证、选 Tracker，不用改脚本
- ⚡ **非交互模式**：命令行参数覆盖任意交互项，可写进 crontab 定时备份
- 🔀 **双客户端**：一个入口同时支持 **Transmission** 和 **qBittorrent**
- 🎯 **按 Tracker 筛选**：列出现有 Tracker（**含数量**），按序号选择 / 关键字匹配 / 全部导出
- 📈 **增量导出**：`--incr` 跳过已导出的种子，重复备份秒级完成
- 🌐 **中英文切换**：启动选语言，或 `--lang zh|en` 指定
- 🔍 **智能定位种子目录**（Transmission）：自动跳过 `/kettu/templates/torrents` 等「假目录」，只认含 40 位 hex 种子文件的真实目录
- 📦 **自动打包 zip**：导出后压成单个 zip，用文件管理器下载一个文件即可，避免多选下载漏文件
- 📄 **导出报告**：自动生成 `report.txt`，含时间/客户端/Tracker/数量，方便核对
- 🔧 **自动装依赖**：缺少 `jq` / `zip` 时自动尝试安装（Alpine `apk` / Debian `apt`）
- 🔄 **自更新**：`--update` 检查并升级到最新版本
- 🔒 **无硬编码凭据**：所有地址、账号、密码运行时输入，脚本本身可安全公开

## 快速开始

### 1. 打开容器终端

在 NAS 的容器管理界面（QNAP Container Station / Container Manager 等）找到 Transmission 容器，打开其 **终端 / Terminal / Exec**，启动一个 `/bin/sh` 或 `/bin/bash` 窗口。

### 2. 把脚本写进容器并运行

在容器终端里运行脚本有两种方式：

**方式 A（推荐）：一行命令从 GitHub 拉取并运行** —— 换设备/换容器时最省事，永远用最新版：

```sh
curl -fsSL https://raw.githubusercontent.com/hizml/torrent-toolkit/main/export-torrents.sh -o /tmp/export.sh && sh /tmp/export.sh
```

> 前提：容器能访问外网（GitHub）。QNAP Docker 默认即可。

**方式 B（离线/内网）：手动粘贴脚本内容** —— 因为是交互式脚本（含 `read` 输入），**不能直接整段粘贴到终端**（`read` 会把后续粘贴内容当成输入）。用 heredoc 写入文件再执行：

```sh
cat > /tmp/export.sh <<'EOF'
# ……（此处粘贴 export-torrents.sh 的完整内容）……
EOF
sh /tmp/export.sh
```

> 💡 也可以把 `export-torrents.sh` 放进容器已映射的共享文件夹（如 `/config`），用文件管理器从 NAS 上直接编辑/运行，省去 heredoc。

### 3. 按提示操作

```
===== 种子导出工具 (Transmission / qBittorrent) =====

【选择客户端】
   1) Transmission
   2) qBittorrent
选择序号 (留空=默认 1): 1
  → Transmission

【Web 地址】
  常见主机预设：
   1) 127.0.0.1   (容器内本机，最常用)
   2) localhost
   3) 自定义 IP / 域名  (例如 NAS 局域网 IP，从容器外访问)
选择序号或直接输入主机 (留空=默认 1):        ← 回车即用默认 127.0.0.1
端口 (留空=默认 9091):                       ← 回车即用 9091；选 qB 时默认 8080

【认证】用户名 (无认证可留空): qnap
密码:                                          ← 输入不回显

正在连接 Transmission...
✅ 连接成功，共 470 个种子

种子目录: /config/torrents

===== Tracker 列表 (含种子数) =====
  1) pt.soulvoice.club (96 个)
  2) tracker.m-team.cc (312 个)
  ...
  a) 全部导出 (470 个)

选择序号 / 关键字 / 输入 a 全部导出: 1
→ 选择: pt.soulvoice.club

[OK]   电影A
[OK]   电影B
...
===== 完成 =====
导出目录: /config/export_20260731_000710
导出数量: 96 个
已打包: /config/export_20260731_000710.zip
```

### 4. 下载导出的 zip

用 NAS 的文件管理器（QNAP FileStation 等）进入 Transmission 的 `/config` 映射文件夹，找到 `export_xxxxxx.zip`，右键 **下载** 即可。本地解压后核对数量。

## Tracker 选择方式

| 输入 | 效果 |
|------|------|
| 序号，如 `1` | 选列表里第 1 个 Tracker |
| 关键字，如 `soulvoice` | 大小写不敏感的模糊匹配 |
| `a` | **导出全部种子（不限 Tracker）** |

> 💡 想把客户端里所有种子一次性导出？Tracker 选择那一步输入 `a` 即可。
> 💡 同一站点的多个域名（如 `pttime.org` 和 `pttime.online`）用关键字 `pttime` 可一次性命中。

## 同时导出进度（用于迁移）

选 Tracker 后，脚本会问「是否同时导出进度文件」，输入 `y` 即可。进度文件能让迁移到另一台时**省去重新校验**：

| 客户端 | 进度文件 | 适用迁移 |
|--------|----------|----------|
| Transmission | `<hash>.resume` | 同版本 Transmission 之间迁移 |
| qBittorrent | `<hash>.fastresume` | qBittorrent 之间迁移 |

导出后目录结构：
```
export_xxxxxx/
├── torrents/    ← .torrent 种子文件
└── resume/      ← 进度文件（仅当选择导出进度时）
```

> ⚠️ 进度文件**不可跨客户端**使用（Tr 的 resume 不能给 qB 用，反之亦然）。跨客户端迁移时，需要用目标客户端「加载种子 + 相同数据路径 + 校验」的方式接续。

## 命令行参数（非交互模式）

默认是交互式；任何一项都能用命令行参数指定，**指定后跳过对应交互**（混合模式）：

```sh
sh export-torrents.sh [OPTIONS]

  --lang zh|en        语言（zh=中文，en=英文）
  --client tr|qb      客户端：tr=Transmission，qb=qBittorrent
  --host HOST         主机（如 127.0.0.1）
  --port PORT         端口（默认 tr=9091，qb=8080）
  --user USER:PASS    认证（账号:密码）
  --tracker KEY       Tracker 关键字，'a'=全部，'__NONE__'=无 tracker 的种子
  --resume            同时导出进度文件
  --no-resume         跳过进度文件（默认）
  --incr              增量导出：跳过输出目录里已存在的种子
  --out DIR           输出目录
  --update            检查并更新脚本到最新版本
  --help              显示帮助
```

**示例——全自动备份某站点种子（可写进 crontab 定时执行）**：

```sh
sh export-torrents.sh --lang zh --client tr --host 127.0.0.1 --port 9091 \
                     --user qnap:qnap --tracker soulvoice --resume --incr \
                     --out /config/backup_soulvoice
```

## 增量导出

加 `--incr` 后，重新运行会**跳过输出目录里已经存在的种子**，只导新增的：

```
===== 完成 =====
种子数量: 3 个
跳过已导出: 93 个        ← 第二次运行，只导了 3 个新的
```

> 💡 增量模式的关键是**重复跑用同一个目录**。所以 `--incr` 默认不再用带时间戳的目录，而是按 tracker 自动用固定目录：
> - `--tracker soulvoice --incr` → `/config/backup_soulvoice/`
> - `--tracker a --incr`（全部）→ `/config/backup_all/`
>
> 这样不传 `--out` 也能直接生效。当然你也可以显式 `--out /your/dir` 指定。

适合做**定期增量备份**（写进 crontab，只补新增种子）。注意它是**只增不减**——远端种子被删除时不会从备份目录移除。

## 自更新

```sh
sh export-torrents.sh --update
```

会检查 GitHub 最新版本，有新版时自动覆盖升级（原文件备份为 `.bak`），已是最新则提示。

## 两种客户端的导出原理

| | Transmission | qBittorrent |
|---|---|---|
| 认证 | 用户名密码 + `X-Transmission-Session-Id` 请求头 | `POST /auth/login` 拿 `SID` cookie（需带 `Referer` 绕过 CSRF） |
| 列种子 | `torrent-get`（trackers 数组） | `torrents/info`（顶层 `tracker` 字段） |
| 导出 | 从磁盘复制 `.torrent` 文件 | `GET /torrents/export?hash=` 经 API 下载 |

> qBittorrent 需 **v4.1.4+**（Web API v2.2.0）才支持 export 端点；旧版会报 `[FAIL] … HTTP 404`。

## 依赖

- `curl`（容器一般自带）
- `jq`（缺失时脚本会自动尝试安装）
- `zip`（缺失时仅不打包，不影响导出本身；会提示安装命令）

## 常见问题

**Q：导出数量和下载下来数量对不上？**
A：通常是用文件管理器「多选 → 下载」打包 zip 不稳定导致的。脚本已默认把导出压成**单个 zip**，下载这一个文件即可避免。

**Q：全是 `[MISS]`（Transmission）？**
A：种子目录定位错了（常见误中 `/kettu/templates/torrents` 模板目录）。脚本已自动跳过这类假目录；若仍失败，会提示手动输入真实路径。

**Q：全是 `[FAIL]`（qBittorrent）？**
A：qBittorrent 版本过旧，缺少 export 端点。升级到 v4.1.4+。

**Q：报 409 Conflict？**
A：正常的 CSRF 机制，脚本已自动重取 `X-Transmission-Session-Id`。

**Q：连接失败 / `parse error`？**
A：多半是 RPC 地址、账号或密码不对。确认 Transmission 设置 → Remote 里是否开了 Authentication，端口是否 9091。

## 局限

- 默认仅导出 `.torrent` 种子文件；**进度文件可选导出**（见上方「同时导出进度」）。
- 进度文件**不可跨客户端**使用；跨客户端迁移时，需用目标客户端「加载种子 + 相同数据路径 + 校验」的方式接续。
- 本项目自带 [ShellCheck](https://www.shellcheck.net/) 自动检查（GitHub Actions），但脚本未在所有客户端版本上实测，建议先小范围验证。

## 换设备 / 迁移使用

脚本本身**不绑定任何设备**——只要是 Transmission 或 qBittorrent，任何能开终端的环境（NAS Docker、VPS、裸机 Linux/Mac）都能直接用，脚本一个字都不用改，只需在交互时按新设备的实际情况填：

| 场景 | 交互时怎么填 |
|------|-------------|
| 在**容器内部**终端运行 | 主机填 `127.0.0.1`（回车默认） |
| 在**宿主机或别的机器**连容器 | 主机选 `3` 填容器实际 IP |
| 端口被改过 | 端口那步输实际端口 |
| 账号密码不同 | 认证那步填新的 |
| 目录非标准布局 | 脚本自动查找；找不到会提示手动输入 |

换设备最省事的方式是用上面的 **方式 A（curl 一键拉取）**，永远跑最新版。

> ⚠️ 两个可能需要手动处理的小坑：
> - **容器没挂载 `/config`**：导出会落到当前目录 `./export_xxx`。可先 `cd` 到有挂载的目录再跑。
> - **进度目录找不到**：进度那步输 `y` 后按提示手动粘路径（如 qB 的 `/Download/qBittorrent/.local/share/qBittorrent/BT_backup`）。

## License

MIT
