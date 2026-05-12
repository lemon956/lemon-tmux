#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG_FILE="$ROOT_DIR/.tmux.conf"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  pattern=$1
  description=$2

  if ! grep -Fq -- "$pattern" "$CONFIG_FILE"; then
    fail "$description"
  fi
}

assert_contains "PREFIX" "status bar should expose a PREFIX mode label"
assert_contains "COPY" "status bar should expose a COPY mode label"
assert_contains "ZOOM" "status bar should expose a ZOOM mode label"
assert_contains "SYNC" "status bar should expose a SYNC mode label"
assert_contains "#{client_prefix}" "PREFIX label should be driven by tmux client_prefix"
assert_contains "#{pane_in_mode}" "COPY label should be driven by tmux pane_in_mode"
assert_contains "#{window_zoomed_flag}" "ZOOM label should be driven by tmux window_zoomed_flag"
assert_contains "#{synchronize-panes}" "SYNC label should be driven by tmux synchronize-panes option"

assert_not_contains() {
  pattern=$1
  description=$2

  if grep -Fq -- "$pattern" "$CONFIG_FILE"; then
    fail "$description"
  fi
}

assert_not_contains "set-hook -g alert-activity" "status config should not register delayed activity notifications"
assert_not_contains "set-hook -g alert-bell" "status config should not register delayed bell notifications"
assert_not_contains "set-hook -g alert-silence" "status config should not register delayed silence notifications"
assert_not_contains "codex_notify.sh" "status config should not call the Codex notification script"

printf 'ok - status mode labels are configured without window notifications\n'
