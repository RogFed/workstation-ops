# Agent Guidelines (`AGENTS.md`)

Welcome, AI Agent! This document outlines the constraints, rules, and best practices for developing and maintaining the `workstation-ops` repository. Please read this thoroughly before modifying any code.

---

## 🖥️ System Context & Environment

This repository contains critical system operations scripts for an **Arch Linux** workstation. 
* **Host OS**: Arch Linux (or derivatives).
* **Critical Utilities**: Uses `paru` (AUR helper), `snapper` (Btrfs snapshotting tool), and `notify-send` (desktop notifications).
* **Impact**: Scripts run with elevated privileges (`sudo`) and perform actions like package upgrades and filesystem snapshotting. **Extreme care must be taken to ensure system stability.**

---

## 🛠️ Development Principles

When modifying or adding scripts, you must adhere to the following principles:

1. **Safety First**:
   * Never write commands or scripts that perform destructive actions without confirmation or a recovery path.
   * Leverage filesystem snapshots (like Btrfs/Snapper) for any operation that can alter critical workstation states.

2. **Shell Script Best Practices**:
   * Always use `set -euo pipefail` in Bash scripts to catch errors early.
   * Avoid hardcoding user paths; use standard environment variables (e.g., `$HOME`, `$XDG_DATA_HOME`).
   * Double-quote variables to prevent word splitting and globbing.
   * If modifying scripts, run `shellcheck` (if available) or perform thorough syntax validation.

3. **Risk Analysis Hierarchy**:
   * If you introduce a script or tool that handles package updates or modifications, maintain or utilize the risk classification categories (**CRITICAL**, **HIGH**, **MEDIUM**, **LOW**).
   * Ensure user-facing warning prompts exist for actions classified as **CRITICAL**.

---

## 🔄 Documentation Synchronization

Documentation integrity is vital. Every time you:
* Add a new script to the `scripts/` directory.
* Add or modify configuration variables in existing scripts.
* Change system dependencies or add new software requirements.

You **must** update the project's documentation in sync with the codebase. To do this, refer to and follow the instructions in [SKILL.md](file:///home/rogeliodelgado/Projects/workstation-ops/.agent/skills/update-readme/SKILL.md).

---

## 🔑 Git Authentication & Operations

Before conducting any Git operations that interact with the remote repository (e.g., `git push`, `git pull`, `git fetch`), you **must** verify that your SSH credentials are authenticated. To do this, refer to and follow the instructions in [git-auth-skill](file:///home/rogeliodelgado/Projects/workstation-ops/.agent/skills/git-auth/SKILL.md).

After implementation is complete and the user explicitly approves the work:
1. Push the feature branch to the remote repository.
2. Open a pull request from the feature branch into `main`.
3. After each push to an open PR branch, review the Copilot PR feedback triggered by the synchronize event and apply fixes if needed.
4. Resolve Copilot-authored review threads after the fixes are pushed or the thread is outdated; leave user-authored comments for the original commenter to resolve.
5. Update the project version for the release.
6. Create the release tag for the new version.

---

## 🧪 Verification & Testing

Before declaring your task complete:
1. Verify the script's syntax (`bash -n scripts/<script-name>`).
2. Run dry-runs or simulated updates if possible.
3. Verify that any log directories required by the script are properly created.
4. Verify that formatting in `README.md` and other markdown files is flawless.
