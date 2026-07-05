# Install `just` separately. Optional accelerators and analyzers are documented in
# docs/ai-agent-harness.md; recipes remain useful when those tools are absent.
set shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

default:
    just --list

verify:
    & ./scripts/verify-bridge.ps1
    & ./scripts/verify-license.ps1

verify-bridge:
    & ./scripts/verify-bridge.ps1

verify-license:
    & ./scripts/verify-license.ps1

verify-apk apk expected="":
    & ./scripts/verify-apk.ps1 -ApkPath '{{apk}}' -ExpectedSha256 '{{expected}}'

checksum-apk apk:
    & ./scripts/verify-apk.ps1 -ApkPath '{{apk}}' -WriteChecksum

# Repomix is optional: npm install -g repomix
pack-context:
    repomix --config repomix.parthicle.json

# Semgrep is optional: python -m pip install semgrep
semgrep-bridge:
    semgrep scan --config auto mobile/app mobile/android/src mobile/components

# reuse-tool is optional: python -m pip install reuse
reuse-lint:
    reuse lint
