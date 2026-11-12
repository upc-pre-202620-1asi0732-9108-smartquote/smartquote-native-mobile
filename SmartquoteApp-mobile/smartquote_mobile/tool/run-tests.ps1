param(
    [ValidatePattern('^(All|US\d{2}|TS\d{2})$')][string]$Story='All',
    [ValidateSet('Unit','Integration','Android')][string]$Level='Unit',
    [string]$BackendPath='E:\smartquote-web-services',
    [string]$Device='',
    [switch]$Coverage,
    [switch]$Machine
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    if ($Level -in @('Integration','Android')) {
        $runner=Join-Path $BackendPath 'tests/run-tests.ps1'
        if (-not (Test-Path -LiteralPath $runner)) { throw "Missing backend test harness: $runner" }
        if ($Level -eq 'Android') {
            if ($Device -notmatch '^[a-zA-Z0-9._:-]+$') { throw 'Use -Device with a connected Android identifier from flutter devices. adb must be on PATH.' }
            # adb reverse sirve para emulador y teléfono; nunca expone PostgreSQL a la LAN.
            $command='$testPort=([uri]$env:SMARTQUOTE_API_URL).Port; adb -s '+$Device+' reverse "tcp:$testPort" "tcp:$testPort"; if ($LASTEXITCODE -ne 0) { throw "adb reverse failed" }; try { flutter test integration_test/core_workflow_test.dart -d '+$Device+' --dart-define="SMARTQUOTE_TEST_API_URL=$env:SMARTQUOTE_API_URL" --dart-define="SMARTQUOTE_TEST_PASSWORD=$env:SMARTQUOTE_BOOTSTRAP_PASSWORD"; if ($LASTEXITCODE -ne 0) { throw "Android integration failed" } } finally { adb -s '+$Device+' reverse --remove "tcp:$testPort" }'
        } else { $command='flutter test tool/core_api_test.dart --reporter expanded' }
        & $runner -Level Integration -ClientOnly -ClientDirectory $root -ClientCommand $command
        if ($LASTEXITCODE -ne 0) { throw 'Isolated integration runner failed.' }
        return
    }
    # Discover every local test, including future story files. Live smoke tests are opt-in.
    $files=@(Get-ChildItem -LiteralPath (Join-Path $root 'test') -File -Filter '*_test.dart' |
        Where-Object Name -ne 'live_backend_test.dart' | Sort-Object Name |
        ForEach-Object { 'test/' + $_.Name })
    if ($files.Count -eq 0) { throw 'No local Flutter tests were found.' }
    Write-Host "Selected $($files.Count) local Flutter test files." -InformationAction Continue
    $arguments=@('test')+$files
    if ($Machine) { $arguments+='--machine' } else { $arguments+=@('--reporter','expanded') }
    if ($Coverage) { $arguments+='--coverage' }
    if ($Story -ne 'All') {
        $pattern="\b$Story\b"
        $exists=$false
        foreach ($file in $files) { if ((Get-Content -Raw -LiteralPath $file) -match "(?:test|testWidgets)\(\s*'[^']*$Story\b") { $exists=$true } }
        if (-not $exists) { throw "$Story has no client test. US01 belongs to Landing Page; consult backend coverage for server-only cases." }
        $arguments+=@('--name',$pattern)
    }
    & flutter @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
} finally { Pop-Location }
