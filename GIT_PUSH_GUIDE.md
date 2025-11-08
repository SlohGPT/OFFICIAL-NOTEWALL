## Git & GitHub Push Guide

This guide captures the exact steps and troubleshooting tips we used to push commits from this workspace to the `NoteWall` GitHub repository. It is meant to help future AI agents (or humans) successfully run the push without getting blocked by environment restrictions.

---

### 1. Prerequisites
- Git is already installed in the environment (Cursor workspaces include it by default).
- The repository remote points to GitHub (`origin` should target `https://github.com/SlohGPT/NOTEWALL_CLAUDE.git`).
- Any desired changes are already committed (`git status -sb` should show a clean tree or only staged changes).

Helpful sanity checks:
```bash
git status -sb
git remote -v
```

---

### 2. Standard Push Flow
Run these commands from the project root: `/Users/carly/Downloads/NOTEWALL-CLAUDECODE`.

```bash
cd /Users/carly/Downloads/NOTEWALL-CLAUDECODE
git status -sb          # confirm what will be pushed
git push                # push current branch (default: main) to origin
```

If the push succeeds, you will see output similar to:
```
To https://github.com/SlohGPT/NOTEWALL_CLAUDE.git
   <local_commit>.. <remote_commit>  main -> main
```

---

### 3. Granting Network Access in Cursor
The Cursor assistant runs commands in a sandbox that may block network access by default. If you see an error like:
```
fatal: unable to access 'https://github.com/...': Could not resolve host: github.com
```
re-run `git push` with explicit network permissions:
```json
required_permissions: ["network"]
```
If that still fails due to certificate lookup, escalate to:
```json
required_permissions: ["all"]
```
Only request the broader permission if the narrower one does not work.

---

### 4. Handling SSL Certificate Errors
In this environment we hit:
```
fatal: unable to access 'https://github.com/...': error setting certificate verify locations:  CAfile: /etc/ssl/cert.pem CApath: none
```

Steps to resolve:
1. Confirm the system certificates directory exists:
   ```bash
   ls /etc/ssl
   ls /etc/ssl/certs
   ```
2. Point Git to the correct certificate bundle and directory:
   ```bash
   git config http.sslCAinfo /etc/ssl/cert.pem
   git config http.sslCApath /etc/ssl/certs
   ```
3. Retry the push with the necessary permissions (see Section 3). If the error persists, use `required_permissions: ["all"]`.

Once the push succeeds, Git remembers the certificate configuration for future commands.

---

### 5. Verifying Success
After a successful push:
```bash
git status -sb
```
Should display:
```
## main...origin/main
```
with no `ahead` indicator. Optionally confirm on GitHub that the commit appears on `main`.

---

### 6. Recovering from Failures
- **Network/DNS errors**: rerun with `["network"]` or `["all"]` permissions.
- **Authentication issues**: ensure the GitHub connection for Cursor is authorized under the user account.
- **SSL errors**: apply the certificate configuration from Section 4.
- **Other errors**: copy the full error message into the conversation so the agent can investigate further.

---

### 7. Quick Reference Script
For future agents, this command sequence maps to what worked:
```bash
cd /Users/carly/Downloads/NOTEWALL-CLAUDECODE
git status -sb
git push  # retry with ["network"] first, then ["all"] if SSL errors appear
```

If SSL errors appear, run:
```bash
git config http.sslCAinfo /etc/ssl/cert.pem
git config http.sslCApath /etc/ssl/certs
```
and retry the push.

---

Document updated: November 8, 2025.

