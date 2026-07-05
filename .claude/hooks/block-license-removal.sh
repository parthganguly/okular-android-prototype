#!/usr/bin/env sh
# License writes need explicit user approval. Scope the environment override to one invocation.
set -eu

[ "${PARTHICLE_LICENSE_EDIT_CONFIRMED:-0}" = "1" ] && exit 0

payload=$(cat)
extract_paths() {
    script='import json,sys
data=json.load(sys.stdin).get("tool_input", {})
def walk(value):
    if isinstance(value, dict):
        for key,item in value.items():
            if key in ("file_path", "notebook_path", "path") and isinstance(item,str): print(item)
            walk(item)
    elif isinstance(value,list):
        for item in value: walk(item)
walk(data)'
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$payload" | python3 -c "$script"
    elif command -v python >/dev/null 2>&1; then
        printf '%s' "$payload" | python -c "$script"
    else
        printf '%s' "$payload"
    fi
}

paths=$(extract_paths | tr '\\' '/')
if printf '%s\n' "$paths" | grep -Eiq '(^|/)(LICENSES/|COPYING([^/]*$|/)|LICENSE([^/]*$|/)|ATTRIBUTION\.md$|REUSE\.toml$|\.reuse/)'; then
    printf '%s\n' 'Blocked license/attribution edit. Obtain explicit user approval, then retry once with PARTHICLE_LICENSE_EDIT_CONFIRMED=1.' >&2
    exit 2
fi

# Bash has no file_path field, so also catch common write forms that name a
# protected file. Read-only commands such as git diff, grep, and cat remain usable.
if command -v python3 >/dev/null 2>&1; then
    command_text=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))')
elif command -v python >/dev/null 2>&1; then
    command_text=$(printf '%s' "$payload" | python -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))')
else
    command_text=$payload
fi

if printf '%s' "$command_text" | grep -Eiq '(LICENSES[/\\]|COPYING|LICENSE([^[:alpha:]]|$)|ATTRIBUTION\.md|REUSE\.toml|\.reuse[/\\])' \
    && printf '%s' "$command_text" | grep -Eiq '(^|[;&|][[:space:]]*)(rm|mv|cp|install|touch|truncate|sed[[:space:]]+-i|perl[[:space:]]+-pi|Set-Content|Add-Content|Out-File|Remove-Item|Move-Item|Copy-Item|Rename-Item)([[:space:]]|$)|>{1,2}'; then
    printf '%s\n' 'Blocked shell edit to a license/attribution path. Obtain explicit user approval, then retry once with PARTHICLE_LICENSE_EDIT_CONFIRMED=1.' >&2
    exit 2
fi

exit 0
