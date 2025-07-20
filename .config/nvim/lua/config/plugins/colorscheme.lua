return {
	{
		"tinted-theming/tinted-nvim",
    priority = 1000,
		config = function()
			vim.cmd([[colorscheme tinted-nvim-colors-file]])
		end
	}
}
