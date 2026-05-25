# Workstation Operations (`workstation-ops`)

A collection of system administration scripts and utilities designed to keep an Arch Linux workstation clean, updated, and resilient.

---

## 🛠️ safe-update

`safe-update` is a Bash-based update orchestrator for Arch Linux and CachyOS systems using **Btrfs** and **Snapper**. It keeps the original rollback-first workflow while adding a modular architecture, runtime configuration, structured reporting, multidimensional operational risk analysis, and ecosystem advisory correlation.

### Core Features

1. **Modular update workflow**  
   `scripts/safe-update` is the orchestration entrypoint and sources focused modules from `lib/` for config, logging, notifications, snapshots, risk analysis, utilities, and report generation.
2. **Context-aware risk analysis**  
   Pending updates are classified into `CRITICAL`, `HIGH`, `MEDIUM`, and `LOW` buckets while also tracking reboot, boot-chain, graphics-stack, core-system, and AUR-related impact metadata.
3. **Rollback-first safety**  
   A pre-update Btrfs snapshot is created with `snapper` before upgrades run.
4. **Human confirmation gates**  
   Critical updates still require explicit confirmation before the script proceeds.
5. **Ecosystem advisory intelligence**  
   Arch Linux news and CachyOS release advisories are fetched, normalized, cached, and correlated against pending packages before execution.
6. **Structured observability**  
   Each run produces both a human-readable log and a JSON report for future automation, dashboards, or advisory correlation.
7. **Manual intervention gates**  
   When an advisory indicates manual review is needed, `safe-update` requires explicit confirmation before continuing.

---

## 📋 Prerequisites

To use `safe-update`, your system must have:

* **Arch Linux** or a compatible derivative such as **CachyOS**
* **pacman-contrib** installed for `checkupdates`, which safely refreshes a temporary pacman database before detection
* **Paru** installed as the AUR helper for `paru -Syu`
* **Btrfs** with **Snapper** configured
* **libnotify** (providing `notify-send`) for desktop alerts
* **curl** for Arch Linux and CachyOS advisory retrieval when advisory intelligence is enabled
* **jq** for structured report generation and validation; when `ENABLE_REPORTS=true` (the default), `safe-update` fails fast if `jq` is unavailable

---

## 🗂️ Repository Layout

```text
workstation-ops/
├── config/
│   └── safe-update.conf
├── lib/
│   ├── advisory.sh
│   ├── archnews.sh
│   ├── cachyos.sh
│   ├── config.sh
│   ├── logging.sh
│   ├── notifications.sh
│   ├── reports.sh
│   ├── risk.sh
│   ├── snapshots.sh
│   └── utils.sh
├── scripts/
│   └── safe-update
├── VERSION
└── tests/
```

---

## 🚀 Installation & Usage

### 1. Clone the Repository

```bash
git clone https://github.com/RogFed/workstation-ops.git
cd workstation-ops
```

### 2. Make the Entrypoints Executable

```bash
chmod +x scripts/safe-update tests/run
```

### 3. Run the Update Workflow

```bash
./scripts/safe-update
```

### 4. Adjust Runtime Configuration

Defaults live in:

```text
config/safe-update.conf
```

The config file is sourced by Bash, so it should contain only trusted shell assignments from a trusted local source.

Current runtime settings include:

```bash
SAFE_UPDATE_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/safe-update"
ENABLE_NOTIFICATIONS=true
ENABLE_ARCH_NEWS=true
ENABLE_CACHYOS_NEWS=true
ENABLE_REPORTS=true
ARCH_NEWS_URL="https://archlinux.org/feeds/news/"
CACHYOS_NEWS_URL="https://cachyos.org/blog/"
ADVISORY_CACHE_TTL_SECONDS=21600
ADVISORY_MAX_ITEMS=12
TIMELINE_RETENTION=6
UPDATE_SNAPSHOT_RETENTION=5
```

---

## 🧪 Verification

### Full spec suite

```bash
./tests/run
```

### Run a single spec file

```bash
./tests/run tests/unit/risk_spec.sh
```

### Syntax-check the main script

```bash
bash -n scripts/safe-update
```

### Lint the main script when `shellcheck` is available

```bash
shellcheck scripts/safe-update
```

---

## 🗄️ Runtime Directories

Runtime-generated data lives outside the repository under:

```text
~/.local/share/safe-update/
├── logs/
├── reports/
├── cache/
└── state/
```

Key outputs:

* **Logs**: `~/.local/share/safe-update/logs/update-YYYY-MM-DDTHHMMSS.log`
* **Reports**: `~/.local/share/safe-update/reports/report-YYYY-MM-DDTHHMMSS.json` (with an automatic suffix only if a same-second collision occurs)
* **Advisory cache**: `~/.local/share/safe-update/cache/{archlinux,cachyos}-news.json`
* **Snapshots**: `pre-update-YYYY-MM-DDTHHMMSS`

## 📊 Structured Report Schema

Reports are immutable JSON records written with `jq` and validated before they are persisted.

Current report fields include:

* `version`
* `timestamp`
* `hostname`
* `kernel_version`
* `bootloader`
* `snapshot.created`, `snapshot.name`, `snapshot.id` (optional; `null` when Snapper does not expose a parsable snapshot ID)
* `updates.critical`, `updates.high`, `updates.medium`, `updates.low`
* `package_risk_metadata[]` objects with `name`, `severity`, `base_severity`, `reboot_required`, `boot_impact`, `graphics_impact`, `core_system_impact`, `userland_only`, `aur_package`, `advisory_match_count`, `escalated_by_advisory`, and `manual_intervention_required`
* `advisories[]` objects with `source`, `title`, `url`, `published_at`, `summary`, `category`, `severity`, `manual_intervention`, `related_packages`, `keywords`, and `matched_packages`
* `escalated_packages[]` objects with `name`, `target_severity`, `advisory_title`, and `manual_intervention`
* `risk_summary.critical_package_count`, `risk_summary.high_package_count`, `risk_summary.medium_package_count`, `risk_summary.low_package_count`
* `risk_summary.graphics_stack_changed`, `risk_summary.boot_chain_changed`, `risk_summary.core_system_changed`
* `risk_summary.reboot_required`, `risk_summary.aur_package_count`, `risk_summary.advisories_detected`, `risk_summary.manual_intervention_required`, `risk_summary.advisory_count`, `risk_summary.escalated_package_count`
* `reboot_required`, `manual_intervention_required`
* `update_result`
* `duration_seconds`
* `advisory_flags.arch_news_detected`, `advisory_flags.cachyos_news_detected`
* `log_file`, `report_path`
