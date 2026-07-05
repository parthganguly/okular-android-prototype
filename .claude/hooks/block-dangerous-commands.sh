#!/usr/bin/env sh
# Claude Code PreToolUse hook. Exit 2 blocks the tool call and returns stderr.
set -eu

payload=$(cat)

extract_command() {
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))'
    elif command -v python >/dev/null 2>&1; then
        printf '%s' "$payload" | python -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))'
    else
        # Conservative fallback: scan the complete hook payload when Python is absent.
        printf '%s' "$payload"
    fi
}

command_text=$(extract_command)

scan() {
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$command_text" | python3 -c 'import re,sys
s=sys.stdin.read()
patterns=[
 (r"(?:^|[;&|]\s*)rm\s+-(?:[^\s]*r[^\s]*f|[^\s]*f[^\s]*r)\b", "rm -rf"),
 (r"\bgit\s+push\b[^\n;&|]*(?:--force(?:-with-lease)?\b|\s-f(?:\s|$))", "forced git push"),
 (r"\bgh\s+release\s+delete\b", "gh release delete"),
 (r"\bcurl\b[^\n|]*\|\s*(?:sudo\s+)?(?:ba|z|k)?sh\b", "curl piped to a shell"),
 (r"\b(?:Invoke-WebRequest|iwr)\b[^\n|]*\|\s*(?:Invoke-Expression|iex)\b", "Invoke-WebRequest piped to iex"),
]
for pattern,label in patterns:
    if re.search(pattern,s,re.I):
        print(label)
        raise SystemExit(0)
raise SystemExit(1)'
    elif command -v python >/dev/null 2>&1; then
        printf '%s' "$command_text" | python -c 'import re,sys
s=sys.stdin.read()
patterns=[
 (r"(?:^|[;&|]\s*)rm\s+-(?:[^\s]*r[^\s]*f|[^\s]*f[^\s]*r)\b", "rm -rf"),
 (r"\bgit\s+push\b[^\n;&|]*(?:--force(?:-with-lease)?\b|\s-f(?:\s|$))", "forced git push"),
 (r"\bgh\s+release\s+delete\b", "gh release delete"),
 (r"\bcurl\b[^\n|]*\|\s*(?:sudo\s+)?(?:ba|z|k)?sh\b", "curl piped to a shell"),
 (r"\b(?:Invoke-WebRequest|iwr)\b[^\n|]*\|\s*(?:Invoke-Expression|iex)\b", "Invoke-WebRequest piped to iex"),
]
for pattern,label in patterns:
    if re.search(pattern,s,re.I):
        print(label)
        raise SystemExit(0)
raise SystemExit(1)'
    else
        printf '%s' "$command_text" | grep -Eiq 'rm[[:space:]]+-rf|git[[:space:]]+push.*--force|gh[[:space:]]+release[[:space:]]+delete|curl.*\|.*(ba)?sh|Invoke-WebRequest.*\|.*iex'
    fi
}

if blocked=$(scan); then
    printf 'Blocked dangerous command (%s). Use a reversible, scoped alternative.\n' "${blocked:-matched policy}" >&2
    exit 2
fi

exit 0
