function l --description 'Customized ls'
     eza -l --hyperlink -a -s=modified --group-directories-first --header -m --time-style=long-iso --git $argv
end
