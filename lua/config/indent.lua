return function(width, spaces)
  vim.bo.shiftwidth = width
  vim.bo.tabstop = width
  vim.bo.softtabstop = spaces and -1 or 0
  vim.bo.expandtab = spaces
  local undo = "setlocal shiftwidth< tabstop< softtabstop< expandtab<"
  vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
end
