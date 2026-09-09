# ROBOPMO installer

One command sets up a ROBOPMO workspace on a Mac (or Linux) with nothing installed first:

```sh
curl -fsSL https://raw.githubusercontent.com/Doss-com/robopmo-install/main/install.sh | sh
```

It installs the GitHub CLI if missing, signs you in to GitHub, then fetches the real installer
from the private `Doss-com/ROBOPMO` repository and hands off to it. That fetch is also the access
check: if you are not a member of the Doss-com GitHub organization, it stops and says who to ask.
Your existing ROBOPMO workspace, if you have one, is not touched; the new one goes to
`~/Documents/ROBOPMO-Workspace` (set `ROBOPMO_WORKSPACE_DIR` for another folder).

## What it asks you, in order

1. **Xcode command line tools**, only if git is missing: a macOS dialog opens. Click Install, wait, press Enter.
2. **GitHub sign-in**: a one-time code and github.com in your browser. Use your Doss-com member account. A pending invitation opens the invitation page; accept it and press Enter.
3. **Coding agents**: `install Claude Code? [Y/n]`, then Codex, then OpenCode. Enter for yes.
4. **DOSS sign-in**: admin.doss.com opens. Sign in with your own DOSS account.
5. **Customer orgs**: pick by number, up to three to start.
6. **Doss agent gateway**: Google sign-in with your @doss.com account (connects OpenCode to the managed models and telemetry). Skipped if OpenCode is not installed.
7. **DOSS platform source**: `[y/N]`. Say no unless you need to read platform code.
8. **Terminal default folder**: `Open new terminal windows in Customer-Installs? [Y/n]`. Set for you in Warp and iTerm2 (after quitting the app); other terminals get a one-line instruction.

You end up inside `Customer-Installs` in a new shell with `robopmo`, `doss`, `claude`, `codex` and
`opencode` on PATH. Later terminals activate on their own when you `cd` into the workspace.

## What you will see

| Line | Meaning |
|---|---|
| `gh: installed 2.x … (sha256 verified)` | GitHub CLI downloaded and verified, ~5 s |
| `GitHub: signed in as … active Doss-com member` | access confirmed |
| `workspace: cloned into …` | the private clone, under a minute |
| `Node: installed v24 … (sha256 verified)` | a workspace-local Node, only if yours is older |
| `agents: installing …` | the coding agents; a vendor download can be slow on a bad day |
| `running robopmo up` | installs the doss CLI and the skills, about a minute |
| `Step 1/8 — Sign in to DOSS admin` | onboarding started |

Measured at 73 to 160 seconds before onboarding on a Mac with nothing preinstalled. If it stops, read
the last `bootstrap: error:` line, fix what it names, and paste the same command again; it resumes.

## Check

```sh
robopmo doctor          # "nothing to do"
robopmo skills status   # three sources ready
robopmo auth status     # DOSS admin signed in; gateway signed in
robopmo list-orgs | head
```

## Rollback

Inside the workspace run `robopmo updates disable`, then delete the folder. Optionally remove the
block between the `# >>> ROBOPMO direnv hook >>>` markers in `~/.zshrc`, and reset your terminal's
default folder in its settings.

## About this repository

`install.sh` here is a copy of `ROBOPMO-src/install.sh` from `Doss-com/ROBOPMO`; only the
`DEFAULT_REF` line differs (it names the channel the installer follows). The private repository is
the source of truth. This file contains no secrets and is safe for anyone to run: it does nothing
beyond installing `gh` before the access check. Windows: see `ROBOPMO-src/bootstrap.ps1` in the
private repository.
