function _tap_if_missing \
    --description "Tap Homebrew repository if not already tapped"

    set -l tap_name $argv[1]

    if test -z "$tap_name"
        echo "[WARN ] Missing tap name. Skipping."
        return 1
    end

    if not type -q brew
        echo "[ERROR] Homebrew not found. Cannot tap."
        return 1
    end

    if not contains $tap_name (brew tap)
        if functions -q log_info
            log_info "Tapping $tap_name..."
        else
            echo "[INFO ] Tapping $tap_name..."
        end

        brew tap $tap_name

        if test $status -eq 0
            if functions -q log_success
                log_success "$tap_name tapped successfully."
            else
                echo "[ OK  ] $tap_name tapped successfully."
            end
        else
            if functions -q log_error
                log_error "Failed to tap $tap_name."
            else
                echo "[ERROR] Failed to tap $tap_name."
            end
        end
    else
        if functions -q log_info
            log_info "$tap_name is already tapped. Skipping."
        else
            echo "[INFO ] $tap_name is already tapped. Skipping."
        end
    end
end