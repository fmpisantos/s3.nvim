**Repository Guide**
- Purpose: lightweight Neovim plugin to browse/download/deploy S3 objects (entry: `lua/s3/init.lua`).
- Audience: agents and contributors who will read, test, lint, and modify Lua code for Neovim.

- Quick start: open this repo from your local Neovim configuration (or use `:luafile` to load during development).

**Build / Lint / Test Commands**
- Install recommended tools (local machine): `stylua`, `luacheck`, `busted` (for plain Lua tests), `neovim` + `plenary.nvim` (for runtime tests).
- Run formatter (Stylua):

```bash
# format all lua files
stylua .
```

- Run linter (Luacheck):

```bash
# lint all lua files
luacheck . --exclude-paths '*/.git/*'
```

- Run unit tests (plain busted):

```bash
# run all busted tests (if any exist)
busted
# run a single spec file
busted spec/path/to/your_spec.lua
```

- Run tests inside Neovim (preferred for this plugin since it depends on runtime APIs):

```bash
# run a single spec file with plenary in headless nvim (requires plenary.nvim in runtimepath)
nvim --headless -c "lua require('plenary.path')" -c "PlenaryBustedFile spec/path/to/your_spec.lua" -c qa

# run an entire directory with plenary
nvim --headless -c "PlenaryBustedDirectory spec" -c qa
```

- Run a single test case (two options):
  - If using `busted` directly you can run a specific file and use `--filter`/`--pattern` to match test names (examples vary by busted version). A reliable option is running the spec file and using a focused `describe/it` by name.
  - With Neovim + Plenary: open `spec/your_spec.lua` in Neovim and run `:PlenaryBustedFile spec/your_spec.lua` or use the file with a focused test (rename `it` to `it("focus: ...", ...)` or use `pending`/`describe` helpers when available).

**Development / Iteration**
- Load code into a running Neovim without restart: from repo root, in Neovim run `:luafile lua/s3/init.lua` to re-source the main module while iterating.
- When debugging async behavior, prefer running Neovim with `--headless` and `-c` commands to reproduce background workflows (downloads, Job callbacks).

**Code Style & Conventions**
- File layout and modules:
  - Each plugin module returns a table (named `M`) at the end: follow the pattern used in `lua/s3/init.lua`.
  - Keep `require` calls at the top of the file and assign to locals: e.g. `local Job = require("plenary.job")`.

- Formatting:
  - Use `stylua` as the canonical formatter. Configure `stylua.toml` if project-specific values are needed (this repo uses 4-space indent in existing files).
  - Indentation: 4 spaces; no hard tabs.
  - Strings: keep consistent quotes (current code uses double quotes). Let `stylua` enforce quoting rules.

- Imports / Requires:
  - Group external deps first (plenary, telescope, etc.), then internal requires.
  - Use short, clear local names for required modules: `local Path = require("plenary.path")`.
  - Avoid global requires at runtime; always `local`-bind the result.

- Naming conventions:
  - Use snake_case for local variables and functions (e.g. `full_local_dir_path`, `parse_s3_ls_output`).
  - Use `M.<public_name>` for exported functions (e.g. `M.setup`, `M.deploy`).
  - Constants (rare in this repo) may be ALL_CAPS if truly constant.

- Types / annotations:
  - Lua is untyped: prefer brief EmmyLua comments for complex functions and parameters to help LSPs. Example:

```lua
--- Setup plugin
--- @param opts table|nil
function M.setup(opts)
  -- ...
end
```

- Function structure and privacy:
  - Exported API: attach functions to `M` and keep them documented with a one-line description.
  - Internal helpers: declare as `local function foo(...)` and keep them near the top (or logically placed) to improve readability.

- Error handling and notifications:
  - Use `vim.notify(message, vim.log.levels.*)` for user-facing errors and info. Match `INFO`, `WARN`, `ERROR` levels appropriately.
  - Prefer early returns after detecting error states. Avoid deeply nested conditionals.
  - When running async jobs (Plenary Job), check the `on_exit` code and surface `j:stderr_result()` when available.

- Async patterns:
  - Use `plenary.job` for external processes. Wrap UI updates in `vim.schedule_wrap` when calling back from async threads (see `M.list_s3` and `M.download_file`).
  - Use `vim.api.nvim_create_autocmd` and `vim.api.nvim_create_user_command` for integration with Neovim.

- Telescope/pickers patterns:
  - Build pickers with `pickers.new({}, { ... }):find()` and use `action_state.get_selected_entry()` to extract the selection.
  - Keep `entry_maker` functions small and return `value`, `display`, and `ordinal` fields.

- Filesystem / Path handling:
  - Use `plenary.path` for path operations: `Path:new(dir):joinpath(file)` and `:mkdir({ parents = true })`.
  - Keep temporary files under `/tmp/nvim-s3/` (current pattern). When changing this path, ensure tests and autocmd patterns update accordingly.

**Testing Guidelines**
- Prefer Plenary-based tests for code that interacts with Neovim APIs. Place tests under `spec/` following busted/plenary conventions.
- Keep tests hermetic: mock external commands (AWS CLI) where possible. Use dependency injection or create a thin wrapper around `plenary.job` so the process can be replaced in tests.

**Git / Commit / PR Guidance for agents**
- Do not make destructive git changes. Create tidy commits with a one-line summary (imperative) and a short body if needed.
- If creating a branch or PR, ensure tests and linters run locally; include `AGENTS.md` changes in the same commit if they are repository-specific.

**Cursor / Copilot Rules**
- Cursor rules: none found in `.cursor/rules/` or `.cursorrules` in this repository.
- GitHub Copilot instructions: none found in `.github/copilot-instructions.md` in this repository.

**Where to look in this repo**
- Main implementation: `lua/s3/init.lua` (primary source to inspect for behavior and style).

**Next steps for an agent**
1. Run `stylua .` and `luacheck .` and fix style issues reported.
2. If adding tests, use `spec/` and run them via `nvim --headless -c "PlenaryBustedFile spec/your_spec.lua" -c qa`.
3. When modifying async flows, add tests that simulate Job exit codes and stderr output.

If you want I can add a minimal `stylua.toml` and a `Makefile` or `justfile` with the commands above. Recommend adding `spec/` scaffolding if you plan to add tests.
