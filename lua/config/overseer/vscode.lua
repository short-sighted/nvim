-- Project-scoped variant of the locked upstream VSCode provider.
local files = require("overseer.files")
local variables = require("overseer.vscode.variables")
local vs_util = require("overseer.vscode.vs_util")
local vscode = require("overseer.vscode")

---@type overseer.TemplateFileProvider
return {
  name = "user-vscode-tasks",
  generator = function(opts)
    local tasks_file = vs_util.get_tasks_file(opts.dir, opts.dir)
    if not tasks_file then
      return "No .vscode/tasks.json file found"
    end
    local content = vs_util.load_tasks_file(tasks_file)
    local global_defaults = {}
    for k, v in pairs(content) do
      if k ~= "version" and k ~= "tasks" then
        global_defaults[k] = v
      end
    end
    local os_key
    if files.is_windows then
      os_key = "windows"
    elseif files.is_mac then
      os_key = "osx"
    else
      os_key = "linux"
    end
    if content[os_key] then
      global_defaults = vim.tbl_deep_extend("force", global_defaults, content[os_key])
    end
    local ret = {}
    local precalculated_vars = variables.precalculate_vars()
    local workspace = vim.fn.resolve(vim.fs.dirname(vim.fs.dirname(tasks_file)))
    local file = vim.api.nvim_buf_get_name(0)
    local relative = vim.fs.relpath(workspace, file) or file
    precalculated_vars.workspaceFolder = workspace
    precalculated_vars.workspaceRoot = workspace
    precalculated_vars.workspaceFolderBasename = vim.fs.basename(workspace)
    precalculated_vars.fileWorkspaceFolder = workspace
    precalculated_vars.relativeFile = relative
    precalculated_vars.relativeFileDirname = vim.fs.dirname(relative) or "."
    precalculated_vars.cwd = workspace

    if content.tasks == nil then
      return "No 'tasks' key found in '.vscode/tasks.json'"
    end

    for _, task in ipairs(content.tasks) do
      local defn = vim.tbl_deep_extend("force", global_defaults, task)
      defn = vim.tbl_deep_extend("force", defn, task[os_key] or {})
      defn.options = defn.options or {}
      defn.options.cwd = defn.options.cwd or workspace
      local tmpl = vscode.convert_vscode_task(defn, precalculated_vars)
      if tmpl then
        table.insert(ret, tmpl)
      end
    end
    return ret
  end,
}
