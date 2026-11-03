-- Data only: no title is invented, and no local configuration is read here.
return {
  version = 1,
  defaults = {
    severity = "info",
    content = {},
    policy = { ttl_seconds = 86400, dedupe_seconds = 10 },
  },
  presets = {
    ["task-completed"] = { severity = "success" },
    ["attention-required"] = { severity = "warning" },
    ["timer-ended"] = { severity = "info" },
  },
}
