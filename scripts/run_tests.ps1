param(
    [string]$GodotExecutable = ""
)

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $godotCommand) {
        $GodotExecutable = $godotCommand.Source
    } else {
        $steamGodot = "E:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
        if (Test-Path -LiteralPath $steamGodot) {
            $GodotExecutable = $steamGodot
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GodotExecutable) -or -not (Test-Path -LiteralPath $GodotExecutable)) {
    throw "Godot executable not found. Pass -GodotExecutable with a Godot 4.7 path."
}

$tests = @(
    "res://tests/territory_prototype_smoke.gd",
	"res://tests/territory_performance_probe.gd",
	"res://tests/phase_b_prototype_smoke.gd",
	"res://tests/phase_b_navigation_probe.gd",
	"res://tests/phase_b_performance_probe.gd"
)

$logDirectory = Join-Path $projectRoot ".godot"
if (-not (Test-Path -LiteralPath $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
}

foreach ($test in $tests) {
    Write-Host "Running $test"
    $testName = [System.IO.Path]::GetFileNameWithoutExtension($test)
    $logPath = Join-Path $logDirectory "$testName.log"
    $arguments = @(
        "--headless",
        "--path", $projectRoot,
        "--audio-driver", "Dummy",
        "--log-file", $logPath,
        "--script", $test
    )
    $process = Start-Process `
        -FilePath $GodotExecutable `
        -ArgumentList $arguments `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    Get-Content -Encoding utf8 -LiteralPath $logPath
    if ($process.ExitCode -ne 0) {
        exit $process.ExitCode
    }
}

Write-Host "All Elemental prototype tests passed."
