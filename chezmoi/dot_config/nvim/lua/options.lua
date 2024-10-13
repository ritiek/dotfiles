require "nvchad.options"

-- add yours here!

-- vim.o.cursorlineopt = 'both' -- highlights current cursor line
vim.o.scrolloff = 5 -- always show x number of top and bottom lines on buffer

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  group = vim.api.nvim_create_augroup("kick-start-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
    -- if vim.v.event.operator == 'y' and vim.v.event.regname == '+' then
      -- require('osc52').copy_register('+')
    -- end
  end,
})

-- vim.o.clipboard = "unnamedplus"
-- vim.o.clipboard = "wl-copy"

local function paste()
  return {
    vim.fn.split(vim.fn.getreg(""), "\n"),
    vim.fn.getregtype(""),
  }
end


local osc52 = require "vim.ui.clipboard.osc52"

vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = osc52.copy("+"),
    ["*"] = osc52.copy("*"),
  },
  paste = {
    ["+"] = paste,
    ["*"] = paste,
  },
}

-- Now the '+' register will copy to system clipboard using OSC52
-- vim.keymap.set('n', '<leader>y', '"+y')
-- vim.keymap.set('n', '<leader>yy', '"+yy')
