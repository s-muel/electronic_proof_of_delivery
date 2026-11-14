[CmdletBinding()]
param(
    [ValidateSet('preview', 'live')]
    [string]$Mode = 'preview',
    [ValidateRange(1024, 65535)]
    [int]$Port = 9999,
    [string]$ServiceAccountPath,
    [switch]$AllowTestSms
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$npx = Get-Command npx.cmd -CommandType Application -ErrorAction Stop
$names = @('BAJ_SMS_MODE', 'BAJ_SMS_FIREBASE_WEB_API_KEY',
    'BAJ_SMS_SERVICE_ACCOUNT_JSON', 'BAJ_ARKESEL_API_KEY', 'BAJ_ARKESEL_SENDER_ID',
    'BAJ_SMS_ALLOW_TEST', 'BAJ_SMS_WORKER_LOCAL_URL')
$original = @{}
foreach ($name in $names) {
    $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

Push-Location -LiteralPath $projectRoot
try {
    $config = Get-Content -Raw -LiteralPath 'lib/firebase_options.dart'
    $web = [regex]::Match($config, '(?s)FirebaseOptions web\s*=\s*FirebaseOptions\((.*?)\);').Groups[1].Value
    $webKey = [regex]::Match($web, "apiKey:\s*'([^']+)'").Groups[1].Value
    if (!$webKey -or $web -notmatch "projectId:\s*'bajfreight-system'") {
        throw 'Could not find the bajfreight-system Web API key in lib/firebase_options.dart.'
    }
    $env:BAJ_SMS_FIREBASE_WEB_API_KEY = $webKey

    if (!$ServiceAccountPath -and !$env:BAJ_SMS_SERVICE_ACCOUNT_JSON) {
        $ServiceAccountPath = Read-Host 'Full path to the BAJ service-account JSON file'
    }
    if ($ServiceAccountPath) {
        $ServiceAccountPath = $ServiceAccountPath.Trim().Trim('"')
        if (!(Test-Path -LiteralPath $ServiceAccountPath -PathType Leaf)) {
            throw 'Enter the full path to the downloaded JSON file, not a folder.'
        }
        $env:BAJ_SMS_SERVICE_ACCOUNT_JSON = Get-Content -Raw -LiteralPath $ServiceAccountPath
    }
    try {
        $account = $env:BAJ_SMS_SERVICE_ACCOUNT_JSON | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw 'The BAJ service-account file is not valid JSON.'
    }
    if ($account.project_id -ne 'bajfreight-system' -or !$account.client_email -or !$account.private_key) {
        throw 'Use a service-account key for bajfreight-system.'
    }

    if ($Mode -eq 'live') {
        if ([string]::IsNullOrWhiteSpace($env:BAJ_ARKESEL_API_KEY)) {
            $secureKey = Read-Host 'BAJ Arkesel API key' -AsSecureString
            try {
                $env:BAJ_ARKESEL_API_KEY = ([System.Net.NetworkCredential]::new('', $secureKey)).Password.Trim()
            } finally {
                $secureKey.Dispose()
            }
        }
        if ([string]::IsNullOrWhiteSpace($env:BAJ_ARKESEL_SENDER_ID)) {
            $env:BAJ_ARKESEL_SENDER_ID = Read-Host 'Approved BAJ Arkesel sender ID'
        }
        if ([string]::IsNullOrWhiteSpace($env:BAJ_ARKESEL_API_KEY)) {
            throw 'The BAJ Arkesel API key is required in live mode.'
        }
        if ($env:BAJ_ARKESEL_SENDER_ID.Trim() -cnotmatch '^[A-Za-z0-9]{1,11}$') {
            throw 'The current SMS function requires an approved sender ID of 1–11 letters or digits.'
        }
    }
    $env:BAJ_SMS_MODE = $Mode
    $env:BAJ_SMS_WORKER_LOCAL_URL = "http://localhost:$Port"
    $env:BAJ_SMS_ALLOW_TEST = if ($AllowTestSms) { 'true' } else { 'false' }
    Write-Host "Starting BAJ SMS in $Mode mode at http://localhost:$Port"
    $testDefine = if ($AllowTestSms) { ' --dart-define=BAJ_SMS_ALLOW_TEST=true' } else { '' }
    Write-Host "In another terminal: flutter run -d chrome --dart-define=SMS_FUNCTION_BASE_URL=http://localhost:$Port$testDefine"
    & $npx.Source netlify-cli functions:serve --port $Port
    if ($LASTEXITCODE -ne 0) { throw "Netlify exited with code $LASTEXITCODE." }
} finally {
    foreach ($name in $names) {
        [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process')
    }
    Pop-Location
}
