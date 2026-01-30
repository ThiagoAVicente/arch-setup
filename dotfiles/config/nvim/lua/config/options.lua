-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.termguicolors = true

-- Function to apply transparency
local function apply_transparency()
    local highlights = {
        "Normal",
        "NormalNC",
        "NormalFloat",
        "SignColumn",
        "LineNr",
        "CursorLineNr",
        "EndOfBuffer",
        "VertSplit",
        "WinSeparator",
        "StatusLine",
        "StatusLineNC",
        "TabLine",
        "TabLineFill",
        "Pmenu",
        "PmenuSbar",
    }

    for _, hl in ipairs(highlights) do
        vim.api.nvim_set_hl(0, hl, { bg = "NONE", ctermbg = "NONE" })
    end
end

-- Apply transparency after colorscheme changes
vim.api.nvim_create_autocmd("ColorScheme", {
    callback = apply_transparency,
})

-- Apply transparency after UI enters (ensures it overrides everything)
vim.api.nvim_create_autocmd("UIEnter", {
    callback = function()
        vim.defer_fn(apply_transparency, 100)
    end,
})

-- Apply immediately
apply_transparency()
