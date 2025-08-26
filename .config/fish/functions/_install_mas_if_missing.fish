function _install_mas_if_missing
    set -l app_id $argv[1]
    
    if test -z "$app_id"
        echo "[ERROR] App ID is required for mas install"
        return 1
    end
    
    # Check if mas is installed
    if not command -v mas >/dev/null 2>&1
        echo "[ERROR] mas is not installed. Install it first with: brew install mas"
        return 1
    end
    
    # Check if app is already installed
    if mas list | grep -q "^$app_id "
        echo "[ OK  ] App $app_id is already installed"
        return 0
    end
    
    echo "[INFO ] Installing App Store app: $app_id"
    if mas install $app_id
        echo "[ OK  ] Successfully installed app: $app_id"
    else
        echo "[ERROR] Failed to install app: $app_id"
        return 1
    end
end