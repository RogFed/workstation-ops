# Copilot Instructions

## Build, test, and lint commands

This repository is a Bash-script repository; there is no separate build step.

- Run the main workflow: `./scripts/safe-update`
- Run the full spec suite: `./tests/run`
- Run a single spec file: `./tests/run tests/unit/risk_spec.sh`
- Validate a single script's syntax: `bash -n scripts/safe-update`
- Lint a single script when `shellcheck` is installed: `shellcheck scripts/safe-update`

## High-level architecture

The repository centers on `scripts/safe-update`, which orchestrates the update flow by sourcing focused modules under `lib/`.

The runtime flow is:

1. Load runtime config from `config/safe-update.conf` plus environment overrides.
2. Derive runtime paths under `~/.local/share/safe-update/{logs,reports,cache,state}`.
3. Detect pending package updates with `paru -Qu`.
4. Classify each pending package as `CRITICAL`, `HIGH`, `MEDIUM`, or `LOW`.
5. If any `CRITICAL` package is present, emit a terminal warning and a `notify-send` desktop notification before asking for explicit confirmation.
6. After confirmation, create a pre-update Btrfs snapshot with `sudo snapper create --description "pre-update-YYYY-MM-DD-HHMM"`.
7. Run the actual upgrade with `paru -Syu`.
8. Emit both a timestamped logfile and a structured JSON report for the run.
9. Recommend a reboot when updated packages match reboot-sensitive patterns.

The module split is part of the repository design:

- `lib/config.sh` loads defaults and runtime config
- `lib/logging.sh` owns mirrored console/log output
- `lib/risk.sh` owns risk classification and reboot detection
- `lib/snapshots.sh` wraps Snapper snapshot creation
- `lib/notifications.sh` gates desktop notifications
- `lib/reports.sh` writes structured JSON reports
- `lib/utils.sh` provides shared helpers

`README.md` is the main user-facing documentation for prerequisites, usage, config, verification, and runtime directories.

## Key conventions

- Keep shell scripts strict: use `set -euo pipefail`.
- `scripts/safe-update` should stay a thin orchestration entrypoint; reusable logic belongs in `lib/*.sh`.
- Runtime-generated data belongs outside the repo under the safe-update data directory; repository files should remain source, config templates, tests, and docs.
- Preserve the existing logging pattern: user-facing milestones go through `log()` / `section()` so they are mirrored to the timestamped logfile.
- Preserve the safety model: analyze update risk first, warn on `CRITICAL` actions, and keep a recovery path via snapshots before destructive system changes.
- The package risk taxonomy is part of the repo's behavior contract: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`.
- JSON reports are a stable integration surface; when behavior changes, keep report fields aligned with the workflow state.
- When adding behavior, update or add specs first and keep `./tests/run` green through the refactor.
- If you change script behavior, configuration defaults, dependencies, or add scripts under `scripts/`, update `README.md` in the same change.
- Before remote Git operations such as `git push`, `git pull`, or `git fetch`, verify SSH agent identities with `ssh-add -l`; this repository's agent guidance requires SSH auth verification first.

## Release workflow

- Implement changes on a feature branch, not on `main`.
- After implementation is complete and the user explicitly approves the work, push the feature branch to the remote repository.
- Open a pull request from the feature branch into `main`.
- Update the repository version for the release as part of the approved changes.
- Create the release tag for the new version after the change set is ready.
