#!/usr/bin/env sh
# Require visible checksum evidence in every `gh release create` command.
set -eu

payload=$(cat)
if command -v python3 >/dev/null 2>&1; then
    command_text=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))')
elif command -v python >/dev/null 2>&1; then
    command_text=$(printf '%s' "$payload" | python -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))')
else
    command_text=$payload
fi

if printf '%s' "$command_text" | grep -Eiq '(^|[;&|][[:space:]]*)gh[[:space:]]+release[[:space:]]+create([[:space:]]|$)'; then
    if [ "${PARTHICLE_RELEASE_SHA256_VERIFIED:-0}" = "1" ]; then
        exit 0
    fi
    if ! printf '%s' "$command_text" | grep -Eiq '(\.sha256|sha-?256)'; then
        printf '%s\n' 'Blocked release creation: include the verified .sha256 asset or SHA-256 evidence. Use /parthicle-release.' >&2
        exit 2
    fi
fi

exit 0
