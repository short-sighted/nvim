-- Mason's registry currently selects an x64 netcoredbg on Apple Silicon.
local system = vim.uv.os_uname()
if system.sysname == "Darwin" and system.machine == "arm64" then
  return { "config.mason_registry.netcoredbg" }
end
return {}
