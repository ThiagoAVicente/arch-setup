return {
    -- Override LazyVim's colorscheme configuration to ensure transparency
    {
        "LazyVim/LazyVim",
        opts = {
            -- Keep the colorscheme but we'll make it transparent
            colorscheme = function()
                -- Load the default colorscheme
                vim.cmd("colorscheme tokyonight")

                -- Force transparency after colorscheme loads
                vim.schedule(function()
                    local transparent_groups = {
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

                    for _, group in ipairs(transparent_groups) do
                        vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
                    end
                end)
            end,
        },
    },
}
