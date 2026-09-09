# ROBOPMO installer

One command sets up a ROBOPMO workspace on a Mac or Linux machine with nothing installed first:

```sh
curl -fsSL https://raw.githubusercontent.com/Doss-com/robopmo-install/main/install.sh | sh
```

It installs the GitHub CLI if missing, signs you in to GitHub (one-time code in the browser),
then fetches the real installer from the private `Doss-com/ROBOPMO` repository and hands off to
it. That step is also the access check: if you are not a member of the Doss-com GitHub
organization, it stops and says who to ask. The real installer then sets up everything else
(Node, direnv, the `doss` CLI, skills, your coding agents) and walks you through your first day.

Windows: see `ROBOPMO-src/bootstrap.ps1` in the private repository.

`install.sh` here is a copy of `ROBOPMO-src/install.sh` from `Doss-com/ROBOPMO`; only the
default channel line differs. The private repository is the source of truth. This file contains
no secrets and is safe for anyone to run: it does nothing beyond installing `gh` before the
access check.
