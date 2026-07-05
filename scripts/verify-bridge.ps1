[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

function Convert-JavaTypeToJni([string]$Type, [switch]$ReturnType) {
    $clean = ($Type -replace '\bfinal\b', '').Trim()
    $clean = $clean -replace '<.*>', ''
    $map = @{
        "void" = "V"; "boolean" = "Z"; "byte" = "B"; "char" = "C";
        "short" = "S"; "int" = "I"; "long" = "J"; "float" = "F";
        "double" = "D"; "String" = "Ljava/lang/String;"
    }
    if ($map.ContainsKey($clean)) { return $map[$clean] }
    if ($clean.EndsWith("[]")) {
        return "[" + (Convert-JavaTypeToJni $clean.Substring(0, $clean.Length - 2))
    }
    if ($clean.Contains(".")) {
        return "L" + $clean.Replace(".", "/") + ";"
    }
    return "Lorg/kde/something/$clean;"
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$cppPath = Join-Path $root "mobile/app/android.cpp"
$headerPath = Join-Path $root "mobile/app/android.h"
$javaPath = Join-Path $root "mobile/android/src/OpenFileActivity.java"
$ttsPath = Join-Path $root "mobile/android/src/ParthicleTtsController.java"
$qmlPath = Join-Path $root "mobile/app/ui/MainView.qml"

foreach ($path in @($cppPath, $headerPath, $javaPath, $ttsPath, $qmlPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "Bridge file is missing: $path" }
}

$cpp = Get-Content -LiteralPath $cppPath -Raw
$header = Get-Content -LiteralPath $headerPath -Raw
$java = Get-Content -LiteralPath $javaPath -Raw
$tts = Get-Content -LiteralPath $ttsPath -Raw
$qml = Get-Content -LiteralPath $qmlPath -Raw

$javaMethods = @{}
$javaPattern = [regex]'public\s+static\s+(?<return>[\w.<>\[\]]+)\s+(?<name>\w+)\s*\((?<params>[^)]*)\)'
foreach ($match in $javaPattern.Matches($java)) {
    $parameters = ""
    $rawParams = $match.Groups["params"].Value.Trim()
    if ($rawParams) {
        foreach ($param in ($rawParams -split ',')) {
            $parts = @($param.Trim() -split '\s+') | Where-Object { $_ -and $_ -ne "final" }
            if ($parts.Count -lt 2) { Fail "Could not parse Java parameter: $param" }
            $parameters += Convert-JavaTypeToJni $parts[$parts.Count - 2]
        }
    }
    $descriptor = "(" + $parameters + ")" + (Convert-JavaTypeToJni $match.Groups["return"].Value -ReturnType)
    $javaMethods[$match.Groups["name"].Value] = $descriptor
}

$jniPattern = [regex]::new('callStatic(?:Object)?Method(?:<[^>]+>)?\s*\(\s*"org/kde/something/FileClass"\s*,\s*"(?<name>[^"]+)"\s*,\s*"(?<descriptor>[^"]+)"', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$calls = @($jniPattern.Matches($cpp))
if ($calls.Count -lt 1) { Fail "No JNI static calls were discovered in android.cpp." }

$mismatches = New-Object System.Collections.Generic.List[string]
foreach ($call in $calls) {
    $name = $call.Groups["name"].Value
    $expected = $call.Groups["descriptor"].Value
    if (-not $javaMethods.ContainsKey($name)) {
        $mismatches.Add("C++ calls missing Java static method: $name $expected")
    } elseif ($javaMethods[$name] -ne $expected) {
        $mismatches.Add("JNI descriptor mismatch for ${name}: C++ $expected, Java $($javaMethods[$name])")
    }
}

$nativePattern = [regex]'public\s+static\s+native\s+[\w.<>\[\]]+\s+(?<name>\w+)\s*\('
foreach ($native in $nativePattern.Matches($java)) {
    $name = $native.Groups["name"].Value
    if ($cpp -notmatch [regex]::Escape("Java_org_kde_something_FileClass_$name")) {
        $mismatches.Add("Java native method has no matching C++ JNI export: $name")
    }
}

$invokables = @{}
$invokablePattern = [regex]'Q_INVOKABLE\s+[\w:&<>]+\s+(?<name>\w+)\s*\('
foreach ($item in $invokablePattern.Matches($header)) { $invokables[$item.Groups["name"].Value] = $true }
$qmlCallPattern = [regex]'uriHandler\.(?<name>\w+)\s*\('
foreach ($qmlCall in $qmlCallPattern.Matches($qml)) {
    $name = $qmlCall.Groups["name"].Value
    if (-not $invokables.ContainsKey($name)) {
        $mismatches.Add("QML calls method missing from URIHandler Q_INVOKABLE surface: $name")
    }
}

foreach ($requiredText in @("new Handler(Looper.getMainLooper())", "TextToSpeech", "void shutdown()")) {
    if (-not $tts.Contains($requiredText)) { $mismatches.Add("TTS controller missing lifecycle/thread marker: $requiredText") }
}
if ($java -notmatch 'onDestroy\s*\(\)[\s\S]*?ttsController\.shutdown\s*\(') {
    $mismatches.Add("OpenFileActivity.onDestroy does not visibly shut down the TTS controller")
}

if ($mismatches.Count -gt 0) {
    $mismatches | ForEach-Object { Write-Host "FAIL: $_" }
    Fail "Bridge verification found $($mismatches.Count) contract issue(s)."
}

Write-Host "JNI calls checked: $($calls.Count)"
Write-Host "Java static methods indexed: $($javaMethods.Count)"
Write-Host "QML URIHandler calls checked: $(@($qmlCallPattern.Matches($qml)).Count)"
Write-Host "TTS main-thread and shutdown markers: present"
Write-Host "Bridge static verification: PASS (device/runtime behavior not tested)"
