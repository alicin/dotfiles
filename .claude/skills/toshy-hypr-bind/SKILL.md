---
name: toshy-hypr-bind
description: Create or fix Hyprland keybindings that must work while Toshy (macOS-style keymapper) is running. Use whenever adding/changing a keybind in config/hypr/lua/binds.lua, or when a Hyprland shortcut "doesn't fire" / is "intercepted by Toshy", or when the user describes a shortcut in physical / macOS terms (Cmd, Option, the Super/Win key, "physical alt"). Translates the physical keypress the user wants into the modifier Hyprland actually receives after Toshy remaps it.
---

# Binding Hyprland shortcuts under Toshy

Toshy grabs the physical keyboard (EVIOCGRAB) and re-emits **virtual** key events through
a uinput device ("XWayKeyz (virtual) Keyboard"). Hyprland — including its global binds —
only ever sees Toshy's *output*, never the physical keys. So a Hyprland bind must target the
modifier Toshy **emits**, not the key the user physically presses. Binding `SUPER+...` to the
physical Super key silently never fires, because Toshy remaps physical Super away.

## The physical → emitted modifier map

Valid for this machine's active Toshy config: `optspec_layout=Disabled`, **Windows**
keyboard type, `l_cmd_is_sup_and_cmd=False`, `l_opt_is_sup_and_opt=False`, `multi_lang=False`,
`Caps2Cmd=False`. (Verify with `sqlite3 ~/.config/toshy/toshy_user_preferences.sqlite
"SELECT name,value FROM config_preferences"`.) Toshy emulates a Mac key layout positionally:
PC `[Ctrl][Win][Alt]` → Mac `[Ctrl][Option][Command]`.

**GUI / normal-app context** — what Hyprland sees for global binds when the focused window is
NOT a terminal:

| Physical key            | Hyprland receives        | macOS role |
|-------------------------|--------------------------|------------|
| Left Ctrl               | **Super** (Left_Meta)    | Ctrl       |
| Left Win / Super        | **Alt** (Left_Alt)       | Option     |
| Left Alt                | **Ctrl** (Right_Ctrl)    | Command    |
| Right Ctrl              | **Super** (Right_Meta)   |            |
| Right Win               | **Alt** (Right_Alt)      |            |
| Right Alt / AltGr       | **Ctrl** (Right_Ctrl)    |            |
| Shift, CapsLock         | unchanged                |            |

**Terminal context** differs in ONE way that matters: **Left Ctrl stays Ctrl** (not Super).
Everything else (Win→Alt, Alt→Ctrl, Right keys) is the same.

### Rule of thumb for picking a modifier for a GLOBAL Hyprland bind
Global binds fire regardless of focus, so only use modifiers that map the **same** in both
contexts:
- physical **Alt** (macOS Command)  → **Ctrl**   ✅ consistent
- physical **Win/Super** (macOS Option) → **Alt** ✅ consistent
- physical **Ctrl** → Super in GUI but Ctrl in terminals ❌ inconsistent — avoid for globals.

### Quick translation of common macOS-style asks
| User says ("physical ...")     | Bind in Hyprland as |
|--------------------------------|---------------------|
| Cmd + KEY                      | `CTRL + KEY`        |
| Cmd + Shift + KEY              | `CTRL + SHIFT + KEY`|
| Super/Win + KEY (e.g. ws nav)  | `ALT + KEY`         |
| Super/Win + Shift + KEY        | `ALT + SHIFT + KEY` |

Caveat: Hyprland's modmask can't distinguish Left vs Right Ctrl, so a `CTRL+...` bind also
catches a literal Left-Ctrl press inside a terminal (where Left Ctrl stays Ctrl). Usually
harmless because the user pastes with Cmd; mention it if relevant.

## Procedure to add/fix a bind

1. Identify the **physical** combo the user wants.
2. Translate each modifier via the map above to what Hyprland receives.
3. Edit `config/hypr/lua/binds.lua`. Modifier tokens already defined there:
   `M`=SUPER, `MS`=SUPER+SHIFT, `MC`=SUPER+CTRL, `MA`=SUPER+ALT, `mod2`=ALT, `M2S`=ALT+SHIFT,
   `CA`=CTRL+ALT. Use plain strings like `"CTRL + SHIFT + V"` when no alias fits.
   Bind form: `hl.bind("CTRL + SHIFT + V", dsp.exec_cmd(apps.clipboard))`.
4. Apply: `hyprctl reload`.
5. Verify the bind registered with the expected modmask:
   `hyprctl binds -j | python3 -c "import json,sys; [print(b['modmask'],b['key'],b['dispatcher']) for b in json.load(sys.stdin) if b['key'].upper()=='<KEY>']"`
   Modmask bits: SHIFT=1, CAPS=2, CTRL=4, ALT=8, SUPER=64 (sum them; e.g. CTRL+SHIFT=5, ALT+SHIFT=9).

## Empirically confirming what a physical combo emits (when unsure)

Run `wev -f wl_keyboard:key` (Wayland), click the window, press the physical combo, read the
`sym:` (e.g. `Control_R`, `Alt_L`) and `mods:` lines. This is the ground truth Hyprland binds
on. Use it to validate the map or to handle a non-Windows keyboard type / changed Toshy prefs.

## Making macOS shortcuts work *inside* a specific app (Toshy keymap, not Hyprland)

If an app "has no Cmd shortcuts," it's usually NOT a detection failure — Toshy's catch-all
"General GUI" keymap rewrites Cmd combos into ones the app ignores (common with apps that only
take single-key binds, e.g. imv: `q`/`x`/`i`/`o`/arrows). Fix = an app-specific Toshy keymap
that maps the Cmd combos onto the app's native keys. App keymaps are evaluated before
"General GUI", so they win.

1. Find the app's window class: `hyprctl clients -j | python3 -c "import json,sys;[print(c['class']) for c in json.load(sys.stdin)]"` (or Toshy's diagnostic: double-tap physical Cmd+Opt+Shift+I).
2. Find the app's native keybinds (e.g. imv's are in `/etc/imv_config`).
3. Edit `~/.config/toshy/toshy_config.py` **only inside a `SLICE_MARK_START/END` block**
   (edits outside are lost on Toshy upgrade). The `user_apps` slice is for app keymaps.
   In Toshy's internal combo notation `RC` = Cmd, `Alt` = Option, `C("q")` = a bare `q`. Pattern:
   ```python
   hmp_is_foo = matchProps(clas="^foo$")
   keymap("foo app", {
       C("RC-q"):   C("q"),     # Cmd+Q -> the app's quit key
       C("RC-equal"): C("i"),   # Cmd+= -> zoom in
   }, when = lambda ctx:
       cnfg.screen_has_focus and ctx_ovl_macos_globals and hmp_is_foo(ctx) )
   ```
4. Validate + reload: `python3 -m py_compile ~/.config/toshy/toshy_config.py && systemctl --user restart toshy-config.service`.
5. Verify it came back up (Python block-buffers stdout, so the journal may look stuck after
   "SharedDeviceContext initialized" even when fine — check the real signal instead):
   `grep -q XWayKeyz /proc/bus/input/devices && echo grabbed` and `systemctl --user show toshy-config.service -p NRestarts` (should stay 0, no Traceback in the journal).

Note `~/.config/toshy/toshy_config.py` is NOT in the dotfiles repo; the `user_apps` slice is the
only upgrade-safe place to keep these.

## Notes
- The config is Lua (`config/hypr/lua/`), loaded by Hyprland's native Lua support; the `hl`
  API is documented in `/usr/share/hypr/stubs/hl.meta.lua`.
- If Toshy prefs change (different keyboard type, optspec enabled, `l_cmd_is_sup_and_cmd`
  turned on, Caps2Cmd, etc.) this map shifts — re-derive from
  `~/.config/toshy/toshy_config.py` modmaps gated on the current pref flags, or re-capture
  with `wev`.
