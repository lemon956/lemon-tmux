# Kitty Keybinding Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a one-shot `Ctrl+Q` Kitty keyboard mode that preserves the approved tmux muscle memory, enables safe Kitty session workflows, and leaves all Kitty default shortcuts intact.

**Architecture:** Stage a complete candidate from the live Kitty configuration, append one clearly marked mapping block, and validate it with Kitty 0.47.4 before copying it into place. Keep mutable session files under Kitty's user data directory, reload the running Kitty process only after static validation passes, and retain a timestamped byte-for-byte backup for rollback.

**Tech Stack:** Kitty 0.47.4 `kitty.conf`, Kitty's Python config loader via `kitty +runpy`, POSIX shell utilities, `apply_patch`

## Global Constraints

- Preserve every built-in Kitty `Ctrl+Shift` shortcut; do not set `clear_all_shortcuts yes` or change `kitty_mod`.
- Use `Ctrl+Q` only as a two-second, one-action keyboard mode named `tmux`.
- Keep the approved 41 mode bindings exactly; use `shift+,` and `shift+.` for the `<` and `>` keys because raw `>` is Kitty's multi-key separator.
- Make `splits` the default while retaining `stack,tall,fat,grid,horizontal,vertical`.
- Do not add scripts, kittens, plugins, or third-party dependencies.
- Do not enable `--use-foreground-process` for session saving.
- Do not modify theme, font, window, scrollback, or tab-bar settings.
- Do not automate close-window, close-tab, or session-save actions during verification.
- Use `apply_patch` for content edits; deploy only a candidate that has already passed Kitty's parser.
- Reference design: `docs/superpowers/specs/2026-07-15-kitty-keybinding-migration-design.md`.

## File Structure

- Modify: `/home/lemon/.config/kitty/kitty.conf` — append the approved layout and `tmux` keyboard-mode block.
- Create: `/home/lemon/.config/kitty/kitty.conf.pre-tmux-migration-YYYYMMDD-HHMMSS` — byte-for-byte rollback copy whose suffix is generated from the execution time.
- Create directory: `/home/lemon/.local/share/kitty/sessions/` — mutable `.kitty-session` storage, mode `0700`.
- Create temporarily: `/tmp/kitty-keymap-migration/kitty.conf` — candidate config edited and parsed before deployment.
- Create temporarily: `/tmp/kitty-keymap-migration/current-theme.conf` — resolves the candidate's existing relative theme include.
- Create temporarily: `/tmp/kitty-keymap-migration/source.sha256` — detects concurrent changes before deployment.

---

### Task 1: Create the rollback baseline

**Deliverable:** A timestamped backup that is byte-identical to the live pre-change `kitty.conf`.

**Files:**

- Read: `/home/lemon/.config/kitty/kitty.conf`
- Create: `/home/lemon/.config/kitty/kitty.conf.pre-tmux-migration-YYYYMMDD-HHMMSS`
- Create: `/tmp/kitty-keymap-migration/source.sha256`

**Interfaces:**

- Consumes: the currently active Kitty config at `/home/lemon/.config/kitty/kitty.conf`.
- Produces: one timestamped backup path and a SHA-256 baseline used as Task 4's concurrent-change gate.

- [ ] **Step 1: Verify the live config has no existing migration block**

Run:

```bash
rg -n "BEGIN KITTY TMUX MIGRATION|--new-mode tmux" /home/lemon/.config/kitty/kitty.conf
```

Expected: exit status `1` with no output. If either marker already exists, stop and reconcile it instead of appending a duplicate block.

- [ ] **Step 2: Verify the baseline parses before changing anything**

Run:

```bash
kitty +runpy 'from kitty.config import load_config; bad=[]; load_config("/home/lemon/.config/kitty/kitty.conf", accumulate_bad_lines=bad); print(f"bad_lines={len(bad)}"); [print(x) for x in bad]; raise SystemExit(1 if bad else 0)'
```

Expected:

```text
bad_lines=0
```

- [ ] **Step 3: Create staging metadata and the timestamped backup**

Run these commands in order:

```bash
mkdir -p /tmp/kitty-keymap-migration
sha256sum /home/lemon/.config/kitty/kitty.conf > /tmp/kitty-keymap-migration/source.sha256
cp --preserve=mode,timestamps /home/lemon/.config/kitty/kitty.conf "/home/lemon/.config/kitty/kitty.conf.pre-tmux-migration-$(date +%Y%m%d-%H%M%S)"
```

Expected: all commands exit `0`.

- [ ] **Step 4: Verify the newest backup is byte-identical**

Run:

```bash
/usr/bin/bash -lc 'backup=$(rg --files -g "kitty.conf.pre-tmux-migration-*" /home/lemon/.config/kitty | sort | tail -1); cmp -s /home/lemon/.config/kitty/kitty.conf "$backup" && printf "backup=%s\n" "$backup"'
```

Expected: exit `0` and one backup path whose filename ends with a 15-character `YYYYMMDD-HHMMSS` date-time suffix.

No repository commit: this task creates only external safety artifacts.

---

### Task 2: Create private Session storage

**Deliverable:** `/home/lemon/.local/share/kitty/sessions/` exists with mode `0700`.

**Files:**

- Create directory: `/home/lemon/.local/share/kitty/sessions/`

**Interfaces:**

- Consumes: no earlier task output.
- Produces: the exact directory used by all `goto_session` and `save_as_session` mappings in Task 3.

- [ ] **Step 1: Confirm no existing Kitty session location needs preservation**

Run:

```bash
rg -n "startup_session|goto_session|save_as_session" /home/lemon/.config/kitty/kitty.conf
rg --files -g '*.kitty-session' -g '*.kitty_session' -g '*.session' /home/lemon/.config/kitty /home/lemon/.local/share/kitty
```

Expected: only the commented `startup_session none` sample line may appear; the second command may exit `2` before the new data directory exists. If active session mappings or files appear, stop and preserve their directory rather than introducing a parallel one.

- [ ] **Step 2: Create the standard session directory**

Run:

```bash
install -d -m 0700 /home/lemon/.local/share/kitty/sessions
```

Expected: exit `0`.

- [ ] **Step 3: Verify ownership and permissions**

Run:

```bash
stat -c '%a %U %G %n' /home/lemon/.local/share/kitty/sessions
```

Expected:

```text
700 lemon lemon /home/lemon/.local/share/kitty/sessions
```

No repository commit: this task creates runtime data storage only.

---

### Task 3: Build and validate the complete candidate config

**Deliverable:** `/tmp/kitty-keymap-migration/kitty.conf` contains the approved block and passes all parser assertions.

**Files:**

- Create: `/tmp/kitty-keymap-migration/kitty.conf`
- Create: `/tmp/kitty-keymap-migration/current-theme.conf`
- Read: `/home/lemon/.config/kitty/kitty.conf`
- Read: `/home/lemon/.config/kitty/current-theme.conf`

**Interfaces:**

- Consumes: the unchanged live config from Task 1 and the session directory path from Task 2.
- Produces: a fully parsed candidate with seven layouts, a two-second `tmux` mode, and exactly 41 bindings for Task 4 to deploy.

- [ ] **Step 1: Copy the live config and its relative include into staging**

Run:

```bash
cp --preserve=mode,timestamps /home/lemon/.config/kitty/kitty.conf /tmp/kitty-keymap-migration/kitty.conf
cp --preserve=mode,timestamps /home/lemon/.config/kitty/current-theme.conf /tmp/kitty-keymap-migration/current-theme.conf
```

Expected: both commands exit `0`.

- [ ] **Step 2: Run the pre-change assertion and verify it fails**

Run:

```bash
kitty +runpy 'from kitty.config import load_config; o=load_config("/tmp/kitty-keymap-migration/kitty.conf"); assert "tmux" in o.keyboard_modes, "tmux mode missing"'
```

Expected: non-zero exit with `AssertionError: tmux mode missing`.

- [ ] **Step 3: Append the complete mapping block with `apply_patch`**

Apply this exact patch to `/tmp/kitty-keymap-migration/kitty.conf`:

```patch
*** Begin Patch
*** Update File: /tmp/kitty-keymap-migration/kitty.conf
@@
 active_tab_font_style bold
 inactive_tab_font_style normal
+
+# ==================================================
+# BEGIN KITTY TMUX MIGRATION
+# Ctrl+Q opens a one-shot tmux-compatible key mode.
+# ==================================================
+
+enabled_layouts splits,stack,tall,fat,grid,horizontal,vertical
+
+map --new-mode tmux --on-action end --on-unknown end --timeout 2.0 ctrl+q
+
+# Exit or pass the original Ctrl+Q through to the foreground program.
+map --mode tmux escape pop_keyboard_mode
+map --mode tmux ctrl+q send_key ctrl+q
+
+# Sessions
+map --mode tmux s goto_session ~/.local/share/kitty/sessions
+map --mode tmux shift+s save_as_session --save-only --match=state:focused_os_window --base-dir ~/.local/share/kitty/sessions
+map --mode tmux ctrl+s save_as_session --save-only --match=session:. .
+
+# Tabs (tmux windows)
+map --mode tmux c new_tab_with_cwd
+map --mode tmux n next_tab
+map --mode tmux p previous_tab
+map --mode tmux 1 goto_tab 1
+map --mode tmux 2 goto_tab 2
+map --mode tmux 3 goto_tab 3
+map --mode tmux 4 goto_tab 4
+map --mode tmux 5 goto_tab 5
+map --mode tmux 6 goto_tab 6
+map --mode tmux 7 goto_tab 7
+map --mode tmux 8 goto_tab 8
+map --mode tmux 9 goto_tab 9
+map --mode tmux w select_tab
+map --mode tmux , set_tab_title
+map --mode tmux shift+, move_tab_backward
+map --mode tmux shift+. move_tab_forward
+map --mode tmux & close_tab
+
+# Kitty windows (tmux panes)
+map --mode tmux h launch --cwd=current --add-to-session . --location=vsplit
+map --mode tmux v launch --cwd=current --add-to-session . --location=hsplit
+map --mode tmux left neighboring_window left
+map --mode tmux right neighboring_window right
+map --mode tmux up neighboring_window up
+map --mode tmux down neighboring_window down
+map --mode tmux alt+left resize_window narrower 5
+map --mode tmux alt+right resize_window wider 5
+map --mode tmux alt+up resize_window taller 5
+map --mode tmux alt+down resize_window shorter 5
+map --mode tmux q focus_visible_window
+map --mode tmux x close_window_with_confirmation
+map --mode tmux z toggle_layout stack
+map --mode tmux ! detach_window new-tab
+map --mode tmux space next_layout
+
+# Kitty utilities
+map --mode tmux r load_config_file
+map --mode tmux l clear_terminal to_cursor_scroll active
+map --mode tmux ? command_palette
+map --mode tmux : kitty_shell window
+
+# END KITTY TMUX MIGRATION
*** End Patch
```

Expected: `apply_patch` reports success and changes only the staged candidate.

- [ ] **Step 4: Parse every mapping action and assert the approved shape**

Run:

```bash
kitty +runpy 'from kitty.config import load_config; bad=[]; o=load_config("/tmp/kitty-keymap-migration/kitty.conf", accumulate_bad_lines=bad); assert not bad, bad; assert o.enabled_layouts == ["splits", "stack", "tall", "fat", "grid", "horizontal", "vertical"], o.enabled_layouts; assert o.clear_all_shortcuts is False; assert o.kitty_mod == 5, o.kitty_mod; assert "tmux" in o.keyboard_modes; m=o.keyboard_modes["tmux"]; assert len(m.keymap) == 41, len(m.keymap); assert m.timeout == 2.0; assert m.on_action == "end"; assert m.on_unknown == "end"; [o.alias_map.resolve_aliases(kd.definition) for defs in m.keymap.values() for kd in defs]; print("bad_lines=0 bindings=41 defaults_preserved=yes mode=tmux timeout=2.0")'
```

Expected:

```text
bad_lines=0 bindings=41 defaults_preserved=yes mode=tmux timeout=2.0
```

- [ ] **Step 5: Review the candidate-only diff**

Run:

```bash
diff --unified=3 /home/lemon/.config/kitty/kitty.conf /tmp/kitty-keymap-migration/kitty.conf
```

Expected: exit `1` because a diff exists; the only additions are the marked migration block shown in Step 3.

No repository commit: the candidate is a temporary deployment artifact.

---

### Task 4: Deploy the validated candidate atomically

**Deliverable:** `/home/lemon/.config/kitty/kitty.conf` is byte-identical to the validated candidate.

**Files:**

- Modify: `/home/lemon/.config/kitty/kitty.conf`
- Read: `/tmp/kitty-keymap-migration/kitty.conf`
- Read: `/tmp/kitty-keymap-migration/source.sha256`

**Interfaces:**

- Consumes: Task 1's SHA-256 baseline and Task 3's parser-clean candidate.
- Produces: the live Kitty configuration consumed by Task 5.

- [ ] **Step 1: Reject concurrent edits to the live config**

Run:

```bash
sha256sum -c /tmp/kitty-keymap-migration/source.sha256
```

Expected:

```text
/home/lemon/.config/kitty/kitty.conf: OK
```

If this fails, stop, rebuild the candidate from the new live file, and do not overwrite the user's changes.

- [ ] **Step 2: Copy the already validated candidate into place**

Run:

```bash
cp --preserve=mode /tmp/kitty-keymap-migration/kitty.conf /home/lemon/.config/kitty/kitty.conf
```

Expected: exit `0`.

- [ ] **Step 3: Verify the deployed file is byte-identical to the candidate**

Run:

```bash
cmp -s /tmp/kitty-keymap-migration/kitty.conf /home/lemon/.config/kitty/kitty.conf
```

Expected: exit `0` with no output.

- [ ] **Step 4: Verify exactly one marked block is deployed**

Run:

```bash
rg -n "BEGIN KITTY TMUX MIGRATION|END KITTY TMUX MIGRATION|--new-mode tmux" /home/lemon/.config/kitty/kitty.conf
```

Expected: exactly three lines: one begin marker, one mode definition, and one end marker.

No repository commit: the live Kitty config is outside this repository.

---

### Task 5: Reload and verify the live configuration

**Deliverable:** The running Kitty process has been signaled to reload a parser-clean live config, with a documented manual smoke checklist.

**Files:**

- Read: `/home/lemon/.config/kitty/kitty.conf`
- Read: `/home/lemon/.config/kitty/kitty.conf.pre-tmux-migration-YYYYMMDD-HHMMSS` for rollback only

**Interfaces:**

- Consumes: Task 4's deployed live config.
- Produces: final parser evidence, reload evidence, rollback command, and user-run behavioral checks.

- [ ] **Step 1: Re-run the full parser assertions against the live file**

Run:

```bash
kitty +runpy 'from kitty.config import load_config; bad=[]; o=load_config("/home/lemon/.config/kitty/kitty.conf", accumulate_bad_lines=bad); assert not bad, bad; assert o.enabled_layouts == ["splits", "stack", "tall", "fat", "grid", "horizontal", "vertical"]; assert o.clear_all_shortcuts is False; assert o.kitty_mod == 5; m=o.keyboard_modes["tmux"]; assert len(m.keymap) == 41; assert (m.timeout, m.on_action, m.on_unknown) == (2.0, "end", "end"); [o.alias_map.resolve_aliases(kd.definition) for defs in m.keymap.values() for kd in defs]; print("live_config=valid bindings=41 defaults_preserved=yes")'
```

Expected:

```text
live_config=valid bindings=41 defaults_preserved=yes
```

- [ ] **Step 2: Signal the running Kitty process to reload**

Run:

```bash
pgrep -a -x kitty
kill -USR1 "$(pgrep -n -x kitty)"
kill -0 "$(pgrep -n -x kitty)"
```

Expected: the first command lists the Kitty 0.47.4 process; both `kill` commands exit `0` and the process remains alive.

- [ ] **Step 3: Record the safe manual smoke sequence**

Do not synthesize these keystrokes automatically. Give the user this exact order:

1. `Ctrl+Q`, `Escape` — cancel without changing the terminal.
2. `Ctrl+Q`, `h` — create a right-hand split.
3. `Ctrl+Q`, `v` — create a lower split.
4. `Ctrl+Q`, arrow keys — move between Kitty windows.
5. `Ctrl+Q`, `c`, then `Ctrl+Q`, `n`/`p` — create and switch tabs.
6. `Ctrl+Q`, `s` — open the empty or populated session selector.
7. `Ctrl+Q`, `Shift+S` — only when ready to create a real session file.
8. `Ctrl+Q`, `Ctrl+S` — only after the selected session has a backing file.

Expected: automated work claims parser and reload verification only; behavioral items remain explicitly user-verifiable.

- [ ] **Step 4: Provide the exact rollback command**

If any live behavior is wrong, run:

```bash
/usr/bin/bash -lc 'backup=$(rg --files -g "kitty.conf.pre-tmux-migration-*" /home/lemon/.config/kitty | sort | tail -1); cp --preserve=mode "$backup" /home/lemon/.config/kitty/kitty.conf; kill -USR1 "$(pgrep -n -x kitty)"'
```

Expected: the newest timestamped backup is restored and the running Kitty process reloads it.

- [ ] **Step 5: Confirm repository state was not polluted by runtime artifacts**

Run:

```bash
git status --short
```

Expected: no changes from implementation; runtime backup, staging files, live Kitty config, and session storage are all outside the repository.

No repository commit: Task 5 verifies external runtime state only.
