local plugins = {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    config = function()
      require "configs.conform"
    end,
  },

  -- {
  --   "neovim/nvim-lspconfig",
  --   dependencies = {
  --     -- format & linting
  --     {
  --       "jose-elias-alvarez/null-ls.nvim",
  --       config = function(_, opts)
  --         require "custom.configs.null-ls"
  --       end,
  --     },
  --   },
  --   config = function(_, opts)
  --     require "plugins.configs.lspconfig"
  --     require "custom.configs.lspconfig"
  --   end, -- Override to setup mason-lspconfig
  -- },

  -- override plugin configs
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
    "nvim-tree/nvim-tree.lua",
    opts = {
      git = {
        enable = true,
      },

      renderer = {
        highlight_git = true,
        icons = {
          show = {
            git = true,
          },
        },
      },
    },
  },

  {
    "NvChad/nvterm",
    opts = {
      terminals = {
        type_opts = {
          float = {
            relative = 'editor',
            row = 0.075,
            col = 0.125,
            width = 0.8,
            height = 0.8,
            border = "single",
          }
        }
      }
    },
    -- init = require("core.utils").load_mappings "nvterm",
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
    -- opts = overrides.comment,
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
    "elkowar/yuck.vim",
    event = "BufWinEnter",
  },

  {
    "folke/which-key.nvim",
    event = "BufWinEnter",
  },

  -- {
  --   "kevinhwang91/nvim-ufo",
  -- opts = {
  --   vim = {
  --     o = {
  --       foldcolumn = "1",
  --       foldlevel = 99,
  --       foldlevelstart = 99,
  --       foldenable = true,
  --     }
  --   },
  -- },
  --   dependencies = {
  --     {
  --       "kevinhwang91/promise-async",
  --     },
  --   },
  --   event = "BufWinEnter",
  --   -- config = function(_, opts)
  --   --   require("ufo").setup()
  --   -- end,
  -- },

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
  --   -- FIXME: Statusline currently doesn't work with NvChad, need to debug.
  --   opts = {
  --     cwd_change_handling = {
  --       pre_cwd_changed_hook = function()
  --         require("lualine").setup({
  --           options = {
  --             theme = "tokyonight",
  --           },
  --           sections = {
  --             lualine_c = {
  --               require("auto-session.lib").current_session_name
  --             },
  --           },
  --         })
  --       end,
  --       post_cwd_changed_hook = function()
  --         require("lualine").refresh()
  --       end,
  --     }
  --   },
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

  -- These are some examples, uncomment them if you want to see them work!
  -- {
  --   "neovim/nvim-lspconfig",
  --   config = function()
  --     require("nvchad.configs.lspconfig").defaults()
  --     require "configs.lspconfig"
  --   end,
  -- },
  --
  -- {
  -- 	"williamboman/mason.nvim",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"lua-language-server", "stylua",
  -- 			"html-lsp", "css-lsp" , "prettier"
  -- 		},
  -- 	},
  -- },
  --
  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}

return plugins
