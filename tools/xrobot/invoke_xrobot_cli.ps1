[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$Command,

  [string[]]$Arguments = @(),

  [ValidateSet('auto', 'system', 'local-venv', 'temp-venv')]
  [string]$Runner = 'auto',

  [string]$ProjectRoot = '',

  [string]$LocalVenvPath = '',

  [string]$PythonCommand = 'python',

  [string]$PackageSpec = 'xrobot'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

if ([string]::IsNullOrWhiteSpace($LocalVenvPath))
{
  $LocalVenvPath = Join-Path $PSScriptRoot '.venv'
}

function Test-NativeCommandAvailable {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-VenvCommandPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$VenvRoot,

    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $scriptsDir = Join-Path $VenvRoot 'Scripts'
  foreach ($candidate in @(
      (Join-Path $scriptsDir "$Name.exe"),
      (Join-Path $scriptsDir "$Name.cmd"),
      (Join-Path $scriptsDir "$Name.ps1"),
      (Join-Path $scriptsDir $Name)))
  {
    if (Test-Path -LiteralPath $candidate)
    {
      return $candidate
    }
  }

  return $null
}

function Get-VenvPythonPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$VenvRoot
  )

  return Join-Path $VenvRoot 'Scripts\\python.exe'
}

function Assert-LastExitCode {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Action
  )

  $exitCodeVar = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
  if ($null -ne $exitCodeVar -and $exitCodeVar.Value -ne 0)
  {
    throw "$Action failed with exit code $($exitCodeVar.Value)."
  }
}

function Ensure-VenvReady {
  param(
    [Parameter(Mandatory = $true)]
    [string]$VenvRoot
  )

  if (-not (Test-NativeCommandAvailable -Name $PythonCommand))
  {
    throw "Python launcher '$PythonCommand' was not found."
  }

  if (-not (Test-Path -LiteralPath $VenvRoot))
  {
    Write-Host "[xrobot] creating virtual environment at $VenvRoot"
    & $PythonCommand -m venv $VenvRoot
    Assert-LastExitCode -Action "python -m venv"
  }

  $venvPython = Get-VenvPythonPath -VenvRoot $VenvRoot
  if (-not (Test-Path -LiteralPath $venvPython))
  {
    throw "Virtual environment is missing python.exe: $venvPython"
  }

  if (-not (Get-VenvCommandPath -VenvRoot $VenvRoot -Name $Command))
  {
    Write-Host "[xrobot] installing $PackageSpec into $VenvRoot"
    & $venvPython -m pip install --upgrade pip
    Assert-LastExitCode -Action "pip upgrade"

    & $venvPython -m pip install $PackageSpec
    Assert-LastExitCode -Action "pip install $PackageSpec"
  }
}

function New-TemporaryVenvPath {
  $tempRoot = [System.IO.Path]::GetTempPath()
  $token = [System.Guid]::NewGuid().ToString('N')
  return Join-Path $tempRoot "xrobot-cli-$token"
}

function Remove-TemporaryVenv {
  param(
    [Parameter(Mandatory = $true)]
    [string]$VenvRoot
  )

  if (-not (Test-Path -LiteralPath $VenvRoot))
  {
    return
  }

  $resolvedTarget = [System.IO.Path]::GetFullPath($VenvRoot)
  $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())

  if (-not $resolvedTarget.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase))
  {
    throw "Refusing to remove non-temp path: $resolvedTarget"
  }

  Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
}

$tempVenvPath = $null
$resolvedCommand = $null

switch ($Runner)
{
  'system'
  {
    if (-not (Test-NativeCommandAvailable -Name $Command))
    {
      throw "Command '$Command' was not found on PATH."
    }

    $resolvedCommand = $Command
  }

  'local-venv'
  {
    Ensure-VenvReady -VenvRoot $LocalVenvPath
    $resolvedCommand = Get-VenvCommandPath -VenvRoot $LocalVenvPath -Name $Command
  }

  'temp-venv'
  {
    $tempVenvPath = New-TemporaryVenvPath
    Ensure-VenvReady -VenvRoot $tempVenvPath
    $resolvedCommand = Get-VenvCommandPath -VenvRoot $tempVenvPath -Name $Command
  }

  'auto'
  {
    if (Test-NativeCommandAvailable -Name $Command)
    {
      $resolvedCommand = $Command
    }
    else
    {
      $resolvedCommand = Get-VenvCommandPath -VenvRoot $LocalVenvPath -Name $Command
      if (-not $resolvedCommand)
      {
        Ensure-VenvReady -VenvRoot $LocalVenvPath
        $resolvedCommand = Get-VenvCommandPath -VenvRoot $LocalVenvPath -Name $Command
      }
    }
  }
}

if (-not $resolvedCommand)
{
  throw "Unable to resolve command '$Command'."
}

Write-Host "[xrobot] runner: $Runner"
Write-Host "[xrobot] project root: $ProjectRoot"
Write-Host "[xrobot] command: $resolvedCommand $($Arguments -join ' ')"

Push-Location $ProjectRoot
try
{
  & $resolvedCommand @Arguments
  Assert-LastExitCode -Action $Command
}
finally
{
  Pop-Location

  if ($null -ne $tempVenvPath)
  {
    Remove-TemporaryVenv -VenvRoot $tempVenvPath
  }
}
