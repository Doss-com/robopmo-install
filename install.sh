#!/bin/sh
# ROBOPMO public install stub — hosted as a byte-for-byte copy in the public repository
# Doss-com/robopmo-install (main), so the whole install is one command with nothing installed first:
#   curl -fsSL https://raw.githubusercontent.com/Doss-com/robopmo-install/main/install.sh | sh
# This file is the source; a change here is republished there by a maintainer (docs/RELEASING.md).
# The private-repo form still works when `gh` is already signed in, and skips this stub entirely:
#   gh api repos/Doss-com/ROBOPMO/contents/ROBOPMO-src/bootstrap.sh -H "Accept: application/vnd.github.raw" | sh
# bootstrap.sh remains the source of truth for everything after this. This stub does ONLY:
# refuse an unsupported OS, require curl, install gh if missing (byte-identical copy of
# bootstrap.sh's install_gh — tests/bootstrap/install-stub.test.ts asserts the two match so they
# can never drift), sign into GitHub if needed, then fetch bootstrap.sh from the private repo and
# exec it with every argument passed through, plus ROBOPMO_BOOTSTRAP_SELF (bootstrap.sh removes
# the mktemp'd copy at the end of main() once it no longer needs it).
# The private-repo fetch is itself the Doss-com membership gate: `gh api contents/...` 404s for
# anyone who isn't an active member. A 404 is ALSO what a bad --ref/branch produces, so its
# message covers both. With a tty, a 404 first checks the org membership state directly: a
# pending invitation opens https://github.com/orgs/Doss-com/invitation (also printed) and retries
# up to 3 times before failing; an already-active member (or no tty) falls straight to the
# not-yet-a-member-or-bad-ref message. --ref/ROBOPMO_BOOTSTRAP_REF picks the branch fetched
# (default main). No secrets, safe for anyone to run. Never printed: a token (redact matches
# bootstrap.sh's).
set -eu
REPO="Doss-com/ROBOPMO"
GITHUB_ORG="Doss-com"
say()  { printf 'bootstrap: %s\n' "$*"; }
fail() { code=$1; shift; printf 'bootstrap: error: %s\n' "$*" >&2; exit "$code"; }
have() { command -v "$1" >/dev/null 2>&1; }
redact() { sed -E 's/(gh[opsur]_|github_pat_)[A-Za-z0-9_]{8,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_.-]{10,}/[redacted]/g'; }
sha256_file() { if have shasum; then shasum -a 256 "$1"; else sha256sum "$1"; fi | cut -d ' ' -f 1; }

os=$(uname -s 2>/dev/null || printf unknown)
arch=$(uname -m 2>/dev/null || printf unknown)
case $os in
  Darwin|Linux) ;;
  *) fail 4 "unsupported OS '$os' — this script runs on macOS or Linux; on Windows see the README for bootstrap.ps1, or use WSL2 (Ubuntu)." ;;
esac
have curl || fail 2 "curl is required — install it (macOS: xcode-select --install; Linux: your package manager), then run this command again."
if ( : </dev/tty ) 2>/dev/null; then
  child_stdin=/dev/tty; tty=1
else
  child_stdin=/dev/null; tty=0
fi
open_url() {
  if have open; then
    open "$1" >/dev/null 2>&1 || true
  elif have xdg-open; then
    xdg-open "$1" >/dev/null 2>&1 || true
  fi
}

# --- gh: install if missing (kept byte-identical to install_gh in bootstrap.sh) ----------------
install_gh() {
  have gh && { say "gh: already present"; return 0; }
  [ "$tty" = 1 ] || return 1
  if have brew; then
    say "gh: installing (brew install gh)"
    brew install gh && return 0
    return 1
  fi
  case $os in Darwin) ghos=macOS ;; *) ghos=linux ;; esac
  case $arch in arm64|aarch64) gharch=arm64 ;; x86_64|amd64) gharch=amd64 ;; *) gharch=$arch ;; esac
  base=${ROBOPMO_BOOTSTRAP_GH_RELEASES:-https://github.com/cli/cli/releases}
  ver=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest </dev/null 2>/dev/null \
    | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n 1)
  [ -n "$ver" ] || { say "warning: could not resolve the latest gh release"; return 1; }
  ext=tar.gz
  [ "$ghos" = macOS ] && ext=zip
  asset="gh_${ver}_${ghos}_${gharch}.$ext"
  tmp=$(mktemp -d)
  if ! curl -fsSL "$base/download/v$ver/gh_${ver}_checksums.txt" -o "$tmp/sums.txt" </dev/null \
    || ! curl -fsSL "$base/download/v$ver/$asset" -o "$tmp/$asset" </dev/null; then
    rm -rf "$tmp"
    return 1
  fi
  expected=$(grep " $asset\$" "$tmp/sums.txt" | cut -d ' ' -f 1)
  actual=$(sha256_file "$tmp/$asset")
  [ -n "$expected" ] && [ "$actual" = "$expected" ] || {
    rm -rf "$tmp"
    say "warning: gh download sha256 mismatch — refusing to install"
    return 1
  }
  mkdir -p "$tmp/x"
  if [ "$ext" = zip ]; then
    have unzip || { rm -rf "$tmp"; return 1; }
    unzip -q "$tmp/$asset" -d "$tmp/x"
  else
    tar -xzf "$tmp/$asset" -C "$tmp/x"
  fi
  found=$(find "$tmp/x" -type f -name gh -perm -u+x | head -n 1)
  [ -n "$found" ] || found=$(find "$tmp/x" -type f -name gh | head -n 1)
  [ -n "$found" ] || { rm -rf "$tmp"; return 1; }
  mkdir -p "$HOME/.local/bin"
  cp "$found" "$HOME/.local/bin/gh"
  chmod 755 "$HOME/.local/bin/gh"
  rm -rf "$tmp"
  PATH="$HOME/.local/bin:$PATH"; export PATH
  say "gh: installed $ver to $HOME/.local/bin/gh (sha256 verified)"
}
install_gh || fail 3 "GitHub CLI (gh) is not installed — install it from https://cli.github.com, run: gh auth login   then run this command again."

# --- gh: signed in --------------------------------------------------------------------------
if ! gh auth status >/dev/null 2>&1 </dev/null; then
  if [ "$tty" = 1 ]; then
    # stdin from /dev/null on purpose: an interactive stdin makes gh use its survey prompts, which
    # break on terminals that answer cursor queries with extra escapes (Warp: "unexpected escape
    # sequence"); non-interactive, gh prints the one-time code and URL, opens the browser and polls.
    say "signing into GitHub — gh prints a one-time code and opens your browser; enter the code there"
    gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key --scopes read:org </dev/null >"$child_stdin" 2>&1 || true
  fi
  gh auth status >/dev/null 2>&1 </dev/null || fail 3 "GitHub CLI is not signed in — run: gh auth login   (GitHub.com, HTTPS, browser) then run this command again."
fi

# --- fetch the real bootstrap and hand off, passing every argument through unchanged ----------
# DEFAULT_REF is the channel this stub fetches bootstrap.sh from when the caller names none: the
# ONE line a hosted copy may change (a pilot copy points at the candidate branch). When it is not
# main and the caller gave no --ref, it is forwarded as `--ref` so bootstrap.sh clones and follows
# the same branch — otherwise bootstrap would fetch from one branch and clone another. An explicit
# --ref or ROBOPMO_BOOTSTRAP_REF wins and is never duplicated (bootstrap.sh reads both itself).
DEFAULT_REF=main
ref=${ROBOPMO_BOOTSTRAP_REF:-$DEFAULT_REF}
explicit=${ROBOPMO_BOOTSTRAP_REF:+1}
prev=""
for a in "$@"; do
  case $prev in --ref) ref=$a; explicit=1 ;; esac
  case $a in --ref=*) ref=${a#--ref=}; explicit=1 ;; esac
  prev=$a
done
if [ -z "$explicit" ] && [ "$ref" != main ]; then set -- --ref "$ref" "$@"; fi
# On success, leaves the fetched script's path in $script and returns 0. On failure, leaves gh's
# own error text in $fetch_err (for the caller to read the reason) and returns nonzero.
fetch_bootstrap() {
  script=$(mktemp)
  if fetch_err=$(gh api "repos/$REPO/contents/ROBOPMO-src/bootstrap.sh?ref=$ref" -H 'Accept: application/vnd.github.raw' \
    2>&1 >"$script" </dev/null); then
    return 0
  fi
  rm -f "$script"
  return 1
}
if ! fetch_bootstrap; then
  detail=$(printf '%s\n' "$fetch_err" | grep '[^[:space:]]' | tail -n 1 | redact)
  case $fetch_err in
    *"HTTP 404"*|*"Not Found"*)
      # A 404 here is also what a bad --ref produces, so the message below covers both. With a
      # tty, check the membership state directly first: a pending invitation gets up to 3 tries
      # at accepting it in the browser, retrying the fetch after each, before falling through to
      # the same not-yet-a-member-or-bad-ref failure.
      login=$(gh api user -q .login 2>/dev/null </dev/null || echo you)
      fetched=0
      if [ "$tty" = 1 ]; then
        state=$(gh api "orgs/$GITHUB_ORG/memberships/$login" -q .state 2>/dev/null </dev/null || true)
        tries=0
        while [ "$state" = pending ] && [ "$tries" -lt 3 ]; do
          tries=$((tries+1))
          say "opening your $GITHUB_ORG invitation (also printed below) — accept it, then press Enter here"
          say "https://github.com/orgs/$GITHUB_ORG/invitation"
          open_url "https://github.com/orgs/$GITHUB_ORG/invitation"
          read -r _ <"$child_stdin" || true
          state=$(gh api "orgs/$GITHUB_ORG/memberships/$login" -q .state 2>/dev/null </dev/null || true)
          if fetch_bootstrap; then fetched=1; break; fi
        done
      fi
      if [ "$fetched" != 1 ]; then
        fail 3 "GitHub user '$login' cannot read $REPO (gh: ${detail:-Not Found}) — you are not yet an active $GITHUB_ORG member, or the branch '$ref' does not exist — ask an admin to invite you in #robopmo, accept the invitation, then run this command again."
      fi ;;
    *) fail 3 "could not fetch bootstrap.sh from $REPO — gh said: ${detail:-no output} — check your network, then run this command again." ;;
  esac
fi
say "fetched bootstrap.sh (ref $ref) — handing off"
ROBOPMO_BOOTSTRAP_SELF=$script exec sh "$script" "$@"
