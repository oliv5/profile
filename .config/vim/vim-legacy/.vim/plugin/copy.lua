-- https://github.com/neovim/neovim/issues/27675
-- https://github.com/neovim/neovim/issues/2325
if (vim.api.nvim_create_autocmd) then
  vim.api.nvim_create_autocmd('CursorMoved', {
    desc = 'Keep * synced with selection',
    callback = function()
      local mode = vim.fn.mode(false)
      if mode == 's' then mode = 'v' end -- setreg() cannot restore s mode
      if mode == 'S' then mode = 'V' end -- setreg() cannot restore S mode
      if mode == '^S' then mode = '\22' end -- setreg() cannot restore ^S mode
      if mode == 'v' or mode == 'V' or mode == '\22' then
        -- The following involves mode change
        --vim.cmd([[silent norm "*ygv]])
        -- The following does NOT involve mode change
        vim.fn.setreg('*', vim.fn.getregion(vim.fn.getpos('.'), vim.fn.getpos('v'), { type = mode }))
      end
    end,
  })
end
