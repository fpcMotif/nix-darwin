-- leader key
vim.g.mapleader = " "
vim.g.maplocalleader = ","
vim.keymap.set("", "<Space>", "<Nop>")

-- special keys
vim.keymap.set({ "n", "v" }, ";", ":")
vim.keymap.set("", "<Tab>", "<Nop>") -- Will be handled in `plugins/completion.lua`

-- reserved prefixes used by this config
vim.keymap.set("", "s", "<Nop>")
vim.keymap.set("", "S", "<Nop>")

-- move lines with Control + vim directions
vim.keymap.set("n", "<C-k>", 'line(".")>1 ? ":m .-2<CR>" : ""', { expr = true, silent = true })
vim.keymap.set("n", "<C-j>", 'line(".")<line("$") ? ":m .+1<CR>" : ""', { expr = true, silent = true })
vim.keymap.set("v", "<C-k>", 'line(".")>1 ? ":m \'<-2<CR>gv" : ""', { expr = true, silent = true })
vim.keymap.set("v", "<C-j>", 'line(".")<line("$") ? ":m \'>+1<CR>gv" : ""', { expr = true, silent = true })

vim.keymap.set("c", "<C-k>", "<Up>")
vim.keymap.set("c", "<C-j>", "<Down>")

-- yank, paste
vim.keymap.set("x", "p", '"_dP')
vim.keymap.set("x", "P", '"_dp')
vim.keymap.set({ "n", "v" }, "x", '"_x')

vim.keymap.set("n", "dw", 'vb"_d')
vim.keymap.set("n", "cw", 'vb"_c')

-- search keys
vim.keymap.set("n", "N", "'Nn'[v:searchforward]", { expr = true })
vim.keymap.set("x", "N", "'Nn'[v:searchforward]", { expr = true })
vim.keymap.set("o", "N", "'Nn'[v:searchforward]", { expr = true })
vim.keymap.set("n", "n", "'nN'[v:searchforward]", { expr = true })
vim.keymap.set("x", "n", "'nN'[v:searchforward]", { expr = true })
vim.keymap.set("o", "n", "'nN'[v:searchforward]", { expr = true })

vim.keymap.set("v", "N", function() require("utils").search(false) end)
vim.keymap.set("v", "n", function() require("utils").search(true) end)

-- tab management
vim.keymap.set({ "n", "v" }, "tt", ":tabe<CR>", { silent = true })
vim.keymap.set({ "n", "v" }, "tT", ":tab split<CR>", { silent = true })
vim.keymap.set({ "n", "v" }, "tp", ":-tabnext<CR>", { silent = true })
vim.keymap.set({ "n", "v" }, "tn", ":+tabnext<CR>", { silent = true })
vim.keymap.set({ "n", "v" }, "tP", ":-tabmove<CR>", { silent = true })
vim.keymap.set({ "n", "v" }, "tN", ":+tabmove<CR>", { silent = true })

-- other keys
vim.keymap.set("n", "<C-S-M-s>", ":up<CR>", { silent = true })
vim.keymap.set("i", "<C-S-M-s>", "<Esc>:up<CR>a", { silent = true })
vim.keymap.set("v", "<C-S-M-s>", "<Esc>:up<CR>", { silent = true })

vim.keymap.set("", "<C-a>", "ggVG$")
vim.keymap.set({ "i", "v" }, "<C-a>", "<Esc>ggVG$")

vim.keymap.set("", "<C-r>", ":filetype detect<CR>", { silent = true })
vim.keymap.set("i", "<C-r>", "<Esc>:filetype detect<CR>a", { silent = true })

vim.keymap.set("", "<C-->", "<C-a>")
vim.keymap.set({ "i", "v" }, "<C-->", "<Esc><C-a>a")
vim.keymap.set("", "<C-=>", "<C-x>")
vim.keymap.set({ "i", "v" }, "<C-=>", "<Esc><C-x>a")

vim.keymap.set("n", "<leader>`", function() require("lazy").profile() end)
