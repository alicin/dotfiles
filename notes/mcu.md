# mcu — pull checklist

Desktop, two LG 4K monitors (one portrait), no touchscreen.
Format and pruning: `notes/README.md`. Run `bin/host-notes` here.

## Open

- [ ] 2026-08-07 — **Ghostty replaces kitty as the terminal.**
      `sudo pacman -S ghostty`, then re-run the profile (or
      `ln -s ~/labs/dotfiles/config/ghostty ~/.config/ghostty`). Every place
      **Watch the symlink:** ghostty creates its own `~/.config/ghostty/`
      (with an empty `config.ghostty` in it) the first time anything runs it,
      and that directory then blocks the profile's symlink. If `ghostty
      +show-config | grep theme` comes back empty, `rm -rf ~/.config/ghostty`
      and re-link.
      that names a terminal now says ghostty; the scratchpad `--class=`
      values are unchanged, so window rules carry over. Kitty is not
      uninstalled by the pull — drop it whenever you like.

- [ ] 2026-08-07 — **Verify workspace 10.**
      `binds.lua` now binds 1–9 for every host; this machine's tenth
      (Super+F5) moved into `hosts/mcu.lua`. Nothing else changed about the
      layout — `monitors.lua`'s old cross-host default rules are gone
      (they pinned workspaces to monitors that do not exist here).

- [ ] 2026-08-07 — **Optional: rose-pine icon themes.**
      `yay -S rose-pine-gtk-theme-full` if you want the icon set and cursor
      to follow the shell theme's light/dark. Skipped silently otherwise.

## Done

_(entries land here with a `→ done <date>` and are deleted a week later)_
