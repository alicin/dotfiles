# Toshy config (tracked subset)

Toshy installs itself into `~/.config/toshy` (a ~74 MB tree: a Python `.venv`,
dbus services, GUI code, scripts, kwin-script, etc.). Almost none of that is
*config* — it's the program, and Toshy regenerates much of it on upgrade. So we
do **not** symlink the whole directory. Only these two files are tracked here and
symlinked back into place:

| File | What it is |
|------|------------|
| `toshy_config.py` | The keymapper config. All our customizations live in its `SLICE_MARK_START/END` blocks (e.g. the `imv` keymap in the `user_apps` slice). The rest is upstream template. |
| `toshy_user_preferences.sqlite` | GUI preferences that decide modifier behavior (optspec layout, Cmd-is-Ctrl, keyboard type, etc.). See the `toshy-hypr-bind` skill for what the values mean. |

Symlinks (created once):

```sh
ln -s ~/labs/dotfiles/config/toshy/toshy_config.py                ~/.config/toshy/toshy_config.py
ln -s ~/labs/dotfiles/config/toshy/toshy_user_preferences.sqlite  ~/.config/toshy/toshy_user_preferences.sqlite
```

## Caveats

- **Upgrades may break the symlink.** When Toshy reinstalls/upgrades, its
  installer may replace `toshy_config.py` with a fresh regular file (atomic
  rename), orphaning the symlink. After a Toshy upgrade, check with
  `ls -l ~/.config/toshy/toshy_config.py` — if it's no longer a symlink, copy any
  new upstream changes you want, then re-run the `ln -s` above. Your custom edits
  live in the SLICE blocks, which Toshy preserves across upgrades regardless.
- After editing `toshy_config.py`: `python3 -m py_compile` it, then
  `systemctl --user restart toshy-config.service`.
- The `.sqlite` is binary, so git diffs are opaque; it only changes when you
  toggle something in the Toshy GUI/tray.
