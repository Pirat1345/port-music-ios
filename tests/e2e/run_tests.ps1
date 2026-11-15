<#
.SYNOPSIS
    Runs the Port Music v2 Native iOS App E2E Test Suite on Windows.
.DESCRIPTION
    Executes all 4 test tiers (267 automated tests) via Node.js runner.
.PARAMETER Tier
    Specify a specific tier to run (1, 2, 3, or 4).
.PARAMETER Tap
    Output results in Test Anything Protocol (TAP) format.
.PARAMETER Json
    Output results in structured JSON format.
.PARAMETER Detailed
    Enable verbose per-test output.
.PARAMETER Filter
    Filter tests by regular expression.
#>
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("1", "2", "3", "4")]
    [string]$Tier,

    [switch]$Tap,
    [switch]$Json,
    [switch]$Detailed,
    [string]$Filter
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RunnerScript = Join-Path $ScriptDir "runner.js"

if (-not (Test-Path $RunnerScript)) {
    Write-Error "Test runner not found at: $RunnerScript"
    exit 1
}

$NodeArgs = @($RunnerScript)

if ($Tier) {
    $NodeArgs += "--tier=$Tier"
}
if ($Tap) {
    $NodeArgs += "--tap"
}
if ($Json) {
    $NodeArgs += "--json"
}
if ($Detailed -or $PSBoundParameters.ContainsKey('Verbose')) {
    $NodeArgs += "--verbose"
}
if ($Filter) {
    $NodeArgs += "--filter=$Filter"
}

Write-Host "Running Port Music v2 iOS E2E Test Suite..." -ForegroundColor Cyan
& node $NodeArgs
exit $LASTEXITCODE
