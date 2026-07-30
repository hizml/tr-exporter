# tr-exporter

**[English](README_EN.md)** | [中文](README.md)

An interactive shell script to batch-export `.torrent` files from **Transmission** or **qBittorrent**, filtered by tracker.

Perfect for **Docker-based clients running on QNAP / Synology NAS** — no SSH required. Just open the container's built-in **Terminal / Exec** panel and run the script.

## What problem does it solve?

Neither Transmission nor qBittorrent's Web UI offers a one-click "export all torrents from tracker X" feature. When you need to:

- Back up every torrent from a specific private tracker (PT site)
- Migrate a site's torrents to another client
- Audit / organize torrents under a given tracker

…you'd otherwise have to hunt and export them one by one. This script uses each client's Web API to **filter by tracker (or export everything) and package the files for download** in one shot.

## Features

- 🖥 **Fully interactive** — choose client, type host/port/credentials, pick a tracker; no need to edit the script
- 🎯 **Filter by tracker** — lists existing trackers; select by number / keyword match / export all
- 🔀 **Two clients** — Transmission **and** qBittorrent from a single entry point
- 📦 **Auto zip** — exports are packed into a single zip so you download one file (avoids multi-select download losses)
- 🔧 **Auto-installs deps** — `jq` / `zip` installed on the fly via Alpine `apk` or Debian `apt` when missing
- 🔒 **No hardcoded credentials** — everything is entered at runtime; the script itself is safe to publish

## Quick start

### 1. Open the container terminal

In your NAS container manager (QNAP Container Station / Container Manager, Synology Container Manager, Portainer, etc.), find the Transmission/qBittorrent container and open its **Terminal / Exec**, launching a `/bin/sh` or `/bin/bash` window.

### 2. Write the script into the container and run it

Because it's an interactive script (it uses `read`), **don't paste it directly into the terminal** — `read` would swallow the pasted text as input. Use a heredoc to write it to a file first, then execute:

```sh
cat > /tmp/export.sh <<'EOF'
# …… paste the full contents of export-torrents.sh here ……
EOF
sh /tmp/export.sh
```

> 💡 You can also drop `export-torrents.sh` into the container's mapped shared folder (e.g. `/config`) and edit/run it via the file manager — no heredoc needed.

### 3. Follow the prompts

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
   ...
选择序号或直接输入主机 (留空=默认 1):        ← Enter = 127.0.0.1
端口 (留空=默认 9091):                       ← Enter = 9091; for qB default is 8080

【认证】用户名 (无认证可留空): qnap
密码:                                        ← not echoed

正在连接...
✅ 连接成功，共 470 个种子

===== Tracker 列表 =====
  1) pt.soulvoice.club
  2) tracker.m-team.cc
  ...
  5) 全部导出

选择序号，或直接输入关键字 (留空=全部): 1
→ 选择: pt.soulvoice.club

[OK]   MovieA
[OK]   MovieB
...
===== 完成 =====
导出数量: 96 个
已打包: /config/export_20260731_000710.zip
```

### 4. Download the exported zip

Use the NAS file manager (QNAP FileStation, etc.) to open the mapped `/config` folder, find `export_xxxxxx.zip`, right-click **Download**. Verify the count after extracting locally.

## Tracker selection

| Input | Effect |
|------|------|
| A number, e.g. `1` | Select the 1st tracker in the list |
| A keyword, e.g. `soulvoice` | Case-insensitive fuzzy match |
| **Empty (Enter)** | **Export every torrent (all trackers)** |

> 💡 Want to export all torrents at once? Just press **Enter** at the tracker prompt.

## Exporting progress (for migration)

After choosing a tracker, the script asks whether to also export progress files — enter `y`. Progress files let you migrate to another machine **without re-checking**:

| Client | Progress file | Migration scope |
|--------|---------------|-----------------|
| Transmission | `<hash>.resume` | between same-version Transmission |
| qBittorrent | `<hash>.fastresume` | between qBittorrent instances |

Resulting directory layout:
```
export_xxxxxx/
├── torrents/    ← .torrent files
└── resume/      ← progress files (only when progress export is chosen)
```

> ⚠️ Progress files are **NOT portable across clients** (Tr's resume can't be used by qB, and vice versa). For cross-client migration, use the target client's "load torrent + same data path + recheck" flow.

## How export works per client

| | Transmission | qBittorrent |
|---|---|---|
| Auth | username/password + `X-Transmission-Session-Id` header | `POST /auth/login` → `SID` cookie (+ `Referer` for CSRF) |
| List | `torrent-get` (trackers array) | `torrents/info` (top-level `tracker` field) |
| Export | copy the `.torrent` file from disk | `GET /torrents/export?hash=` via API |

> qBittorrent requires **v4.1.4+** (Web API v2.2.0) for the export endpoint. Older versions will report `[FAIL] … HTTP 404`.

## Dependencies

- `curl` (usually preinstalled in images)
- `jq` (auto-installed if missing)
- `zip` (optional; if missing, only the zip step is skipped — export still works)

## FAQ

**Q: Export count ≠ downloaded count?**
A: Usually the NAS file manager's "multi-select → download" zipping is unreliable. This script already packs everything into a **single zip**; download that one file to avoid the problem.

**Q: All `[MISS]` (Transmission)?**
A: The torrents directory was mislocated (commonly matching `/kettu/templates/torrents`). The script auto-skips such decoy dirs; if it still fails it will prompt for the real path.

**Q: All `[FAIL]` (qBittorrent)?**
A: Your qBittorrent is too old and lacks the export endpoint. Upgrade to v4.1.4+.

**Q: HTTP 409 Conflict (Transmission)?**
A: Normal CSRF mechanism — the script re-fetches the session-id automatically.

**Q: Connection failed / `parse error`?**
A: Usually wrong host/port/credentials. Check whether Authentication is enabled in settings and confirm the port (Transmission 9091 / qBittorrent 8080 by default).

## Limitations

- Exports the raw `.torrent` file by default; **progress files are optional** (see "Exporting progress" above).
- Progress files are **NOT portable across clients**; for cross-client migration, use the target client's "load torrent + same data path + recheck" flow.
- This project ships with automated [ShellCheck](https://www.shellcheck.net/) via GitHub Actions, but the script is not tested on every client version — validate on a small batch first.

## License

MIT
