local M = {}
local Job = require("plenary.job")
local Path = require("plenary.path")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

M.config = {
    bucket = nil,
    profile = "default",
}

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    -- Register commands
    vim.api.nvim_create_user_command("S3Ls", function(args)
        local bucket = M.config.bucket
        local profile = M.config.profile

        -- Parse args if provided (simple parsing: bucket profile)
        local params = vim.split(args.args, " ")
        if params[1] and params[1] ~= "" then bucket = params[1] end
        if params[2] and params[2] ~= "" then profile = params[2] end

        if not bucket then
            vim.notify("S3: Bucket not specified in setup or command args", vim.log.levels.ERROR)
            return
        end

        M.list_s3(bucket, "", profile)
    end, { nargs = "*" })

    vim.api.nvim_create_user_command("S3Deploy", function()
        M.deploy()
    end, {})

    -- Autocmd to restore buffer variables if opening an existing s3 temp file
    local group = vim.api.nvim_create_augroup("S3Plugin", { clear = true })
    vim.api.nvim_create_autocmd("BufRead", {
        group = group,
        pattern = "/tmp/nvim-s3/*",
        callback = function(ev)
            -- Path format: /tmp/nvim-s3/<bucket>/<key>
            local path = ev.file
            local relative_path = path:match("/tmp/nvim-s3/(.*)")
            if relative_path then
                local parts = vim.split(relative_path, "/")
                local bucket = table.remove(parts, 1)
                local key = table.concat(parts, "/")

                vim.b.s3_bucket = bucket
                vim.b.s3_key = key
                -- We might not know the profile if just opening the file,
                -- default to config or try to infer?
                -- For now, fallback to config profile if not set
                if not vim.b.s3_profile then
                    vim.b.s3_profile = M.config.profile
                end
            end
        end
    })
end

local function parse_s3_ls_output(output_lines)
    local entries = {}
    for _, line in ipairs(output_lines) do
        if line and line ~= "" then
            -- Handle PRE (folder)
            -- Format: "                           PRE foldername/"
            local pre_match = line:match("%s+PRE%s+(.+)")

            if pre_match then
                table.insert(entries, {
                    name = pre_match,
                    type = "folder",
                    display = "📁 " .. pre_match
                })
            else
                -- Handle File
                -- Format: "2023-10-27 10:00:00 1234 filename.txt"
                -- Use regex to capture name preserving spaces
                local date, time, size, name = line:match("^(%d%d%d%d%-%d%d%-%d%d)%s+(%d%d:%d%d:%d%d)%s+(%d+)%s+(.*)$")

                if name and name ~= "" then
                    table.insert(entries, {
                        name = name,
                        type = "file",
                        display = "📄 " .. name
                    })
                end
            end
        end
    end
    return entries
end

function M.list_s3(bucket, prefix, profile)
    local s3_uri = string.format("s3://%s/%s", bucket, prefix)

    Job:new({
        command = "aws",
        args = { "--profile", profile, "s3", "ls", s3_uri },
        on_exit = vim.schedule_wrap(function(j, return_val)
            if return_val ~= 0 then
                vim.notify("Failed to list S3 bucket: " .. s3_uri, vim.log.levels.ERROR)
                return
            end

            local result = j:result()
            local entries = parse_s3_ls_output(result)

            if prefix and prefix ~= "" then
                table.insert(entries, 1, {
                    name = "../",
                    type = "up",
                    display = "📁 ../",
                })
            end

            if #entries == 0 then
                vim.notify("No files found in " .. s3_uri, vim.log.levels.WARN)
                return
            end

            M.show_telescope(entries, bucket, prefix, profile)
        end),
    }):start()
end

function M.show_telescope(entries, bucket, current_prefix, profile)
    pickers.new({}, {
        prompt_title = string.format("S3: %s/%s", bucket, current_prefix),
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.display,
                    ordinal = entry.name,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                local entry = selection.value

                if entry.type == "folder" then
                    -- Recursive call
                    M.list_s3(bucket, current_prefix .. entry.name, profile)
                elseif entry.type == "up" then
                    -- Go up one level
                    local new_prefix = ""
                    if current_prefix and current_prefix ~= "" then
                        -- Remove trailing slash
                        local p = current_prefix:sub(1, -2)
                        -- Find last slash
                        local last_slash_idx = p:match("^.*()/")
                        if last_slash_idx then
                            new_prefix = p:sub(1, last_slash_idx)
                        end
                    end
                    M.list_s3(bucket, new_prefix, profile)
                else
                    -- Download file
                    M.download_file(bucket, current_prefix .. entry.name, profile)
                end
            end)
            return true
        end,
    }):find()
end

function M.download_file(bucket, key, profile)
    local local_dir = string.format("/tmp/nvim-s3/%s", bucket)

    -- key might contain subdirectories
    local key_parts = vim.split(key, "/")
    local filename = table.remove(key_parts)
    local key_dir = table.concat(key_parts, "/")

    local full_local_dir_path = Path:new(local_dir):joinpath(key_dir)
    local local_path = full_local_dir_path:joinpath(filename)

    -- Ensure directory exists
    full_local_dir_path:mkdir({ parents = true })

    local s3_uri = string.format("s3://%s/%s", bucket, key)

    vim.notify("Downloading " .. s3_uri .. " ...", vim.log.levels.INFO)

    Job:new({
        command = "aws",
        args = { "--profile", profile, "s3", "cp", s3_uri, local_path:absolute() },
        on_exit = vim.schedule_wrap(function(j, return_val)
            if return_val ~= 0 then
                vim.notify("Failed to download file: " .. s3_uri, vim.log.levels.ERROR)
                return
            end

            vim.notify("Downloaded to " .. local_path:absolute(), vim.log.levels.INFO)

            -- Open file
            vim.cmd.edit(local_path:absolute())

            -- Set buffer variables
            vim.b.s3_bucket = bucket
            vim.b.s3_key = key
            vim.b.s3_profile = profile

            -- Optional: Set up autosave deploy
            vim.api.nvim_create_autocmd("BufWritePost", {
                buffer = 0,
                callback = function()
                    M.deploy()
                end
            })
        end),
    }):start()
end

function M.deploy()
    local bucket = vim.b.s3_bucket
    local key = vim.b.s3_key
    local profile = vim.b.s3_profile or M.config.profile

    if not bucket or not key then
        -- Fallback: Check file path if variables are missing
        local path = vim.api.nvim_buf_get_name(0)
        local relative_path = path:match("/tmp/nvim-s3/(.*)")
        if relative_path then
            local parts = vim.split(relative_path, "/")
            bucket = table.remove(parts, 1)
            key = table.concat(parts, "/")

            -- Update vars for next time
            vim.b.s3_bucket = bucket
            vim.b.s3_key = key
            vim.b.s3_profile = profile
        else
            vim.notify("Not an S3 file (metadata missing and path not in /tmp/nvim-s3)", vim.log.levels.ERROR)
            return
        end
    end

    local s3_uri = string.format("s3://%s/%s", bucket, key)
    local local_path = vim.api.nvim_buf_get_name(0)

    vim.notify("Deploying to " .. s3_uri .. " ...", vim.log.levels.INFO)

    Job:new({
        command = "aws",
        args = { "--profile", profile, "s3", "cp", local_path, s3_uri },
        on_exit = vim.schedule_wrap(function(j, return_val)
            if return_val ~= 0 then
                local stderr = table.concat(j:stderr_result(), "\n")
                vim.notify("Failed to deploy: " .. stderr, vim.log.levels.ERROR)
            else
                vim.notify("Successfully deployed to " .. s3_uri, vim.log.levels.INFO)
            end
        end),
    }):start()
end
return M

