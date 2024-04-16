require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

local function removeMap ()
end

-- map("n", ";", ":", { desc = "CMD enter command mode" })

map({ "n", "i", "t" }, "<M-i>", function()
  require("nvchad.term").toggle({ pos = "float", id = "floatTerm", float_opts = {
    relative = "editor",
    row = 0.075,
    col = 0.125,
    width = 0.8,
    height = 0.8,
    border = "single",
  }})
end, { desc = "Toggle Floating Term" })

map({ "n", "i", "t" }, "<M-k>", function()
  require("nvchad.term").toggle({ pos = "float", id = "floatTermMini", float_opts = {
    relative = "editor",
    row = 0.260,
    col = 0.380,
    width = 0.45,
    height = 0.45,
    border = "single",
  }})
end, { desc = "Toggle Mini Floating Term" })

map("n", "=", "<C-a>", { desc = "Increment" })
map("n", "-", "<C-x>", { desc = "Decrement" })
map("n", "<C-x>", removeMap)
map("n", "<Space><S-b>", function()
  vim.cmd("tabnew")
end, { desc = "New Tab" })
map("n", "<Space><TAB>", function()
  vim.cmd("tabnext")
end, { desc = "Next Tab" })
map("n", "<Space><S-TAB>", function()
  vim.cmd("tabprevious")
end, { desc = "Previous Tab" })
map("n", "<Space><S-x>", function()
  vim.cmd("tabclose")
end, { desc = "Close Tab" })

map("n", "<leader>tt", function()
  require("base46").toggle_theme()
end, { desc = "Toggle Theme" })

-- Unbind <C-c> from NvChad from copying entire file contents to clipboard.
-- map("<C-c>", function() end)

-- Bind "gy" to copy entire file contents to clipboard.
-- map("gy", function()
--   vim.cmd("%yank")
-- end, { desc = "Copy entire buffer to clipboard" })

map("t", "<S-Space>", function()
  vim.api.nvim_put({" "}, "c", true, true)
end, { nowait = true })


map("v", "<leader>cn", ":CarbonNow<CR>", { desc = "Carbon Now", nowait = true })
map({ "n", "i" }, "<C-a>", function()
  vim.cmd("NeoZoomToggle")
end, { desc = "NeoZoom Toggle", nowait = true })
map("n", "<leader>ta", function()
  require("gitsigns").toggle_numhl()
end, { desc = "Toggle Addition" })
map("n", "<leader>ta", function()
  require("gitsigns").toggle_deleted()
end, { desc = "Toggle Deleted" })

-- toggle_word_diff

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
