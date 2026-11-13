$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

if (-not (Test-Path -LiteralPath 'android/key.properties')) {
    throw 'Release signing requires android/key.properties. See android/key.properties.example.'
}

$taskPreviousJavaHome = $env:JAVA_HOME
if (Test-Path -LiteralPath 'C:/Program Files/Android/Android Studio/jbr/bin/java.exe') {
    $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
}
$taskPreviousJavaOptions = $env:JAVA_TOOL_OPTIONS
try {
    # Windows Java socket paths must stay short, including when run in a sandbox.
    $taskSocketDirectory = Join-Path $PSScriptRoot 'build/java-tmp'
    New-Item -ItemType Directory -Force -Path $taskSocketDirectory | Out-Null
    $env:JAVA_TOOL_OPTIONS = "$taskPreviousJavaOptions `"-Djdk.net.unixdomain.tmpdir=$taskSocketDirectory`""
    flutter build appbundle --release --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Play Store bundle build failed.' }
    $taskBundlePath = Join-Path $PSScriptRoot 'build/app/outputs/bundle/release/app-release.aab'
    if (-not (Test-Path -LiteralPath $taskBundlePath)) { throw 'App bundle was not produced.' }
    Write-Output "Signed Play Store bundle: $taskBundlePath"
} finally {
    $env:JAVA_TOOL_OPTIONS = $taskPreviousJavaOptions
    $env:JAVA_HOME = $taskPreviousJavaHome
}
