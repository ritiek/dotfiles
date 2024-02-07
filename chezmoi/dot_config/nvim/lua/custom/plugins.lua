local overrides = require("custom.configs.overrides")

---@type NvPluginSpec[]
local plugins = {

  -- Override plugin definition options

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- format & linting
      {
        "jose-elias-alvarez/null-ls.nvim",
        config = function(_, opts)
          require "custom.configs.null-ls"
        end,
      },
    },
    config = function(_, opts)
      require "plugins.configs.lspconfig"
      require "custom.configs.lspconfig"
    end, -- Override to setup mason-lspconfig
  },

  -- override plugin configs
  {
    "williamboman/mason.nvim",
    opts = overrides.mason
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = overrides.treesitter,
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = overrides.nvimtree,
  },

  {
    "NvChad/nvterm",
    opts = overrides.nvterm,
    init = require("core.utils").load_mappings "nvterm",
    config = function(_, opts)
      require "base46.term"
      require("nvterm").setup(opts)
    end,
  },

  -- Install a plugin
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function(_, opts)
      require("better_escape").setup()
    end,
  },

  {
    "numToStr/Comment.nvim",
    event = "BufWinEnter",
    opts = overrides.comment,
  },

  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = overrides.copilot,
  },

  {
    "nyngwang/NeoZoom.lua",
    event = "BufWinEnter",
    opts = overrides.neozoom,
    config = function(_, opts)
      require("neo-zoom").setup(opts)
    end,
  },

  {
    "ellisonleao/carbon-now.nvim",
    event = "BufWinEnter",
    config = function(_, opts)
      require("carbon-now").setup()
    end,
  },

  {
    "elkowar/yuck.vim",
    event = "BufWinEnter",
  },

  {
    "folke/which-key.nvim",
    event = "BufWinEnter",
  },

  -- Commenting this out as it seems there's already support for syntax
  -- highlighting for SuperCollider *.sc extensions.
  -- {
  --   "davidgranstrom/scnvim",
  --   event = "BufWinEnter",
  --   opts = overrides.scnvim,
  --   config = function()
  --     -- require("scnvim").setup(opts)
  --     require("scnvim").setup()
  --   end,
  -- },

  -- Commenting this out for now as it breaks `git commit` opening editor.
  -- {
  --   "samjwill/nvim-unception",
  --   event = "BufWinEnter",
  -- },

  {
    "hrsh7th/nvim-cmp",
    enabled = false,
  },

  -- {
  --   "rmagatti/auto-session",
  --   event = "VimEnter",
  --   opts = overrides.autosession,
  --   config = function(_, opts)
  --     require("auto-session").setup(opts)
  --   end,
  -- },

  -- {
  --   "lewis6991/gitsigns.nvim",
  --   event = "BufWinEnter",
  --   config = function()
  --     require("gitsigns").setup(
  --       overrides.gitsigns
  --     )
  --   end,
  -- }

  -- To make a plugin not be loaded
  -- {
  --   "NvChad/nvim-colorizer.lua",
  --   enabled = false
  -- },

}

return plugins
