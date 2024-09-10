local configs = require "nvchad.configs.lspconfig"

local on_attach = configs.on_attach
local on_init = configs.on_init
local capabilities = configs.capabilities

local lspconfig = require "lspconfig"
local servers = {
  "html",
  "cssls",
  "ts_ls",
  "clangd",
  "pylsp",
  "rust_analyzer",
}

-- lsps with default config
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_init = on_init,
    on_attach = on_attach,
    capabilities = capabilities,
  }
end

-- python
lspconfig.pylsp.setup {
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          ignore = true,
          maxLineLength = 120,
        },
      },
    },
  },
}

-- typescript
lspconfig.ts_ls.setup {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
}

local telescope = require "telescope.builtin"
-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set("n", "<space>e", vim.diagnostic.open_float)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }

    opts["desc"] = "Lsp hover"
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

    opts["desc"] = "Lsp implementation"
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)

    -- Messes when navigating to pane Up.
    -- opts["desc"] = "Lsp signature help"
    -- vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)

    opts["desc"] = "Lsp add workspace folder"
    vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, opts)

    opts["desc"] = "Lsp remove workspace folder"
    vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, opts)

    opts["desc"] = "Lsp list workspace folders"
    vim.keymap.set("n", "<space>wl", function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)

    opts["desc"] = "Lsp rename"
    vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)

    opts["desc"] = "Lsp code action"
    vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)

    opts["desc"] = "Lsp format"
    vim.keymap.set("n", "<space>f", function()
      vim.lsp.buf.format { async = true }
    end, opts)

    vim.keymap.set("n", "gV", function()
      require("telescope.builtin").lsp_definitions { jump_type = "vsplit" }
    end, { desc = "Lsp Go to definition (vsplit)" })

    vim.keymap.set("n", "gS", function()
      require("telescope.builtin").lsp_definitions { jump_type = "split" }
    end, { desc = "Lsp Go to definition (split)" })

    opts["desc"] = "Lsp Go to declaration"
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

    opts["desc"] = "Lsp Go to definition"
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)

    opts["desc"] = "Lsp type defintion"
    vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, opts)

    opts["desc"] = "Lsp Show references"
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)

    opts["desc"] = "Lsp Show references (Telescope)"
    vim.keymap.set("n", "gR", telescope.lsp_references, opts)
  end,
})
