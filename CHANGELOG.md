# Changelog

## v0.2.2

- Expanded the risk engine from simple string matching into multidimensional metadata for reboot, boot-chain, graphics-stack, core-system, and AUR-aware package impact
- Replaced reboot heuristics with metadata-driven reboot analysis and added graphics/boot advisory summaries to the operational log output
- Extended structured reports with per-package risk metadata objects and aggregate `risk_summary` fields for dashboards and future advisory correlation
- Preserved append-only report persistence while keeping same-second report filenames collision-safe

## v0.2.1

- Reworked structured report generation to use `jq` instead of manual JSON string assembly
- Added report validation before persistence and preserved append-only timestamped report history
- Expanded report metadata with version, hostname, kernel version, bootloader, snapshot state, duration, and risk-bucketed package arrays
- Standardized runtime artifact naming on sortable `YYYY-MM-DDTHHMMSS` timestamps
- Improved log consistency with timestamped log lines

## v0.2.0

- Refactored `safe-update` into sourceable Bash modules under `lib/`
- Added a repository-local spec runner and Bash specs for config, risk analysis, reporting, and the end-to-end update flow
- Added a runtime config template at `config/safe-update.conf`
- Added structured JSON reports under the safe-update runtime data directory
- Expanded risk and reboot detection coverage for CachyOS-oriented packages such as `linux-cachyos`, `limine`, and `pipewire`
- Added groundwork flags and report fields for future Arch/CachyOS advisory integration
