---
name: update-readme-skill
description: Guides AI agents in maintaining and updating README.md as scripts, configurations, and dependencies evolve within the workstation-ops repository.
---

# Skill: Update README (`SKILL.md`)

This skill defines the strict procedure that you, the AI agent, must follow to ensure that the project's `README.md` accurately reflects the codebase at all times.

---

## 🔍 1. Trigger Conditions

You must trigger this skill immediately when:
* A new utility or script is added to the `scripts/` directory.
* An existing script is modified in a way that changes its functional behavior, command-line arguments, or options.
* A script's configuration defaults (like timestamps, log directories, or risk levels) are updated.
* A new external dependency (such as a system package or a command-line tool) is introduced.

---

## 🛠️ 2. Step-by-Step Procedure

### Step 2.1: Analyze the Code Changes
1. Identify all added, modified, or deleted scripts.
2. Scan the scripts for new configuration parameters or changed behaviors (e.g., new risk categories, changes to snapper/btrfs usage).
3. Check if any new tools are invoked (e.g., a shift from `paru` to another package manager, or the introduction of a new notification utility).

### Step 2.2: Identify Affected README Sections
Examine the current [README.md](file:///home/rogeliodelgado/Projects/workstation-ops/README.md) and identify which sections need updating:
* **Core Utilities**: If a new script is added, it needs its own section header (e.g., `## 🛠️ new-script-name`) detailing its features and workflow.
* **Prerequisites**: Update if there are new packages required by the updated or new scripts.
* **Usage Instructions**: Update if the setup, execution flags, or run commands have changed.
* **Directories & Paths**: Update if log locations, cache locations, or config files are added or restructured.

### Step 2.3: Modify the README File
1. Use targeted file-modification tools (such as `replace_file_content` or `multi_replace_file_content`) to apply exact updates.
2. Do not wipe out unrelated sections or rewrite the entire README unless requested.
3. Keep the premium aesthetic, consistent Markdown formatting, and emoji-enhanced lists.

### Step 2.4: Validate the Output
1. Check that all file links (e.g., `[safe-update](file:///home/rogeliodelgado/Projects/workstation-ops/scripts/safe-update)`) are correct and unbroken.
2. Ensure markdown formatting (headers, tables, bold text, code-blocks) renders correctly.
3. Run `git diff README.md` to verify changes are clean and precise.

---

## 📝 Example Markdown Additions

### Adding a new script block:
```markdown
## 🧹 clean-cache

`clean-cache` is a script that safely prunes pacman, paru, and systemd journal logs to recover disk space on Arch Linux workstations.

### Core Features
* Prunes AUR package caches keeping only the last two versions.
* Vacuum systemd journal logs older than 7 days.
```

### Adding a new prerequisite:
```markdown
* **pacman-contrib** (providing `paccache`) for cache-cleaning operations.
```
