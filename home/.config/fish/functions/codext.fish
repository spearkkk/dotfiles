function codext --description 'Start Codex in a fresh temporary workspace'
    set -l workspace (mktemp -d); or return
    command codex -C "$workspace" $argv
end
