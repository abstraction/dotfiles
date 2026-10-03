return {
  "saghen/blink.cmp",
  opts = {
    completion = {
      menu = {
        auto_show = function()
          local ft = vim.bo.filetype
          local bufname = vim.api.nvim_buf_get_name(0)
          if vim.tbl_contains({ "markdown", "text", "gitcommit", "gitrebase" }, ft) then
            return false
          end
          if bufname:match("jetski%-prompt") then
            return false
          end
          return true
        end,
      },
      ghost_text = {
        enabled = false,
      },
    },
  },
}
