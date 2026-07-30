# tr-exporter

[English](README_EN.md) | **中文**

> **EN:** An interactive shell script to batch-export `.torrent` files from **Transmission** or **qBittorrent**, filtered by tracker. Designed for Docker clients on QNAP / Synology NAS — no SSH required.

按 Tracker 批量导出 **Transmission / qBittorrent** 的 `.torrent` 种子文件的交互式脚本。

特别适合 **QNAP / 群晖等 NAS 上的 Docker 版客户端**——无需 SSH，只需在 Container Station / 容器管理器的「终端」里运行即可。

## 解决什么问题

Transmission / qBittorrent 自带界面都没有「按 Tracker 一键导出」功能。当你需要：

- 备份某个 PT 站点的全部种子
- 从某站点迁移到另一个客户端
- 统计 / 整理某 Tracker 下的种子

……就要手动一个个找、一个个导。本脚本通过 Transmission 的 RPC 接口，**一键筛出指定 Tracker（或全部）的种子并打包下载**。

## 特性

- 🖥 **纯交互式**：选择客户端、输入地址/端口/认证、选 Tracker，不用改脚本
- 🔀 **双客户端**：一个入口同时支持 **Transmission** 和 **qBittorrent**
- 🎯 **按 Tracker 筛选**：列出现有 Tracker，按序号选择 / 关键字匹配 / 全部导出
- 🔍 **智能定位种子目录**（Transmission）：自动跳过 `/kettu/templates/torrents` 等「假目录」，只认含 40 位 hex 种子文件的真实目录
- 📦 **自动打包 zip**：导出后压成单个 zip，用文件管理器下载一个文件即可，避免多选下载漏文件
- 🔧 **自动装依赖**：缺少 `jq` / `zip` 时自动尝试安装（Alpine `apk` / Debian `apt`）
- 🔒 **无硬编码凭据**：所有地址、账号、密码运行时输入，脚本本身可安全公开

## 快速开始

### 1. 打开容器终端

在 NAS 的容器管理界面（QNAP Container Station / Container Manager 等）找到 Transmission 容器，打开其 **终端 / Terminal / Exec**，启动一个 `/bin/sh` 或 `/bin/bash` 窗口。

### 2. 把脚本写进容器并运行

因为是交互式脚本（含 `read` 输入），**不能直接整段粘贴到终端**——`read` 会把后续粘贴内容当成输入。推荐用 heredoc 写入文件再执行：

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

===== Tracker 列表 =====
  1) pt.soulvoice.club
  2) tracker.m-team.cc
  ...
  5) 全部导出

选择序号，或直接输入关键字(留空=全部): 1
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
| 留空回车 | **全部导出** |

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

- 导出的是原始 `.torrent` 文件。**不包含下载进度**（`.resume`）。
- 若要迁移到其它客户端且保留进度，还需配合目标客户端的「加载种子 + 相同数据路径 + 校验」流程，`.resume` 无法直接跨客户端使用。

## License

MIT
