-- Extend the C/C++ pack with the existing cross-compiler allowlist.
return {
  {
    "AstroNvim/astrolsp",
    opts = {
      config = {
        clangd = {
          on_attach = function(_, bufnr)
            -- Preserve the parameter/type hints configured in clangd/config.yaml.
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          end,
          cmd = {
            "clangd",
            "--query-driver=/usr/bin/gcc,/usr/bin/g++,/opt/toolchains/**/bin/*gcc,/opt/toolchains/**/bin/*g++",
          },
        },
      },
    },
  },
}
