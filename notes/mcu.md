# mcu — pull checklist

Desktop, two LG 4K monitors (one portrait), no touchscreen.
Format and pruning: `notes/README.md`. Run `bin/host-notes` here.

## Open

- [ ] 2026-08-07 — **Toshy prefs DB is untracked now — your symlink is dangling.**
      `~/.config/toshy/toshy_user_preferences.sqlite` was a symlink into the
      repo, and this pull **deletes the file it points at**, so Toshy will
      quietly build a fresh default DB — losing `override_kbtype=Windows`,
      `forced_numpad`, `altgr_on_menu_key` and the `Caps2*` flags the modmaps
      read. Replace the link with a real file (the `rm` matters — a redirect
      writes straight through a symlink):
      ```sh
      rm -f ~/.config/toshy/toshy_user_preferences.sqlite
      git -C ~/labs/dotfiles show 5aedf00d:config/toshy/toshy_user_preferences.sqlite \
        > ~/.config/toshy/toshy_user_preferences.sqlite
      systemctl --user restart toshy-config.service
      ```
      Then confirm: `sqlite3 ~/.config/toshy/toshy_user_preferences.sqlite
      "SELECT name,value FROM config_preferences"` — 16 rows.
      Why: the symlink meant Toshy wrote runtime state into the working tree
      (`mru_layouts`, appended on every start), so the repo was dirty after
      every login on every host. Prefs are per-machine and untracked from now
      on; `toshy-install.sh` no longer relinks them.

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
