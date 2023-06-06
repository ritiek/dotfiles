local opt = vim.opt
local autocmd = vim.api.nvim_create_autocmd

-- Auto reload files
opt.autoread = true

-- Auto resize panes when resizing nvim window
autocmd("VimResized", {
  pattern = "*",
  command = "tabdo wincmd =",
})
