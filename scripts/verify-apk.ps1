[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApkPath,

    [string]$ExpectedSha256 = "",

    [string]$RequireAbi = "arm64-v8a",

    [switch]$WriteChecksum
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    Fail "APK not found: $ApkPath"
}

$apk = Get-Item -LiteralPath $ApkPath
$fullPath = $apk.FullName
$stream = [System.IO.File]::OpenRead($fullPath)
try {
    $magic = New-Object byte[] 4
    if ($stream.Read($magic, 0, 4) -ne 4 -or $magic[0] -ne 0x50 -or $magic[1] -ne 0x4B) {
        Fail "File does not have ZIP/APK magic: $fullPath"
    }
} finally {
    $stream.Dispose()
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($fullPath)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName })
    $abiPrefix = "lib/$RequireAbi/"
    if (-not ($entries | Where-Object { $_.StartsWith($abiPrefix, [System.StringComparison]::Ordinal) })) {
        Fail "Required ABI directory is absent from APK: $abiPrefix"
    }
    $libCpp = "${abiPrefix}libc++_shared.so"
    if ($entries -notcontains $libCpp) {
        Fail "Required NDK runtime is absent from APK: $libCpp"
    }
} finally {
    $archive.Dispose()
}

$sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToUpperInvariant()
if ($ExpectedSha256) {
    $expected = (($ExpectedSha256 -split '\s+')[0] -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
    if ($expected.Length -ne 64) {
        Fail "Expected SHA-256 must contain exactly 64 hexadecimal characters."
    }
    if ($sha256 -ne $expected) {
        Fail "SHA-256 mismatch. Expected $expected, got $sha256"
    }
}

$checksumPath = "$fullPath.sha256"
if ($WriteChecksum) {
    "$sha256  $($apk.Name)" | Set-Content -LiteralPath $checksumPath -Encoding ASCII
}

$signatureStatus = "not checked (apksigner unavailable)"
$apksigner = Get-Command apksigner, apksigner.bat -ErrorAction SilentlyContinue | Select-Object -First 1
if ($apksigner) {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $signatureOutput = & $apksigner.Source verify --print-certs $fullPath 2>&1
    $signatureExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    if ($signatureExitCode -ne 0) {
        $signatureOutput | Write-Host
        Fail "apksigner verification failed."
    }
    $signatureStatus = "verified with apksigner"
    $signatureOutput | ForEach-Object { Write-Host "SIGNATURE: $_" }
}

$applicationId = "not checked (apkanalyzer unavailable)"
$apkanalyzer = Get-Command apkanalyzer, apkanalyzer.bat -ErrorAction SilentlyContinue | Select-Object -First 1
if ($apkanalyzer) {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $idOutput = & $apkanalyzer.Source manifest application-id $fullPath 2>&1
    $analyzerExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    if ($analyzerExitCode -ne 0) {
        $applicationId = "not checked (apkanalyzer failed with exit $analyzerExitCode)"
        $idOutput | ForEach-Object { Write-Warning "apkanalyzer: $_" }
    } else {
        $applicationId = ($idOutput | Select-Object -First 1).ToString().Trim()
    }
}

Write-Host "APK: $fullPath"
Write-Host "Bytes: $($apk.Length)"
Write-Host "ABI: $RequireAbi"
Write-Host "NDK runtime: lib/$RequireAbi/libc++_shared.so"
Write-Host "SHA-256: $sha256"
Write-Host "Signature: $signatureStatus"
Write-Host "Application ID: $applicationId"
if ($WriteChecksum) {
    Write-Host "Checksum file: $checksumPath"
}
