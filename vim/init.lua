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
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
    { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" }, config = function()
      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/" },
          mappings = {
            i = {
              ["<C-j>"] = "move_selection_next",
              ["<C-k>"] = "move_selection_previous",
            },
          },
        },
		pickers = {
			find_files = {
				hidden = true, -- Show hidden files
			},
	    },
      })
    end
  }
})

vim.cmd.colorscheme "catppuccin-frappe"

-- Key mappings
local opts = { noremap = true, silent = true }

vim.keymap.set("n", "<leader>ne", ":NERDTreeToggle<CR>", opts)
vim.g.NERDTreeShowHidden = 1
vim.g.NERDTreeMapOpen = 'go'
vim.o.timeoutlen = 300

-- Telescope
local builtin = require("telescope.builtin")

vim.keymap.set("n", "<leader>fg", builtin.live_grep, opts)
vim.keymap.set("n", "<leader>ff", builtin.find_files, opts)
vim.keymap.set("n", "<leader>fb", builtin.buffers, opts)
vim.keymap.set("n", "<leader>fh", builtin.help_tags, opts)

-- Move lines up and down in normal mode
vim.keymap.set("n", "<C-j>", ":m .+1<CR>==", opts)
vim.keymap.set("n", "<C-k>", ":m .-2<CR>==", opts)
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", opts)
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", opts)

-- Move lines up and down in insert mode
vim.keymap.set("i", "<C-j>", "<Esc>:m .+1<CR>==gi", opts)
vim.keymap.set("i", "<C-k>", "<Esc>:m .-2<CR>==gi", opts)
vim.keymap.set("i", "<A-j>", "<Esc>:m .+1<CR>==gi", opts)
vim.keymap.set("i", "<A-k>", "<Esc>:m .-2<CR>==gi", opts)

-- Keep cursor at the end after yanking in visual mode
vim.keymap.set("v", "y", "y`]", opts)

