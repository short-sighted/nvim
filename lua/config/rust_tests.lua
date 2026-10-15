local M = {}

function M.binary(root, path)
  local nio = require("nio")
  if vim.in_fast_event() then
    nio.scheduler()
  end
  local future = nio.control.future()
  vim.system({
    "cargo",
    "test",
    "--manifest-path",
    vim.fs.joinpath(root, "Cargo.toml"),
    "--message-format=json",
    "--no-run",
    "--quiet",
  }, { cwd = root, text = true }, function(result)
    future.set(result)
  end)
  local result = future.wait()
  nio.scheduler()
  if result.code ~= 0 then
    error("Rust 测试构建失败：\n" .. (result.stderr or ""))
  end
  local candidates = {}
  path = vim.fn.resolve(path)
  for _, line in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
    local ok, artifact = pcall(vim.json.decode, line)
    if ok and artifact.reason == "compiler-artifact" and artifact.executable and artifact.profile.test then
      if vim.fn.resolve(artifact.target.src_path) == path then
        return artifact.executable
      end
      if vim.fs.relpath(vim.fs.dirname(artifact.target.src_path), path) then
        candidates[#candidates + 1] = artifact
      end
    end
  end
  if #candidates == 1 then
    return candidates[1].executable
  elseif #candidates > 1 then
    local selected = nio.ui.select(candidates, {
      prompt = "选择包含当前文件的 Rust 测试目标：",
      format_item = function(item)
        return item.target.name .. " (" .. table.concat(item.target.kind, ", ") .. ")"
      end,
    })
    return selected and selected.executable or require("dap").ABORT
  end
  error("没有找到当前源码对应的 Rust 测试可执行文件。")
end

return M
