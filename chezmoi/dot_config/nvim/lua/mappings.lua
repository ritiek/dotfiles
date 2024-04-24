require "nvchad.mappings"

local function removeKeyMap()
end

vim.keymap.set({ "n", "i", "t" }, "<M-i>", function()
  require("nvchad.term").toggle({
    pos = "float",
    id = "floatTerm",
    float_opts = {
      relative = "editor",
      row = 0.075,
      col = 0.125,
      width = 0.8,
      height = 0.8,
      border = "single",
    }
  })
end, { desc = "Toggle Floating Term" })

vim.keymap.set({ "n", "i", "t" }, "<M-p>", function()
  require("nvchad.term").toggle({
    pos = "float",
    id = "floatTermMini",
    float_opts = {
      relative = "editor",
      row = 0.260,
      col = 0.380,
      width = 0.45,
      height = 0.45,
      border = "single",
    }
  })
end, { desc = "Toggle Mini Floating Term" })

vim.keymap.set("n", "=", "<C-a>", { desc = "Increment" })
vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement" })
vim.keymap.set("n", "<C-x>", removeKeyMap)

vim.keymap.set("n", "<Space><S-b>", function()
  vim.cmd("tabnew")
end, { desc = "New Tab" })
vim.keymap.set("n", "<Space><TAB>", function()
  vim.cmd("tabnext")
end, { desc = "Next Tab" })
vim.keymap.set("n", "<Space><S-TAB>", function()
  vim.cmd("tabprevious")
end, { desc = "Previous Tab" })
vim.keymap.set("n", "<Space><S-x>", function()
  vim.cmd("tabclose")
end, { desc = "Close Tab" })

vim.keymap.set("n", "<Space>*", function()
  vim.cmd("tabnew")
end, { desc = "New Tab" })
vim.keymap.set("n", "<Space><S-b>", function()
  vim.cmd("tabnew")
end, { desc = "New Tab" })

vim.keymap.set("n", "<leader>tt", function()
  require("base46").toggle_theme()
end, { desc = "Toggle Theme" })

-- Unbind <C-c> from NvChad from copying entire file contents to clipboard.
-- vim.keymap.set("<C-c>", function() end)

-- Bind "gy" to copy entire file contents to clipboard.
-- vim.keymap.set("gy", function()
--   vim.cmd("%yank")
-- end, { desc = "Copy entire buffer to clipboard" })

vim.keymap.set("t", "<S-Space>", function()
  vim.api.nvim_put({ " " }, "c", true, true)
end, { nowait = true })

vim.keymap.set("v", "<leader>cn", ":CarbonNow<CR>", { desc = "Carbon Now", nowait = true })
vim.keymap.set({ "n", "i" }, "<C-a>", function()
  -- vim.cmd("NeoZoomToggle")
  require("neo-zoom").neo_zoom({})
end, { desc = "NeoZoom Toggle", nowait = true })

vim.keymap.set("n", "<leader>ta", function()
  require("gitsigns").toggle_numhl()
end, { desc = "Toggle Addition" })
vim.keymap.set("n", "<leader>td", function()
  require("gitsigns").toggle_deleted()
end, { desc = "Toggle Deleted" })
vim.keymap.set("n", "<leader>tw", function()
  require("gitsigns").toggle_word_diff()
end, { desc = "Toggle Word Diff" })
vim.keymap.set("n", "<leader>ti", function()
  require("gitsigns").diffthis()
end, { desc = "Diff This" })
vim.keymap.set("n", "<leader>tm", function()
  local gitsigns = require("gitsigns")
  gitsigns.toggle_numhl()
  gitsigns.toggle_deleted()
  gitsigns.toggle_word_diff()
end, { desc = "Diff Mode" })
vim.keymap.set("n", "<leader>tr", function()
  require("gitsigns").reset_buffer()
end, { desc = "Reset Buffer" })

vim.keymap.set("n", "<M-j>", ":cnext<CR>", { desc = "cnext", nowait = true })
vim.keymap.set("n", "<M-k>", ":cprevious<CR>", { desc = "cprev", nowait = true })
vim.keymap.set("n", "<M-o>", ":copen<CR>", { desc = "copen", nowait = true })
vim.keymap.set("n", "<M-Esc>", ":cclose<CR>", { desc = "cclose", nowait = true })

vim.keymap.set("n", "<Space>fe", function()
  require("telescope.builtin").resume()
end, { desc = "Telescope Resume" })
vim.keymap.set("n", "<Space>fi", function()
  local word = vim.fn.expand("<cword>")
  require("telescope.builtin").grep_string({ search = word })
end, { desc = "Telescope Word" })
vim.keymap.set("n", "<Space>fI", function()
  local word = vim.fn.expand("<cWORD>")
  require("telescope.builtin").grep_string({ search = word })
end, { desc = "Telescope WORD" })
vim.keymap.set("n", "<Space>fk", function()
  require("telescope.builtin").keymaps()
end, { desc = "Telescope Keymaps" })
vim.keymap.set("n", "<Space>fu", function()
  require("telescope").extensions.undo.undo()
end, { desc = "Telescope Undo" })
vim.keymap.set("n", "<Space>fp", function()
  require("telescope").extensions.harpoon.marks()
end, { desc = "Telescope Harpoon" })

vim.keymap.set("n", "<A-0>", function()
  require("harpoon.mark").add_file()
end, { desc = "Harpoon add file" })
vim.keymap.set("n", "<A-->", function()
  require("harpoon.ui").nav_prev()
end, { desc = "Harpoon nav prev" })
vim.keymap.set("n", "<A-=>", function()
  require("harpoon.ui").nav_next()
end, { desc = "Harpoon nav prev" })
for buf=1,9 do
    vim.keymap.set("n", "<A-" .. buf .. ">", function()
      require("harpoon.ui").nav_file(buf)
    end, { desc = "Harpoon nav " .. buf })
end
vim.keymap.set("n", "<A-`>", function()
  require("harpoon.ui").toggle_quick_menu()
end, { desc = "Harpoon toggle quick menu" })

-- vim.keymap.set("t", "<C-x>", function()
--   vim.api.nvim_put({vim.api.nvim_replace_termcodes("<C-\\><C-x>", true, true, true)}, "c", true, true)
-- end)

-- vim.keymap.set("t", "<Esc>", function()
-- --   -- vim.api.nvim_feedkeys("", "t", true)
--   vim.api.nvim_put({vim.api.nvim_replace_termcodes("<Esc>", true, true, true)}, "c", true, true)
-- --   -- vim.api.nvim_put({"<M-Esc>"}, "c", true, true)
-- --   -- require("nvchad.term").send("<M-Esc>")
-- end)

-- toggle_word_diff

-- vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
