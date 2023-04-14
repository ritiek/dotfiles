---@type MappingsTable
local M = {}

M.general = {
  n = {
    [";"] = { ":", "enter command mode", opts = { nowait = true } },
    ["<leader>tt"] = {
      function()
        require("base46").toggle_theme()
      end,
      "toggle theme", opts = { nowait = true },
    },
    ["<C-a>"] = {
      function()
        vim.cmd("NeoZoomToggle")
      end,
      "neozoom toggle", opts = { nowait = true }
    },
  },

  i = {
    ["<C-a>"] = {
      function()
        vim.cmd("NeoZoomToggle")
      end,
      "neozoom toggle", opts = { nowait = true }
    },
  },

  v = {
    ["<leader>cn"] = {
      -- Not using this as it'd carbon now the entire file.
      -- function()
      --   vim.cmd("CarbonNow")
      -- end,
      ":CarbonNow<CR>",
      "carbon now", opts = { nowait = true }
    },
  },
}

-- more keybinds!

return M
