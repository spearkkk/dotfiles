function l --description 'List files with eza when available'
    if type -q eza
        eza -l --hyperlink -a -s=modified --group-directories-first --header -m --time-style=long-iso --git $argv
    else
        if functions -q log_warn
            log_warn "eza not installed. Falling back to ls."
        end

        command ls -la $argv
    end
end
