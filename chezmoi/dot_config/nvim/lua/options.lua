require "nvchad.options"

-- add yours here!

local o = vim.o

-- o.cursorlineopt = 'both' -- highlights current cursor line
o.scrolloff = 5 -- always show x number of top and bottom lines on buffer

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  group = vim.api.nvim_create_augroup("kick-start-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
