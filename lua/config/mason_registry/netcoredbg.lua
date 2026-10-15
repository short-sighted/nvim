-- Official 3.2.0-1092 arm64 asset, SHA256 verified during installation:
-- f4fa33b3ff874910cc184b4bb3b9c56d0abdf5c6521cee0b144d7c6e4a6e59ea
return {
  schema = "registry+v1",
  name = "netcoredbg",
  description = "Official NetCoreDbg build for native macOS arm64.",
  homepage = "https://github.com/Samsung/netcoredbg",
  licenses = { "MIT" },
  languages = { "C#", "F#" },
  categories = { "DAP" },
  source = {
    id = "pkg:github/Samsung/netcoredbg@3.2.0-1092",
    asset = {
      target = "darwin_arm64",
      file = "netcoredbg-osx-arm64.zip:libexec/",
      bin = "exec:libexec/netcoredbg/netcoredbg",
    },
  },
  bin = { netcoredbg = "{{source.asset.bin}}" },
}
