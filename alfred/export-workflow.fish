#!/usr/bin/env fish

function usage
    echo "Usage: fish alfred/export-workflow.fish <workflow-id> [export-name]"
    echo "Example: fish alfred/export-workflow.fish user.workflow.6E8AFCEC-6AD8-4B67-A2D9-BEAFC0401716 pomo"
end

set -l workflow_id $argv[1]
set -l export_name $argv[2]

if test -z "$workflow_id"
    usage
    exit 2
end

if not string match -rq '^user\.workflow\.[A-F0-9-]+$' "$workflow_id"
    echo "Invalid Alfred workflow ID: $workflow_id" >&2
    exit 2
end

set -l script_dir (cd (dirname (status --current-filename)); and pwd)
set -l source_dir "$HOME/.config/alfred/Alfred.alfredpreferences/workflows/$workflow_id"

if test -z "$export_name"
    set export_name $workflow_id
end

if not string match -rq '^[A-Za-z0-9._-]+$' "$export_name"
    echo "Export name may contain only letters, numbers, dots, underscores, and hyphens." >&2
    exit 2
end

set -l output_file "$script_dir/workflows/$export_name.alfredworkflow"

if not test -d "$source_dir"
    echo "Workflow source not found: $source_dir" >&2
    exit 1
end

if not test -f "$source_dir/info.plist"
    echo "Workflow source has no info.plist: $source_dir" >&2
    exit 1
end

if test -e "$output_file"
    echo "Export already exists: $output_file" >&2
    exit 1
end

if not type -q zip
    echo "zip is required to create an .alfredworkflow archive." >&2
    exit 1
end

set -l secret_pattern '(api[_-]?key|secret|token|password|passwd|authorization|bearer|private[_-]?key|BEGIN [A-Z ]*PRIVATE)'
if type -q rg
    if rg -n -i --hidden -g '!**/*.png' -g '!**/*.gif' -g '!**/*.icns' -g '!**/*.pdf' "$secret_pattern" "$source_dir"
        echo "Potential secret found. Review and remove it before exporting." >&2
        exit 1
    end
end

pushd "$source_dir" >/dev/null
command zip -qr "$output_file" . -x '*.DS_Store'
set -l zip_status $status
popd >/dev/null

if test $zip_status -ne 0
    rm -f "$output_file"
    echo "Failed to export workflow: $workflow_id" >&2
    exit 1
end

echo "Exported: $output_file"
