-- return {
--   "m4xshen/hardtime.nvim",
--   dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
--   opts = {
--     max_count = 3,
--     max_time = 2000,
--     hint = true,
--     disabled_filetypes = { "NvimTree", "lazy", "help" },
--     disabled_buffer_types = { "nofile", "terminal" },
--     restriction_patterns = {
--       ["h"]  = true, ["j"]  = true, ["k"]  = true, ["l"]  = true,
--       ["0"]  = true, ["^"]  = true, ["$"]  = true, ["w"]  = true,
--       ["b"]  = true, ["e"]  = true, ["gg"] = true, ["G"]  = true,
--     },
--   },
-- }

return {
   "m4xshen/hardtime.nvim",
   lazy = false,
   dependencies = { "MunifTanjim/nui.nvim" },
   opts = {},
}
