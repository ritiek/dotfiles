local plugins = {
  -- FIXME: Are we using this?
  -- {
  --   "stevearc/conform.nvim",
  --   -- event = 'BufWritePre', -- uncomment for format on save
  --   config = function()
  --     require "configs.conform"
  --   end,
  -- },

  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- lua stuff
        "lua-language-server",
        "stylua",

        -- web dev stuff
        "css-lsp",
        "html-lsp",
        "typescript-language-server",
        "deno",
        "prettier",

        -- c/cpp stuff
        "clangd",
        "clang-format",

        -- python stuff
        "python-lsp-server",

        -- rust stuff
        "rust-analyzer",
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- format & linting
      -- {
      --   "jose-elias-alvarez/null-ls.nvim",
      --   config = function(_, opts)
      --     require "custom.configs.null-ls"
      --   end,
      -- },
    },
    config = function()
      require("nvchad.configs.lspconfig").defaults()
      require "configs.lspconfig"
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim",
        "lua",
        "html",
        "css",
        "javascript",
        "typescript",
        "tsx",
        "c",
        "python",
        "rust",
        "markdown",
        "markdown_inline",
        "svelte",
      },
      indent = {
        enable = true,
        -- disable = {
        --   "python"
        -- },
      },
      highlight = {
        enable = true,
      },
    },
  },

  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = {
      suggestion = {
        auto_trigger = true,
      },
    }
  },

  {
    "nyngwang/NeoZoom.lua",
    event = "BufWinEnter",
    opts = {
      winopts = {
        offset = {
          -- NOTE: you can omit `top` and/or `left` to center the floating window.
          top = 0.06,
          left = 0.03,
          width = 200,
          height = 0.85,
        },
        -- NOTE: check :help nvim_open_win() for possible border values.
        border = "single",
      },
      exclude_buftypes = {
        -- "terminal",
      },
    },
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
    "debugloop/telescope-undo.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    event = "BufWinEnter",
  },

  {
    "ThePrimeagen/harpoon",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
  },

  {
    "elkowar/yuck.vim",
    event = "BufWinEnter",
  },

  {
    "hrsh7th/nvim-cmp",
    enabled = false,
  },

  {
    "nvzone/typr",
    dependencies = "nvzone/volt",
    opts = {},
    cmd = { "Typr", "TyprStats" },
  },

  {
    "cappyzawa/trim.nvim",
    opts = {},
  },
  -- {
  --   "ojroques/nvim-osc52",
  -- }

  -- {
  --   "lewis6991/gitsigns.nvim",
  --   event = "BufWinEnter",
  --   config = function()
  --     require("gitsigns").setup({
  --       numhl = true
  --     })
  --     -- local gitsigns = require("gitsigns")
  --     -- gitsigns.setup()
  --     -- gitsigns.toggle_numhl()
  --   end,
  -- }
}

return plugins
