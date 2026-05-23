---
name: git-auth-skill
description: Guides AI agents in verifying SSH identities in the active ssh-agent and prompting the user to load their private keys before conducting remote Git operations.
---

# Skill: Git Authentication (`SKILL.md`)

This skill defines the mandatory verification and authentication procedure that you, the AI agent, must perform before executing any remote Git operations (e.g., `git push`, `git pull`, `git fetch`, or pushing tags).

---

## 🔍 1. Trigger Conditions

You must trigger this skill:
* Immediately before attempting any Git command that interacts with the remote repository `origin`.
* If a remote Git operation fails with an SSH-related error (e.g., `Permission denied (publickey)`, `ssh_askpass`, etc.).

---

## 🛠️ 2. Step-by-Step Procedure

### Step 2.1: Check Current SSH Identities
Run the following command to check if any private keys are currently decrypted and loaded into the active SSH agent session:
```bash
ssh-add -l
```

* **Case A: Identities are listed**: The keys are unlocked and loaded. You may proceed immediately with the Git operation.
* **Case B: "The agent has no identities" or error**: No keys are loaded. Proceed to **Step 2.2**.

### Step 2.2: Attempt Automated Loading
Try to dynamically locate the configured private key to load it:

1. Determine the hostname from the Git remote URL:
   ```bash
   git remote get-url origin
   ```
   *Example: if the URL is `git@cachyos-github:user/repo.git`, the host is `cachyos-github`.*

2. Scan the user's SSH configuration file (`~/.ssh/config`) for a matching `Host` block to retrieve the configured `IdentityFile` path.

3. Attempt to load the detected key (or the default key if none is specified) in a non-interactive way:
   ```bash
   ssh-add <path-to-identity-file> < /dev/null
   ```

* **Case A: Success**: The key had no passphrase (or was already unlocked). You may now proceed with the Git operation.
* **Case B: Fails with `ssh_askpass` or passphrase prompt**: The key is encrypted and requires a passphrase. Proceed to **Step 2.3**.

### Step 2.3: Prompt the User for Interactive Unlock
Because the key is passphrase-protected and you are running in a non-interactive background agent shell, you cannot safely prompt for the passphrase yourself.

1. **Stop execution** of the Git command.
2. **Respond to the user** explaining that the Git operation requires their private key to be loaded.
3. **Instruct the user** to run `ssh-add` in their local interactive terminal. If a custom key was located in Step 2.2, specify the command with its path:
   ```bash
   ssh-add <path-to-identity-file>
   ```
   Otherwise, if no custom key is configured, recommend running the default:
   ```bash
   ssh-add
   ```
4. **Pause and ask for confirmation** once they have successfully run the command and entered their passphrase.
5. **Verify and proceed**: Once the user confirms, run `ssh-add -l` again to verify, then perform the Git operation.

