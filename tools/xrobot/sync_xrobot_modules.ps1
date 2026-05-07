[CmdletBinding()]
param(
  [string]$ModulesConfig = 'Modules/modules.yaml',

  [string]$SourcesConfig = 'Modules/sources.yaml',

  [string]$ModulesDirectory = 'Modules',

  [ValidateSet('auto', 'system', 'local-venv', 'temp-venv')]
  [string]$Runner = 'auto',

  [string]$PythonCommand = 'python',

  [string]$PackageSpec = 'xrobot'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$invokeScript = Join-Path $PSScriptRoot 'invoke_xrobot_cli.ps1'
$arguments = @('--config', $ModulesConfig, '--directory', $ModulesDirectory)

if (Test-Path -LiteralPath $SourcesConfig)
{
  $arguments += '--sources'
  $arguments += $SourcesConfig
}
else
{
  Write-Warning "Source index not found: $SourcesConfig. Falling back to xrobot defaults."
}

& $invokeScript `
  -Command 'xrobot_init_mod' `
  -Arguments $arguments `
  -Runner $Runner `
  -PythonCommand $PythonCommand `
  -PackageSpec $PackageSpec
