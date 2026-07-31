# torrent-toolkit

[![ShellCheck](https://github.com/hizml/torrent-toolkit/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/hizml/torrent-toolkit/actions/workflows/shellcheck.yml)
![version](https://img.shields.io/badge/version-1.5.0-blue)

**[English](README_EN.md)** | [中文](README.md)

A shell toolkit to batch **export / import** `.torrent` files for **Transmission** or **qBittorrent**, filtered by tracker.

Perfect for **Docker-based clients running on QNAP / Synology NAS** — no SSH required. Just open the container's built-in **Terminal / Exec** panel and run the script.

## Tools overview

| Script | Purpose | Status |
|--------|---------|--------|
| `export-torrents.sh` | Batch **export** torrents by tracker (with progress, incremental, report) | ✅ Available |
| `import-torrents.sh` | Batch **import** torrents into a client (dedup, progress restore) | ✅ Available |

## What problem does it solve?

Neither Transmission nor qBittorrent's Web UI offers a one-click "export all torrents from tracker X" feature. When you need to:

- Back up every torrent from a specific private tracker (PT site)
- Migrate a site's torrents to another client
- Audit / organize torrents under a given tracker

…you'd otherwise have to hunt and export them one by one. This script uses each client's Web API to **filter by tracker (or export everything) and package the files for download** in one shot.

## Features

- 🖥 **Fully interactive** — choose client, type host/port/credentials, pick a tracker; no need to edit the script
- ⚡ **Non-interactive mode** — CLI flags override any prompt; cron-friendly for scheduled backups
- 🎯 **Filter by tracker** — lists existing trackers (**with counts**); select by number / keyword match / export all
- 📈 **Incremental export** — `--incr` skips already-exported torrents; repeat backups are instant
- 🔀 **Two clients** — Transmission **and** qBittorrent from a single entry point
- 🌐 **i18n** — Chinese / English switch at start, or via `--lang zh|en`
- 📦 **Auto zip** — exports are packed into a single zip so you download one file (avoids multi-select download losses)
- 📄 **Export report** — auto-generates `report.txt` with time/client/tracker/counts for verification
- 🔧 **Auto-installs deps** — `jq` / `zip` installed on the fly via Alpine `apk` or Debian `apt` when missing
- 🔄 **Self-update** — `--update` checks and upgrades to the latest release
- 🔒 **No hardcoded credentials** — everything is entered at runtime; the script itself is safe to publish

## Quick start

### 1. Open the container terminal

In your NAS container manager (QNAP Container Station / Container Manager, Synology Container Manager, Portainer, etc.), find the Transmission/qBittorrent container and open its **Terminal / Exec**, launching a `/bin/sh` or `/bin/bash` window.

### 2. Write the script into the container and run it

There are two ways to run the script in the container terminal:

**Option A (recommended): fetch & run in one line from GitHub** — easiest when switching devices/containers; always the latest version:

```sh
curl -fsSL https://raw.githubusercontent.com/hizml/torrent-toolkit/main/export-torrents.sh -o /tmp/export.sh && sh /tmp/export.sh
```

> Requires outbound internet access to GitHub. QNAP Docker works out of the box.

**Option B (offline / air-gapped): paste the script manually** — because it's an interactive script (it uses `read`), **don't paste it directly into the terminal** (read would swallow the pasted text as input). Use a heredoc to write it to a file first, then execute:

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

===== Tracker 列表 (含种子数) =====
  1) pt.soulvoice.club (96)
  2) tracker.m-team.cc (312)
  ...
  a) 全部导出 (470)

选择序号 / 关键字 / 输入 a 全部导出: 1
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
| `a` | **Export every torrent (all trackers)** |

> 💡 Want to export all torrents at once? Enter `a` at the tracker prompt.
> 💡 Multiple domains of the same site (e.g. `pttime.org` and `pttime.online`) can be matched at once with the keyword `pttime`.

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
├── resume/      ← progress files (only when progress export is chosen)
└── paths.json   ← each torrent's original download path (for import auto-restore)
```

> ⚠️ Progress files are **NOT portable across clients** (Tr's resume can't be used by qB, and vice versa). For cross-client migration, use the target client's "load torrent + same data path + recheck" flow.

## Command-line options (non-interactive mode)

Interactive by default; any prompt can be supplied via a flag, which **skips that prompt** (hybrid mode):

```sh
sh export-torrents.sh [OPTIONS]

  --lang zh|en        Language (zh=Chinese, en=English)
  --client tr|qb      Client: tr=Transmission, qb=qBittorrent
  --host HOST         Web host (e.g. 127.0.0.1)
  --port PORT         Web port (default tr=9091, qb=8080)
  --user USER:PASS    Auth credentials (user:password)
  --tracker KEY       Tracker keyword, 'a' for all, '__NONE__' for no-tracker
  --resume            Also export progress files
  --no-resume         Skip progress files (default)
  --incr              Incremental: skip already-exported torrents
  --out DIR           Output directory
  --update            Update the script to the latest release
  --help              Show help
```

**Example — fully automated backup of one site's torrents (cron-friendly):**

```sh
sh export-torrents.sh --lang en --client tr --host 127.0.0.1 --port 9091 \
                     --user qnap:qnap --tracker soulvoice --resume --incr \
                     --out /config/backup_soulvoice
```

## Incremental export

With `--incr`, re-running **skips torrents already present** in the output dir, exporting only new ones:

```
===== Done =====
Torrents: 3
Skipped (already exported): 93      ← second run, only 3 new ones
```

> 💡 Incremental mode needs **the same dir across runs**. So `--incr` no longer uses a timestamped dir — it defaults to a tracker-named fixed dir:
> - `--tracker soulvoice --incr` → `/config/backup_soulvoice/`
> - `--tracker a --incr` (all) → `/config/backup_all/`
>
> This works out of the box without `--out`, though you can still pass `--out /your/dir` explicitly.

Great for **periodic incremental backups** (in crontab, top-up new torrents only). Note it's **add-only** — torrents deleted on the client are NOT removed from the backup dir.

## Self-update

```sh
sh export-torrents.sh --update
```

Checks GitHub for the latest version; auto-upgrades (backing up the original as `.bak`) when newer, or confirms you're up to date.

---

# Import torrents (import-torrents.sh)

`import-torrents.sh` is the **mirror** of the export script — batch-import `.torrent` files into Transmission / qBittorrent, with duplicate skipping and progress restoration. Ideal for migrating exported torrents to another client.

## Quick start

```sh
curl -fsSL https://raw.githubusercontent.com/hizml/torrent-toolkit/main/import-torrents.sh -o /tmp/import.sh && sh /tmp/import.sh
```

Interactive prompts: client → host/port → credentials → **source dir** → restore progress? → save path.

## Command-line options

```sh
sh import-torrents.sh [OPTIONS]

  --lang zh|en        Language
  --client tr|qb      Client
  --host HOST         Web host
  --port PORT         Web port
  --user USER:PASS    Auth credentials
  --src DIR           Source dir containing .torrent files
  --resume            Restore progress files (.resume/.fastresume)
  --no-resume         Import torrents only (default)
  --save-path DIR     Download/save directory (empty=client default)
  --no-skip-dup       Do not skip duplicate torrents
  --skip-dup          Skip duplicates (default)
  --update            Check for updates
  --help              Show help
```

**Example — import exported torrents into a new client:**

```sh
sh import-torrents.sh --lang en --client tr --host 127.0.0.1 --port 9091 \
                     --user qnap:qnap --src /config/export_20260731_000710 \
                     --resume --save-path /Download
```

## Save-path auto-restore (paths.json)

Torrents may be scattered across different dirs (e.g. `/Download`, `/Movies`). The export script auto-generates `paths.json` recording each torrent's original download path; the import script reads it and **restores each torrent to its original path** — no manual batching needed.

```
Export: auto-generates export_xxx/paths.json
        {"abc123": "/Download", "xyz456": "/Movies", ...}

Import: reads paths.json
        torrent abc123 -> restored to /Download
        torrent xyz456 -> restored to /Movies
```

**Path priority** (on import):
1. The torrent's entry in `paths.json` (highest)
2. The global `--save-path`
3. Client default

> 💡 Full migration flow: run `export-torrents.sh` on the old client (which emits paths.json), then `import-torrents.sh` on the new client — paths are restored automatically. `--save-path` only acts as a fallback for torrents not in paths.json.

## Progress restoration notes

With `--resume`, the script copies `.resume` (Tr) / `.fastresume` (qB) back into the client's config dir. **A client restart is required to apply them**, and the data file paths on the new machine must match the original — otherwise a recheck is needed.

> ⚠️ The script only copies progress files; it does **NOT** rewrite paths inside them. Cross-path migration (data moved) requires tools like `qbfrt` to patch `.fastresume` paths, which is beyond this script's scope.

## How import works per client

| | Transmission | qBittorrent |
|---|---|---|
| Add | `torrent-add` (`filename` local path) | `torrents/add` (multipart upload) |
| Duplicate | `result: duplicate torrent` | body `Fails.` |
| Progress file | `<hash>.resume` → resume dir | `<hash>.fastresume` → BT_backup |

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

## Switching devices / migration

The script is **device-agnostic** — as long as it's Transmission or qBittorrent, any terminal-capable environment (NAS Docker, VPS, bare-metal Linux/Mac) works. No edits to the script are needed; just answer the prompts according to the new device:

| Scenario | What to enter |
|----------|---------------|
| Running inside the **container** terminal | host = `127.0.0.1` (Enter for default) |
| From the **host or another machine** | choose `3` and enter the container's IP |
| Non-default port | enter the actual port at the port prompt |
| Different credentials | enter them at the auth prompt |
| Non-standard directory layout | the script auto-detects; prompts for manual input if not found |

The easiest way on a new device is **Option A (curl one-liner)** above, which always runs the latest version.

> ⚠️ Two minor gotchas you may need to handle manually:
> - **Container has no `/config` mount**: exports land in the current dir `./export_xxx`. `cd` into a mounted folder before running.
> - **Progress dir not found**: after answering `y` to the progress prompt, paste the path manually (e.g. for qB `/Download/qBittorrent/.local/share/qBittorrent/BT_backup`).

## License

MIT
