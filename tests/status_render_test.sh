#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOCKET="/tmp/lemon-status-render-test-$$.sock"

cleanup() {
  tmux -S "$SOCKET" kill-server >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

tmux -S "$SOCKET" -f "$ROOT_DIR/.tmux.conf" new-session -d -s lemon_status_render
tmux -S "$SOCKET" copy-mode -t lemon_status_render:1.1

rendered=$(tmux -S "$SOCKET" display-message -p -t lemon_status_render:1.1 '#{E:status-format[0]}')

printf '%s\n' "$rendered" | grep -Fq " COPY " ||
  fail "expanded status-format should render a visible COPY label in copy mode"

printf '%s\n' "$rendered" | grep -Fq "#[bg=#805ad5,fg=#ffffff,bold]" ||
  fail "COPY label style should keep comma-separated tmux style attributes intact"

printf 'ok - status-format renders COPY mode label\n'
