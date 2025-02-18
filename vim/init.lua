vim.cmd("source ~/.vimrc")

vim.api.nvim_create_autocmd("CmdlineLeave", {
  pattern = ":",
  callback = function()
    local cmd = vim.fn.getcmdline()
    if cmd:match("^%d+$") then
      vim.cmd("normal! zz")
    end
  end,
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "junegunn/goyo.vim" },
  { "scrooloose/nerdcommenter" },
  { "preservim/nerdtree" },  -- Updated repo for NERDTree
  { "tpope/vim-surround" },
  { "rust-lang/rust.vim" },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 }
})

vim.cmd.colorscheme "catppuccin-frappe"

-- Key mappings
local opts = { noremap = true, silent = true }

vim.keymap.set("n", "<leader>ne", ":NERDTreeToggle<CR>", opts)
