# Host notes — what each machine has to do after a pull

One file per host (`k3v1n.md`, `h4l9000.md`, `mcu.md`). A change that needs a
hand on *that* machine — install a package, restart a service, verify hardware
— gets an entry there. Anything the repo applies by itself does not.

This replaced the sprawling `todo-*.md` / `*-review.md` files: those were
work logs that outlived their work and nobody ever deleted. These are
checklists with an expiry.

## Format

```markdown
- [ ] 2026-08-07 — Short imperative title
      Any detail, indented. Commands in backticks.
- [x] 2026-08-07 → done 2026-08-09 — Something already handled
```

- `- [ ]` open, `- [x]` done. The first date is when the change landed; the
  `→ done <date>` is when that host actually did it.
- Indented lines belong to the entry above and travel with it.
- **Done entries are deleted a week after their done-date** — that is the
  whole point of the format. `bin/host-notes` does it.

## Using it

```sh
bin/host-notes            # open items for this host (and prunes stale done ones)
bin/host-notes --all      # every host
bin/host-notes --done "ghostty"   # mark the matching open item done today
```

Hyprland runs `bin/host-notes --notify` at session start (lua/startup.lua), so
a machine with pending items says so once per login and stays quiet otherwise.
