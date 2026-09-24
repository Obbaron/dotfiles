-- animations.lua

-- hl.curve("smooth", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })
hl.curve("snappy", { type = "spring", mass = 1, stiffness = 300, dampening = 22 })

hl.animation({ leaf = "windows",    enabled = true, speed = 5, spring = "snappy" })
hl.animation({ leaf = "fade",       enabled = true, speed = 6, spring = "snappy" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, spring = "snappy" })
hl.animation({ leaf = "border",     enabled = true, speed = 8, spring = "snappy" })

hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, spring = "snappy", style = "slidefadevert -50%" })
