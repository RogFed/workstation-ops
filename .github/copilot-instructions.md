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
6. After confirmation, create a pre-update Btrfs snapshot with `sudo snapper create --description "pre-update-YYYY-MM-DDTHHMMSS"`.
7. Run the actual upgrade with `paru -Syu`.
8. Emit both a timestamped logfile and a validated structured JSON report for the run.
9. Recommend a reboot when updated packages match reboot-sensitive patterns.

The module split is part of the repository design:

- `lib/config.sh` loads defaults and runtime config
- `lib/logging.sh` owns mirrored console/log output
- `lib/risk.sh` owns risk classification and reboot detection
- `lib/snapshots.sh` wraps Snapper snapshot creation
- `lib/notifications.sh` gates desktop notifications
- `lib/reports.sh` generates and validates structured JSON reports with `jq`
- `lib/utils.sh` provides shared helpers

`README.md` is the main user-facing documentation for prerequisites, usage, config, verification, and runtime directories.

## Key conventions

- Keep shell scripts strict: use `set -euo pipefail`.
- `scripts/safe-update` should stay a thin orchestration entrypoint; reusable logic belongs in `lib/*.sh`.
- Runtime-generated data belongs outside the repo under the safe-update data directory; repository files should remain source, config templates, tests, and docs.
- Preserve the existing logging pattern: user-facing milestones go through `log()` / `section()` so they are mirrored to the timestamped logfile.
- Preserve the safety model: analyze update risk first, warn on `CRITICAL` actions, and keep a recovery path via snapshots before destructive system changes.
- The package risk taxonomy is part of the repo's behavior contract: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`.
- JSON reports are a stable integration surface; generate them with `jq`, validate them before persistence, and keep report fields aligned with the workflow state.
- Default runtime artifact names should use sortable `YYYY-MM-DDTHHMMSS` timestamps.
- When adding behavior, update or add specs first and keep `./tests/run` green through the refactor.
- If you change script behavior, configuration defaults, dependencies, or add scripts under `scripts/`, update `README.md` in the same change.
- Before remote Git operations such as `git push`, `git pull`, or `git fetch`, verify SSH agent identities with `ssh-add -l`; this repository's agent guidance requires SSH auth verification first.

## Release workflow

- Before starting a new feature branch, switch to `main` and update it to the latest remote state.
- Base every feature branch on the latest `main`; do not branch from another feature branch unless the user explicitly asks for stacked work.
- Implement changes on a feature branch, not on `main`.
- After implementation is complete and the user explicitly approves the work, push the feature branch to the remote repository.
- Open a pull request from the feature branch into `main`.
- Once the branch is pushed to an open PR, treat the PR synchronize event as the trigger for GitHub Copilot review and then read the resulting review comments.
- Apply any required fixes from Copilot review feedback, rerun the relevant checks, and push follow-up commits until the review feedback is resolved.
- Resolve Copilot-authored review threads after the fix is pushed or the comment is outdated; do not resolve user-authored comments on their behalf.
- After a feature branch is merged, return to `main`, update it to the latest remote state, and start the next feature branch from that refreshed `main`.
- Update the repository version for the release as part of the approved changes.
- Create the release tag for the new version after the change set is ready.
