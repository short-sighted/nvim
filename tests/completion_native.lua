-- Requires the native matcher downloaded by blink.cmp (network on first run).
-- Run: nvim --headless -i NONE '+luafile tests/completion_native.lua'
for name in pairs(vim.lsp._enabled_configs) do
  vim.lsp.enable(name, false)
end
local ok, err = pcall(function()
  assert(
    vim.wait(60000, function()
      return package.loaded["blink.cmp.completion.trigger"] ~= nil
    end, 20),
    "Completion setup did not finish"
  )
  local fuzzy = require("blink.cmp.fuzzy")
  -- A substitution cannot match as a Lua subsequence; Rust permits one typo.
  local matches = fuzzy.fuzzy("pront", 5, {
    buffer = {
      { label = "print", source_id = "buffer" },
      { label = "unrelated", source_id = "buffer" },
    },
  }, "prefix")
  assert(#matches == 1 and matches[1].label == "print", "Native typo-tolerant matching is unavailable")
  assert(fuzzy.implementation_type == "rust", "Completion is still using the Lua fallback")
  print("Native completion: Rust library loaded and typo-tolerant matching passed")
end)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
