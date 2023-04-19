---@type MappingsTable
local M = {}

-- M.general = {}

M.lspconfig = {
  plugin = false,
}

M.tabufline = {
  plugin = false,
}

M.nvterm = {
  plugin = false,
}

M.whichkey = {
  plugin = false,
}

M.nvterm = {
  plugin = false,
}

M.blankline = {
  plugin = false,
}

M.comment = {
  plugin = false,

  n = {
    ["gc"] = {
      function()
        require("Comment").toggle()
      end,
      "toggle line comment",
    },
    ["gb"] = {
      function()
        require("Comment").toggle()
      end,
      "toggle block comment",
    },
  },
}

M.carbon = {
  plugin = false,

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

M.neozoom = {
  plugin = false,

  n = {
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
}

M.telescope = {
  plugin = false,

  n = {
    [";"] = { ":", "enter command mode", opts = { nowait = true } },
    ["<leader>tt"] = {
      function()
        require("base46").toggle_theme()
      end,
      "toggle theme", opts = { nowait = true },
    },
  },
}

M.gitsigns = {
  plugin = false,

  n = {
    ["<leader>ta"] = {
      function()
        require("gitsigns").toggle_numhl()
      end,
      "Toggle addition",
    },
  },
}

return M
