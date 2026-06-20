-- Animation curves and per-leaf animations.
-- The `enabled = yes` keyword is set in lua/options.lua via hl.config{}.

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 5,  bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7,  bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 14, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3,  bezier = "default" })
