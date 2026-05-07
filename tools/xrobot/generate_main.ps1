[CmdletBinding()]
param(
  [string]$Config = 'User/xrobot.yaml',

  [string]$Output = 'User/xrobot_main.hpp',

  [string]$ConstexprOutput = '',

  [string[]]$Modules = @(),

  [string]$HardwareVariable = 'hw',

  [ValidateSet('auto', 'system', 'local-venv', 'temp-venv')]
  [string]$Runner = 'auto',

  [string]$PythonCommand = 'python',

  [string]$PackageSpec = 'xrobot'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$invokeScript = Join-Path $PSScriptRoot 'invoke_xrobot_cli.ps1'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Get-NormalizedRepoRelativePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PathValue
  )

  $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $PathValue))
  $repoRootNormalized = [System.IO.Path]::GetFullPath($repoRoot)
  $repoRootUri = New-Object System.Uri(($repoRootNormalized.TrimEnd('\') + '\'))
  $fileUri = New-Object System.Uri($fullPath)
  $relativePath = $repoRootUri.MakeRelativeUri($fileUri).ToString()
  return [System.Uri]::UnescapeDataString($relativePath).Replace('\', '/')
}

function Get-ModuleMetadataMap {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ModulesRoot
  )

  $metadataMap = @{}
  if (-not (Test-Path -LiteralPath $ModulesRoot))
  {
    return $metadataMap
  }

  Get-ChildItem -LiteralPath $ModulesRoot -Directory | ForEach-Object {
    $moduleDir = $_.FullName
    $moduleYaml = Join-Path $moduleDir 'module.yaml'
    if (-not (Test-Path -LiteralPath $moduleYaml))
    {
      return
    }

    $moduleName = $null
    $headerName = $null
    $className = $null
    Get-Content -LiteralPath $moduleYaml | ForEach-Object {
      if ($_ -match '^\s*name:\s*(.+?)\s*$')
      {
        $moduleName = $matches[1].Trim()
      }
      elseif ($_ -match '^\s*class_name:\s*(.+?)\s*$')
      {
        $className = $matches[1].Trim()
      }
      elseif ($_ -match '^\s*header:\s*(.+?)\s*$')
      {
        $headerName = $matches[1].Trim()
      }
    }

    if (-not [string]::IsNullOrWhiteSpace($moduleName) -and -not [string]::IsNullOrWhiteSpace($headerName))
    {
      $metadataMap[$moduleName] = @{
        Header = $headerName
        ClassName = $className
        ModuleDir = $moduleDir
      }
    }
  }

  return $metadataMap
}

function Get-ConfiguredModuleNames {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
  )

  $moduleNames = New-Object System.Collections.Generic.List[string]
  $inModules = $false

  foreach ($line in (Get-Content -LiteralPath $ConfigPath))
  {
    if ($line -match '^\s*modules:\s*$')
    {
      $inModules = $true
      continue
    }

    if (-not $inModules)
    {
      continue
    }

    if ($line -match '^\S')
    {
      break
    }

    if ($line -match '^\s*-\s*id:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$')
    {
      $moduleNames.Add($matches[1])
      continue
    }

    if ($line -match '^\s*name:\s*([A-Za-z_][A-Za-z0-9_\-]*)\s*$')
    {
      $moduleNames.Add($matches[1])
    }
  }

  return $moduleNames
}

function Get-ConfiguredModules {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
  )

  $modules = New-Object System.Collections.Generic.List[object]
  $inModules = $false
  $currentId = $null
  $currentName = $null

  foreach ($line in (Get-Content -LiteralPath $ConfigPath))
  {
    if ($line -match '^\s*modules:\s*$')
    {
      $inModules = $true
      continue
    }

    if (-not $inModules)
    {
      continue
    }

    if ($line -match '^\S')
    {
      break
    }

    if ($line -match '^\s*-\s*id:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$')
    {
      if (-not [string]::IsNullOrWhiteSpace($currentId) -or -not [string]::IsNullOrWhiteSpace($currentName))
      {
        $modules.Add([pscustomobject]@{
            Id = $currentId
            Name = $currentName
          })
      }

      $currentId = $matches[1]
      $currentName = $null
      continue
    }

    if ($line -match '^\s*name:\s*([A-Za-z_][A-Za-z0-9_\-]*)\s*$')
    {
      $currentName = $matches[1]
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($currentId) -or -not [string]::IsNullOrWhiteSpace($currentName))
  {
    $modules.Add([pscustomobject]@{
        Id = $currentId
        Name = $currentName
      })
  }

  return $modules
}

function Resolve-ConstexprOutputPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$GeneratedOutput
  )

  if (-not [string]::IsNullOrWhiteSpace($ConstexprOutput))
  {
    return $ConstexprOutput
  }

  $outputDirectory = Split-Path -Parent $GeneratedOutput
  if ([string]::IsNullOrWhiteSpace($outputDirectory))
  {
    return 'xrobot_constexpr.hpp'
  }

  return Join-Path $outputDirectory 'xrobot_constexpr.hpp'
}

function Convert-YamlScalarValue {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ValueText
  )

  $trimmed = $ValueText.Trim()
  if (($trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) -or ($trimmed.StartsWith("'") -and $trimmed.EndsWith("'")))
  {
    return $trimmed.Substring(1, $trimmed.Length - 2)
  }

  return $trimmed
}

function Write-ConstexprHeaderFromConfig {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
  )

  $configLines = Get-Content -LiteralPath $ConfigPath
  $namespaceName = 'XRobotProjectConstexpr'
  $includes = New-Object System.Collections.Generic.List[string]
  $constexprEntries = New-Object System.Collections.Generic.List[object]

  $section = ''
  $currentConstexprName = $null
  $currentConstexprType = $null
  $currentConstexprValue = $null
  $inIncludeList = $false

  foreach ($rawLine in $configLines)
  {
    $line = $rawLine
    if ($line -match '^\s*#')
    {
      continue
    }

    if ($line -match '^\s*constexpr_namespace:\s*(.+?)\s*$')
    {
      $namespaceName = $matches[1].Trim()
      continue
    }

    if ($line -match '^\s*constexpr_includes:\s*$')
    {
      $section = 'includes'
      $inIncludeList = $true
      continue
    }

    if ($inIncludeList -and $line -match '^\s*-\s*(.+?)\s*$')
    {
      $includes.Add($matches[1].Trim())
      continue
    }

    if ($line -match '^\s*constexprs:\s*$')
    {
      $section = 'constexprs'
      $inIncludeList = $false
      continue
    }

    if ($section -eq 'constexprs' -and $line -match '^\s{2}([A-Za-z_][A-Za-z0-9_]*)\s*:\s*$')
    {
      if ($null -ne $currentConstexprName)
      {
        $constexprEntries.Add([pscustomobject]@{
            Name = $currentConstexprName
            Type = $currentConstexprType
            Value = $currentConstexprValue
          })
      }

      $currentConstexprName = $matches[1]
      $currentConstexprType = $null
      $currentConstexprValue = $null
      continue
    }

    if ($section -eq 'constexprs' -and $line -match '^\s{4}type:\s*(.+?)\s*$')
    {
      $currentConstexprType = Convert-YamlScalarValue -ValueText $matches[1]
      continue
    }

    if ($section -eq 'constexprs' -and $line -match '^\s{4}value:\s*(.+?)\s*$')
    {
      $currentConstexprValue = $matches[1].Trim()
      continue
    }
  }

  if ($null -ne $currentConstexprName)
  {
    $constexprEntries.Add([pscustomobject]@{
        Name = $currentConstexprName
        Type = $currentConstexprType
        Value = $currentConstexprValue
      })
  }

  $outputLines = New-Object System.Collections.Generic.List[string]
  $outputLines.Add('#pragma once')
  $outputLines.Add('')

  foreach ($includeLine in $includes)
  {
    $outputLines.Add('#include ' + $includeLine)
  }

  if ($includes.Count -gt 0)
  {
    $outputLines.Add('')
  }

  $outputLines.Add("namespace $namespaceName {")
  foreach ($entry in $constexprEntries)
  {
    if ([string]::IsNullOrWhiteSpace($entry.Type) -or [string]::IsNullOrWhiteSpace($entry.Value))
    {
      throw "Incomplete constexpr entry '$($entry.Name)' in $ConfigPath"
    }

    $outputLines.Add("inline constexpr $($entry.Type) $($entry.Name) = $($entry.Value);")
  }
  $outputLines.Add("}  // namespace $namespaceName")

  $outputDir = Split-Path -Parent $OutputPath
  if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir))
  {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
  }

  Set-Content -LiteralPath $OutputPath -Value $outputLines -Encoding utf8
}

function Sync-GeneratedIncludes {
  param(
    [Parameter(Mandatory = $true)]
    [string]$GeneratedMainPath,

    [Parameter(Mandatory = $true)]
    [string]$ModulesRoot
  )

  if (-not (Test-Path -LiteralPath $GeneratedMainPath))
  {
    throw "Generated file not found: $GeneratedMainPath"
  }

  $metadataMap = Get-ModuleMetadataMap -ModulesRoot $ModulesRoot
  $lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $GeneratedMainPath)
  $includePrefix = '#include "'

  for ($index = 0; $index -lt $lines.Count; $index++)
  {
    $line = $lines[$index]
    $trimmed = $line.Trim()
    if (-not $trimmed.StartsWith('static '))
    {
      continue
    }

    $constructorLine = $trimmed
    while (-not $constructorLine.Contains('(') -and ($index + 1) -lt $lines.Count)
    {
      $index++
      $constructorLine += ' ' + $lines[$index].Trim()
    }

    if ($constructorLine -notmatch '^static\s+([A-Za-z_][A-Za-z0-9_:<>]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
    {
      continue
    }

    $generatedClassName = $matches[1]
    $instanceName = $matches[2]
    $moduleName = $instanceName
    if ($metadataMap.ContainsKey($moduleName))
    {
      $expectedHeader = $metadataMap[$moduleName].Header

      for ($includeIndex = 0; $includeIndex -lt $lines.Count; $includeIndex++)
      {
        if ($lines[$includeIndex] -eq ($includePrefix + $expectedHeader + '"'))
        {
          break
        }

        if ($lines[$includeIndex].StartsWith($includePrefix) -and $lines[$includeIndex].EndsWith('"'))
        {
          $headerCandidate = $lines[$includeIndex].Substring($includePrefix.Length)
          $headerCandidate = $headerCandidate.Substring(0, $headerCandidate.Length - 1)
          if ($headerCandidate -like '*.hpp' -and $headerCandidate -ne 'xrobot_constexpr.hpp')
          {
            $headerPath = Join-Path $metadataMap[$moduleName].ModuleDir $headerCandidate
            $includeHeaderPath = Join-Path $metadataMap[$moduleName].ModuleDir 'include'
            if ((Test-Path -LiteralPath $headerPath) -or (Test-Path -LiteralPath (Join-Path $includeHeaderPath $headerCandidate)))
            {
              $lines[$includeIndex] = $includePrefix + $expectedHeader + '"'
              break
            }
          }
        }
      }
    }
  }

  Set-Content -LiteralPath $GeneratedMainPath -Value $lines -Encoding utf8
}

function Normalize-GeneratedMainFromConfig {
  param(
    [Parameter(Mandatory = $true)]
    [string]$GeneratedMainPath,

    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$ModulesRoot
  )

  $configuredModules = @(Get-ConfiguredModules -ConfigPath $ConfigPath)
  if ($configuredModules.Count -eq 0)
  {
    return
  }

  $metadataMap = Get-ModuleMetadataMap -ModulesRoot $ModulesRoot
  $lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $GeneratedMainPath)

  $firstConfiguredModule = $configuredModules[0]
  if ([string]::IsNullOrWhiteSpace($firstConfiguredModule.Name) -or -not $metadataMap.ContainsKey($firstConfiguredModule.Name))
  {
    return
  }

  $moduleMeta = $metadataMap[$firstConfiguredModule.Name]
  $expectedHeader = $moduleMeta.Header
  $expectedClassName = $moduleMeta.ClassName
  if ([string]::IsNullOrWhiteSpace($expectedHeader) -or [string]::IsNullOrWhiteSpace($expectedClassName))
  {
    return
  }

  for ($index = 0; $index -lt $lines.Count; $index++)
  {
    if ($lines[$index] -match '^#include ".*\.hpp"$' -and $lines[$index] -ne '#include "xrobot_constexpr.hpp"')
    {
      $lines[$index] = '#include "' + $expectedHeader + '"'
      break
    }
  }

  for ($index = 0; $index -lt $lines.Count; $index++)
  {
    if ($lines[$index] -match '^\s*static\s+([A-Za-z_][A-Za-z0-9_:<>]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
    {
      $instanceName = $matches[2]
      if (-not [string]::IsNullOrWhiteSpace($firstConfiguredModule.Id))
      {
        $instanceName = $firstConfiguredModule.Id
      }
      $indent = ($lines[$index] -replace '^(\s*).*$','$1')
      $lines[$index] = "$indent" + 'static ' + $expectedClassName + ' ' + $instanceName + '('
      break
    }
  }

  Set-Content -LiteralPath $GeneratedMainPath -Value $lines -Encoding utf8
}

function Rewrite-GeneratedMainFromTemplate {
  param(
    [Parameter(Mandatory = $true)]
    [string]$GeneratedMainPath,

    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$ModulesRoot
  )

  $configuredModules = @(Get-ConfiguredModules -ConfigPath $ConfigPath)
  if ($configuredModules.Count -eq 0)
  {
    return
  }

  $firstConfiguredModule = $configuredModules[0]
  if ([string]::IsNullOrWhiteSpace($firstConfiguredModule.Name))
  {
    return
  }

  $metadataMap = Get-ModuleMetadataMap -ModulesRoot $ModulesRoot
  if (-not $metadataMap.ContainsKey($firstConfiguredModule.Name))
  {
    return
  }

  $moduleMeta = $metadataMap[$firstConfiguredModule.Name]
  $expectedHeader = $moduleMeta.Header
  $expectedClassName = $moduleMeta.ClassName
  $expectedInstanceName = $firstConfiguredModule.Id
  if ([string]::IsNullOrWhiteSpace($expectedHeader) -or
      [string]::IsNullOrWhiteSpace($expectedClassName) -or
      [string]::IsNullOrWhiteSpace($expectedInstanceName))
  {
    return
  }

  $lines = @(Get-Content -LiteralPath $GeneratedMainPath)
  $callStart = -1
  for ($index = 0; $index -lt $lines.Length; $index++)
  {
    if ($lines[$index] -match '^\s*static\s+[A-Za-z_][A-Za-z0-9_:<>]*\s+[A-Za-z_][A-Za-z0-9_]*\s*\($')
    {
      $callStart = $index
      break
    }
  }

  if ($callStart -lt 0)
  {
    throw "Unable to locate generated module construction in $GeneratedMainPath"
  }

  $callEnd = -1
  for ($index = $callStart + 1; $index -lt $lines.Length; $index++)
  {
    if ($lines[$index].Trim() -eq ');')
    {
      $callEnd = $index
      break
    }
  }

  if ($callEnd -lt 0)
  {
    throw "Unable to locate generated constructor end in $GeneratedMainPath"
  }

  $argumentLines = New-Object System.Collections.Generic.List[string]
  for ($index = $callStart + 1; $index -lt $callEnd; $index++)
  {
    $argumentLines.Add($lines[$index])
  }

  $newLines = New-Object System.Collections.Generic.List[string]
  $newLines.Add('#include "app_framework.hpp"')
  $newLines.Add('#include "libxr.hpp"')
  $newLines.Add('')
  $newLines.Add('// Module headers')
  $newLines.Add('#include "' + $expectedHeader + '"')
  $newLines.Add('#include "xrobot_constexpr.hpp"')
  $newLines.Add('')
  $newLines.Add('static void XRobotMain(LibXR::HardwareContainer &hw) {')
  $newLines.Add('  using namespace LibXR;')
  $newLines.Add('  ApplicationManager appmgr;')
  $newLines.Add('')
  $newLines.Add('  // Auto-generated module instantiations')
  $newLines.Add('  static ' + $expectedClassName + ' ' + $expectedInstanceName + '(')
  foreach ($argumentLine in $argumentLines)
  {
    $newLines.Add($argumentLine)
  }
  $newLines.Add('  );')
  $newLines.Add('')
  $newLines.Add('  while (true) {')
  $newLines.Add('    appmgr.MonitorAll();')
  $newLines.Add('    Thread::Sleep(1);')
  $newLines.Add('  }')
  $newLines.Add('}')

  Set-Content -LiteralPath $GeneratedMainPath -Value $newLines -Encoding utf8
}

$normalizedOutput = Get-NormalizedRepoRelativePath -PathValue $Output
$normalizedConfig = Get-NormalizedRepoRelativePath -PathValue $Config
$resolvedConstexprOutput = Resolve-ConstexprOutputPath -GeneratedOutput $Output
$normalizedConstexprOutput = Get-NormalizedRepoRelativePath -PathValue $resolvedConstexprOutput

$arguments = @(
  '--output', $normalizedOutput,
  '--config', $normalizedConfig,
  '--hw', $HardwareVariable
)

if ($Modules.Count -gt 0)
{
  $arguments += '--modules'
  $arguments += $Modules
}

& $invokeScript `
  -Command 'xrobot_gen_main' `
  -Arguments $arguments `
  -Runner $Runner `
  -PythonCommand $PythonCommand `
  -PackageSpec $PackageSpec

Sync-GeneratedIncludes `
  -GeneratedMainPath ([System.IO.Path]::GetFullPath((Join-Path $repoRoot $normalizedOutput))) `
  -ModulesRoot ([System.IO.Path]::GetFullPath((Join-Path $repoRoot 'Modules')))

Rewrite-GeneratedMainFromTemplate `
  -GeneratedMainPath ([System.IO.Path]::GetFullPath((Join-Path $repoRoot $normalizedOutput))) `
  -ConfigPath ([System.IO.Path]::GetFullPath((Join-Path $repoRoot $normalizedConfig))) `
  -ModulesRoot ([System.IO.Path]::GetFullPath((Join-Path $repoRoot 'Modules')))

Write-ConstexprHeaderFromConfig `
  -ConfigPath ([System.IO.Path]::GetFullPath((Join-Path $repoRoot $normalizedConfig))) `
  -OutputPath ([System.IO.Path]::GetFullPath((Join-Path $repoRoot $normalizedConstexprOutput)))
