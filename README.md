# Workstation Operations (`workstation-ops`)

A collection of system administration scripts and utilities designed to keep an Arch Linux workstation clean, updated, and resilient. 

---

## 🛠️ safe-update

`safe-update` is a robust Bash script designed for Arch Linux systems utilizing **Btrfs** and **Snapper**. It automates system updates while mitigating the risks of system instability by analyzing package risk levels and creating system recovery snapshots before any changes are made.

### Core Features

1. **Intelligent Risk Analysis**: 
   Inspects pending updates and classifies package updates into risk categories based on core system components:
   * 🔴 **CRITICAL**: Core system, drivers, or standard libraries (`linux`, `nvidia`, `glibc`).
   * 🟠 **HIGH**: Vital system services or display drivers (`mesa`, `systemd`).
   * 🟡 **MEDIUM**: Desktop environment packages (`plasma`).
   * 🟢 **LOW**: User-space utilities and application software.

2. **Automated Btrfs Rollback Snapshots**: 
   Before executing upgrades, the script triggers `snapper` to take a pre-update snapshot of the system (`pre-update-YYYY-MM-DD-HHMM`). If an update breaks the environment, the workstation can easily be rolled back.

3. **User Safety Check**: 
   Displays a detailed list of pending updates and their risk levels. If critical updates are found, it triggers a warning and desktop notification, prompting the user for explicit confirmation (`[y/N]`) before proceeding.

4. **Reboot Detection**: 
   After upgrades complete, the script checks if critical components (kernel, systemd, graphics drivers) were updated. If so, it recommends a reboot and sends a system-wide desktop notification.

5. **Consolidated Logging**:
   Every run is logged with structured output inside the user's home directory.

---

## 📋 Prerequisites

To use `safe-update`, your system must have:
* **Arch Linux** (or derivative distribution).
* **Paru** installed as the AUR helper (for `paru -Qu` and `paru -Syu`).
* **Btrfs** file system with **Snapper** configured.
* **libnotify** (providing `notify-send`) for desktop alerts.

---

## 🚀 Installation & Usage

### 1. Clone the Repository
```bash
git clone https://github.com/RogFed/workstation-ops.git
cd workstation-ops
```

### 2. Make the Script Executable
```bash
chmod +x scripts/safe-update
```

### 3. Run the Update
```bash
./scripts/safe-update
```

---

## 🗂️ Directories & Paths

* **Logs**: Script logs are stored under:
  ```
  ~/.local/share/safe-update/logs/update-YYYY-MM-DD-HHMM.log
  ```
* **Btrfs Snapshots**: Created using `snapper` configurations under the naming scheme `pre-update-YYYY-MM-DD-HHMM`.
