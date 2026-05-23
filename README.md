# Workstation Operations (`workstation-ops`)

A collection of system administration scripts and utilities designed to keep an Arch Linux workstation clean, updated, and resilient.

---

## 🛠️ safe-update

`safe-update` is a Bash-based update orchestrator for Arch Linux and CachyOS systems using **Btrfs** and **Snapper**. It keeps the original rollback-first workflow while adding a modular architecture, runtime configuration, and structured reporting.

### Core Features

1. **Modular update workflow**  
   `scripts/safe-update` is the orchestration entrypoint and sources focused modules from `lib/` for config, logging, notifications, snapshots, risk analysis, utilities, and report generation.
2. **Risk-aware package classification**  
   Pending updates are grouped into `CRITICAL`, `HIGH`, `MEDIUM`, and `LOW` buckets before any changes are made.
3. **Rollback-first safety**  
   A pre-update Btrfs snapshot is created with `snapper` before upgrades run.
4. **Human confirmation gates**  
   Critical updates still require explicit confirmation before the script proceeds.
5. **Structured observability**  
   Each run produces both a human-readable log and a JSON report for future automation, dashboards, or advisory correlation.
6. **Advisory groundwork**  
   Runtime flags and report fields are in place for future Arch Linux and CachyOS news/advisory integration without introducing opaque autonomous decisions.

---

## 📋 Prerequisites

To use `safe-update`, your system must have:

* **Arch Linux** or a compatible derivative such as **CachyOS**
* **Paru** installed as the AUR helper (for `paru -Qu` and `paru -Syu`)
* **Btrfs** with **Snapper** configured
* **libnotify** (providing `notify-send`) for desktop alerts

---

## 🗂️ Repository Layout

```text
workstation-ops/
├── config/
│   └── safe-update.conf
├── lib/
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

* **Logs**: `~/.local/share/safe-update/logs/update-YYYY-MM-DD-HHMM.log`
* **Reports**: `~/.local/share/safe-update/reports/report-YYYY-MM-DD-HHMM.json`
* **Snapshots**: `pre-update-YYYY-MM-DD-HHMM`
