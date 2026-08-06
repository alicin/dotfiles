# Toshy config (tracked subset)

Toshy installs itself into `~/.config/toshy` (a ~74 MB tree: a Python `.venv`,
dbus services, GUI code, scripts, kwin-script, etc.). Almost none of that is
*config* — it's the program, and Toshy regenerates much of it on upgrade. So we
do **not** symlink the whole directory. Only these two files are tracked here
(three counting this README, which stays put) and symlinked back into place:

| File | What it is |
|------|------------|
| `toshy_config.py` | The keymapper config. Keymaps live in its `SLICE_MARK_START/END` blocks (e.g. the `imv`/`yazi` keymaps in `user_apps`) — but the 2026-07-05 **modifier scheme is edits *outside* the slices**; see "The upgrade trap" below. The rest is upstream template (base: toshy commit `17dc24c4c3`, template `20260615`). |
| `toshy_user_preferences.sqlite` | GUI preferences that decide modifier behavior (optspec layout, Cmd-is-Ctrl, keyboard type, etc.). See the `desktop` skill for what the values mean. |

> **Never add `toshy` to a profile's `configs` array.** That array is fed to
> `link_config()`, which symlinks the *whole* `~/.config/<name>` directory and
> moves whatever was there into `~/.dotfiles-backup/`. For Toshy that means the
> entire 74 MB install — `.venv`, dbus services, `scripts/` — gets swapped for
> the three tracked files here, and every `~/.local/bin/toshy-*` symlink (they
> all point into `~/.config/toshy/scripts/bin/`) dangles. Use
> `scripts/toshy-install.sh` instead; it installs Toshy and re-creates the two
> file-level symlinks below.

Symlinks (created once):

```sh
ln -s ~/labs/dotfiles/config/toshy/toshy_config.py                ~/.config/toshy/toshy_config.py
ln -s ~/labs/dotfiles/config/toshy/toshy_user_preferences.sqlite  ~/.config/toshy/toshy_user_preferences.sqlite
```

## The upgrade trap

**A Toshy install/upgrade regenerates `toshy_config.py` and silently reverts
the whole modifier scheme.** This is not hypothetical: the 2026-08-05 install
wrote a stock file (preserved as `toshy_config.py.installed-20260805-181702` in
`~/.config/toshy/`) with **zero** of our edits — it even reset the `user_apps`
slice to boilerplate, so "customizations live in slices, slices survive
upgrades" is *not* a safe assumption on this install path. Only the manual
re-symlink restored the scheme. The failure mode is total and silent: physical
Super reverts to emitting Alt, physical Ctrl to Super — every SUPER-based
Hyprland bind stops firing at once, with no error anywhere.

What lives **outside** the slice blocks (the out-of-slice inventory — anything
here is lost if the tracked file is ever rebuilt from upstream):

- The scheme itself: `Key.LEFT_CTRL → LEFT_CTRL` and `Key.LEFT_META →
  LEFT_META` self-maps in the GUI and Terms Win-kbd modmaps (marked `# ALI:`,
  ~lines 2383/2399/2509), plus the commented-out stock originals around them.
- The terminals-list entry `'.*floating_shell.*'` (~line 497) that gives the
  floating kitty scratchpads terminal-context keymaps.
- The `getattr(cnfg, "Caps2…", False)` guards (~2030/2039/2316/2324) that keep
  xwaykeyz 1.25 from killing every modmap (its settings class dropped those
  attributes).
- The `ST`/`UC` keystroke-helper aliases (~412-413).

Defenses:

- `scripts/toshy-install.sh` ends with a **canary**: it verifies the live
  config is the tracked symlink *and* still contains
  `# ALI: Super stays native`, and refuses to restart the service otherwise.
- Upstream base for diffing: toshy commit `17dc24c4c3` (template `20260615`).
  To re-derive the inventory: strip the slice contents from both files and
  diff against that template.

Restore after an upgrade ate the config: re-run `scripts/toshy-install.sh`
(installs + relinks + canary), or by hand: re-create the `ln -s` above, then
diff the `.installed-*` backup against the tracked copy for upstream changes
worth merging into it.

## Caveats

- After editing `toshy_config.py`: `python3 -m py_compile` it, then
  `systemctl --user restart toshy-config.service`, then verify it came back:
  `grep -q XWayKeyz /proc/bus/input/devices && echo grabbed` (don't trust
  journal silence — Python block-buffers stdout).
- The `.sqlite` is binary, so git diffs are opaque. It changes when you toggle
  something in the Toshy GUI/tray — and newer Toshy also rewrites it on schema
  migration (e.g. adding the `capslock_mode` row), so a dirty sqlite right
  after an upgrade is expected, not an accident.
- `throttle_delays` (8/12 ms, in the `keymapper_api` slice) adds ~20 ms per
  emitted keystroke — a multi-combo macro like the yazi Cmd+T `[t, t]` pays
  ~40–80 ms. That latency is this knob, not the compositor; don't re-tune the
  wrong one.
- The systemd units tracked under `config/systemd/user/` are **not** what
  systemd runs: Toshy's installer writes its own fresh units into the real
  `~/.config/systemd/user/`, so the tracked copies can drift from the live
  ones silently. Treat them as provisioning seeds, not as the deployed truth.
