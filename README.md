s3.nvim
======

Lightweight Neovim plugin to browse, download and deploy objects in Amazon S3 using the AWS CLI and Telescope.

What it does
-----------
- Lists S3 bucket contents in a Telescope picker with folders and files.
- Downloads selected files to a temporary local directory and opens them in a buffer.
- Lets you deploy (upload) the current buffer back to the original S3 key.
- Optionally triggers deploy automatically after saving a file opened by the plugin.

Requirements
-----------
- Neovim (0.5+)
- aws CLI on your PATH and configured profiles (https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
- plenary.nvim (runtime dependency)
- telescope.nvim (optional but recommended for the picker UI)

Installation
-----------
Install with your favorite plugin manager. Examples:

Packer:

```lua
use {
  'yourname/s3.nvim',
  requires = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' }
}
```

Lazy:

```lua
{ 'yourname/s3.nvim', dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' } }
```

Setup / Configuration
---------------------
Call the setup function from your Neovim configuration to set defaults. Available options:

- `bucket` (string|nil) — default S3 bucket to use when running `:S3Ls` with no args.
- `profile` (string) — AWS CLI profile to use (defaults to `"default"`).

Example:

```lua
require('s3').setup({
    bucket = "my-default-bucket", -- optional
    profile = "default",
})
```

Commands / Usage
----------------
- `:S3Ls [bucket] [profile]`
  - Opens a Telescope picker listing objects under the bucket (and optional prefix).
  - If you configured a `bucket` in `setup`, you can omit the bucket argument.
  - Example: `:S3Ls` or `:S3Ls my-bucket my-profile`.

- `:S3Deploy`
  - Uploads the current buffer back to the S3 key it was downloaded from.
  - The buffer must have been opened by the plugin (metadata stored in buffer variables) or be located under `/tmp/nvim-s3/<bucket>/...`.

Behaviour Details
-----------------
- When you choose a folder in the picker it navigates into that prefix recursively.
- Selecting a file downloads it to `/tmp/nvim-s3/<bucket>/<key>` and opens it.
- The plugin sets buffer-local variables: `vim.b.s3_bucket`, `vim.b.s3_key`, and `vim.b.s3_profile` so `:S3Deploy` knows where to upload.
- When a buffer is opened by the plugin it installs a `BufWritePost` autocmd for that buffer which calls `M.deploy()` (so saving can auto-deploy). You can remove or override that behaviour in your config if you prefer.

Troubleshooting
---------------
- "Failed to list S3 bucket" / "Failed to download file": make sure `aws` is installed and the profile has permissions to list/get the objects.
- If Telescope doesn't show up, ensure `telescope.nvim` and `plenary.nvim` are installed and on Neovim's runtimepath.
- Files opened outside `/tmp/nvim-s3` will not have S3 metadata — run `:S3Deploy` only on files that were downloaded with the plugin or manually set `vim.b.s3_bucket` and `vim.b.s3_key`.

Contributing
------------
Contributions and issues are welcome. The codebase is intentionally small — see `lua/s3/init.lua` for the implementation.

License
-------
MIT
