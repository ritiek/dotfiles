local M = {}

M.treesitter = {
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
}

M.mason = {
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
}

-- git support in nvimtree
M.nvimtree = {
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
}

M.comment = {
}

M.copilot = {
  suggestion = {
    auto_trigger = true,
  },
}

M.neozoom = {
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
}

-- FIXME: Statusline currently doesn't work with NvChad, need to debug.
M.autosession = {
  cwd_change_handling = {
    pre_cwd_changed_hook = function()
      require("lualine").setup({
        options = {
          theme = "tokyonight",
        },
        sections = {
          lualine_c = {
            require("auto-session.lib").current_session_name
          },
        },
      })
    end,
    post_cwd_changed_hook = function()
      require("lualine").refresh()
    end,
  }
}

M.scnvim = {
}

M.nvterm = {
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
}

-- M.nvim_ufo = {
--   vim = {
--     o = {
--       foldcolumn = "1",
--       foldlevel = 99,
--       foldlevelstart = 99,
--       foldenable = true,
--     }
--   },
-- }

return M
