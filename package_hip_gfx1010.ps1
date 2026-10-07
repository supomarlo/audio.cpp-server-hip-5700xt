#requires -Version 5.1
<#
.SYNOPSIS
  One-click self-contained HIP package builder for the RX 5700 XT (gfx1010).

.DESCRIPTION
  Builds audiocpp_server from ./audio.cpp using the rocBLAS GEMM path (hipBLASLt ships
  no gfx1010 kernels) and assembles a runnable package under ./dist/<PackageName>/ that
  bundles everything the target machine needs, so it does NOT need the ROCm SDK:

    - audiocpp_server.exe            (deployment build: model_specs embedded)
    - ROCm runtime DLLs + MSVC CRT   (dependency-walked: amdhip64/amd_comgr/hipblas/rocblas + CRT)
    - rocblas\library\               (Tensile kernels for -GpuTargets + fallback)
    - model_specs\                   (also copied on disk, in addition to the embedded copy)

  The target machine only needs a normal AMD Adrenalin driver.

.PARAMETER RocmPath
  ROCm install used to build and to source the runtime DLLs / kernels. Defaults to
  HIP_PATH/ROCM_PATH, else the newest install under %ProgramFiles%\AMD\ROCm.
.PARAMETER GpuTargets
  Semicolon-separated gfx archs (default gfx1010 for the 5700 XT).
.PARAMETER PackageName
  Folder name created under ./dist. Defaults to audio.cpp-server-hip-gfx1010_<Version>.
.PARAMETER Version
  Version suffix for the artifact name. Defaults to the upstream audio.cpp nearest git tag
  (e.g. v0.8.2-audio8-perf-hotfix).
.PARAMETER MsvcToolset
  MSVC toolset version prefix required by ROCm HIP clang (default 14.44).
.PARAMETER Jobs
  Build parallelism (default = logical CPU count).
.PARAMETER SkipBuild
  Only re-assemble the package from the existing build output.
.PARAMETER NoEmbedModelSpecs
  Do not compile model_specs into the exe (then model_specs\ on disk is required).
.PARAMETER Zip
  Also produce ./dist/<PackageName>.zip.
#>
[CmdletBinding()]
param(
    [string]$RocmPath    = "",
    [string]$GpuTargets  = "gfx1010",
    [string]$PackageName = "",
    [string]$Version     = "",
    [string]$MsvcToolset = "14.44",
    [int]$Jobs           = 0,
    [switch]$SkipBuild,
    [switch]$NoEmbedModelSpecs,
    [switch]$Zip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Checked {
    param([string]$FilePath, [string[]]$Arguments = @())
    Write-Host "> $FilePath $($Arguments -join ' ')"
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $FilePath $($Arguments -join ' ')" }
}

function Get-DllDependencies {
    param([string]$Path)
    $lines = & dumpbin /DEPENDENTS $Path 2>$null
    foreach ($line in $lines) {
        if ($line -match '^\s+([A-Za-z0-9_.\-]+\.dll)\s*$') { $matches[1] }
    }
}

# ----- paths -----
$ProjectRoot = $PSScriptRoot

# Resolve the ROCm install: -RocmPath, else HIP_PATH/ROCM_PATH, else the newest under Program Files.
if ($RocmPath -eq "") {
    if ($env:HIP_PATH)        { $RocmPath = $env:HIP_PATH.TrimEnd('\') }
    elseif ($env:ROCM_PATH)   { $RocmPath = $env:ROCM_PATH.TrimEnd('\') }
    else {
        $found = @(Get-ChildItem (Join-Path $env:ProgramFiles "AMD\ROCm\*") -Directory -ErrorAction SilentlyContinue |
                   Sort-Object Name -Descending)
        if ($found.Count -gt 0) { $RocmPath = $found[0].FullName }
    }
}

$Upstream    = Join-Path $ProjectRoot "audio.cpp"
$BuildScript = Join-Path $Upstream "scripts\build_windows_hip.ps1"
$ModelSpecs  = Join-Path $Upstream "model_specs"
$BuildBin    = Join-Path $Upstream "build\hip\bin"
$DistDir     = Join-Path $ProjectRoot "dist"

# Version (artifact name suffix): from -Version, else the upstream audio.cpp nearest git tag
if ($Version -eq "") {
    $desc = & git -C $Upstream describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -eq 0 -and $desc) {
        $Version = ($desc | Select-Object -First 1).Trim()
    } else {
        $sha = & git -C $Upstream rev-parse --short HEAD 2>$null
        if ($sha) { $Version = "g$(($sha | Select-Object -First 1).Trim())" }
    }
}
if ($PackageName -eq "") {
    $PackageName = if ($Version -ne "") { "audio.cpp-server-hip-gfx1010_$Version" } else { "audio.cpp-server-hip-gfx1010" }
}
$PackageDir  = Join-Path $DistDir $PackageName

if (-not (Test-Path -LiteralPath $BuildScript)) { throw "audio.cpp not found under '$Upstream'. Run 'git submodule update --init --recursive' first." }
if (-not $RocmPath -or -not (Test-Path -LiteralPath $RocmPath)) { throw "ROCm not found. Pass -RocmPath or set HIP_PATH/ROCM_PATH." }
if ($Jobs -le 0) { $Jobs = [Math]::Max(2, [Environment]::ProcessorCount) }

# ----- locate Visual Studio with the required MSVC toolset -----
$vsInstall = $null
$vsRoots = @()
if ($env:ProgramFiles)        { $vsRoots += Join-Path $env:ProgramFiles "Microsoft Visual Studio" }
if (${env:ProgramFiles(x86)}) { $vsRoots += Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio" }
foreach ($root in $vsRoots) {
    foreach ($vcvars in @(Get-ChildItem -Path (Join-Path $root "*\*\VC\Auxiliary\Build\vcvarsall.bat") -ErrorAction SilentlyContinue)) {
        $candidate = $vcvars.Directory.Parent.Parent.Parent.FullName
        if (Test-Path (Join-Path $candidate "VC\Tools\MSVC\$MsvcToolset.*")) { $vsInstall = $candidate; break }
    }
    if ($vsInstall) { break }
}
if (-not $vsInstall) { throw "No Visual Studio install with MSVC toolset $MsvcToolset found. Install the v143 $MsvcToolset toolset." }

$vcvarsall = Join-Path $vsInstall "VC\Auxiliary\Build\vcvarsall.bat"
$crtDir = Get-ChildItem (Join-Path $vsInstall "VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT") -Directory -ErrorAction SilentlyContinue |
          Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crtDir) { throw "MSVC CRT redist directory not found under '$vsInstall'." }
$ninjaDir = Join-Path $vsInstall "Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"

Write-Host "Project:  $ProjectRoot"
Write-Host "VS:       $vsInstall (toolset $MsvcToolset)"
Write-Host "ROCm:     $RocmPath"
Write-Host "Targets:  $GpuTargets"
Write-Host "Package:  $PackageDir"

# ----- import vcvars environment (child processes inherit it) -----
Write-Host "`n== Setting up MSVC environment =="
cmd /c "`"$vcvarsall`" x64 -vcvars_ver=$MsvcToolset && set" |
    ForEach-Object { if ($_ -match '^(.*?)=(.*)$') { Set-Item -Path ("env:" + $matches[1]) -Value $matches[2] -ErrorAction SilentlyContinue } }
if ($env:VCToolsVersion -notlike "$MsvcToolset*") { throw "vcvars did not select toolset $MsvcToolset (got '$env:VCToolsVersion')." }
if (Test-Path -LiteralPath $ninjaDir) { $env:PATH = "$ninjaDir;$env:PATH" }
if (-not (Get-Command ninja.exe -ErrorAction SilentlyContinue)) { throw "ninja.exe not found (looked on PATH and in $ninjaDir)." }

# ----- build -----
if (-not $SkipBuild) {
    Write-Host "`n== Building audiocpp_server (HIP, $GpuTargets, rocBLAS path) =="
    $buildArgs = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $BuildScript,
        "-RocmPath", $RocmPath,
        "-GpuTargets", $GpuTargets,
        "-NoHipblasLt",
        "-Target", "audiocpp_server",
        "-Jobs", $Jobs.ToString(),
        "-NoNativeCpu"
    )
    if (-not $NoEmbedModelSpecs) { $buildArgs += "-DeploymentBuild" }
    Invoke-Checked "powershell.exe" $buildArgs
}

$exe = Join-Path $BuildBin "audiocpp_server.exe"
if (-not (Test-Path -LiteralPath $exe)) { throw "Build output not found: $exe" }

# ----- assemble package -----
Write-Host "`n== Assembling package =="
if (Test-Path -LiteralPath $PackageDir) { Remove-Item -LiteralPath $PackageDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $PackageDir "rocblas\library") | Out-Null
Copy-Item -LiteralPath $exe -Destination $PackageDir

# Walk the import table; copy every non-system DLL we own (ROCm bin / MSVC CRT).
$rocmBin    = Join-Path $RocmPath "bin"
$searchDirs = @($rocmBin, $crtDir.FullName)
$queue = New-Object System.Collections.Queue
$seen  = [System.Collections.Generic.HashSet[string]]::new()
$queue.Enqueue((Join-Path $PackageDir "audiocpp_server.exe"))
while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    foreach ($dep in Get-DllDependencies $current) {
        if (-not $seen.Add($dep)) { continue }
        foreach ($dir in $searchDirs) {
            $src = Join-Path $dir $dep
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination (Join-Path $PackageDir $dep) -Force
                $queue.Enqueue((Join-Path $PackageDir $dep))
                break
            }
        }
    }
}

# rocBLAS Tensile kernels: requested arches + fallback.
$archs = @($GpuTargets -split '[;,]' | Where-Object { $_ } | ForEach-Object { [regex]::Escape($_.Trim()) })
$archPattern = (@($archs) + @('fallback')) -join '|'
$kernelSrc = Join-Path $rocmBin "rocblas\library"
if (-not (Test-Path -LiteralPath $kernelSrc)) { throw "rocBLAS kernel dir not found: $kernelSrc" }
Get-ChildItem -LiteralPath $kernelSrc -File |
    Where-Object { $_.Name -match $archPattern } |
    Copy-Item -Destination (Join-Path $PackageDir "rocblas\library")
$kernelCount = @(Get-ChildItem (Join-Path $PackageDir "rocblas\library") -File).Count
if ($kernelCount -eq 0) { throw "No rocBLAS kernels matched '$archPattern'." }

# model_specs on disk (in addition to the copy embedded in the exe).
if (Test-Path -LiteralPath $ModelSpecs) {
    Copy-Item -LiteralPath $ModelSpecs -Destination $PackageDir -Recurse -Force
} else {
    Write-Warning "model_specs not found at $ModelSpecs"
}

# third-party license notices
$notices = Join-Path $ProjectRoot "THIRD_PARTY_NOTICES.txt"
if (Test-Path -LiteralPath $notices) { Copy-Item -LiteralPath $notices -Destination $PackageDir -Force }
$licensesDir = Join-Path $ProjectRoot "LICENSES"
if (Test-Path -LiteralPath $licensesDir) { Copy-Item -LiteralPath $licensesDir -Destination $PackageDir -Recurse -Force }
$projectLicense = Join-Path $ProjectRoot "LICENSE"
if (Test-Path -LiteralPath $projectLicense) { Copy-Item -LiteralPath $projectLicense -Destination $PackageDir -Force }

# ----- optional zip -----
if ($Zip) {
    $zipPath = Join-Path $DistDir "$PackageName.zip"
    Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
    Write-Host "`n== Compressing =="
    Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $zipPath
    Write-Host "Zip:      $zipPath"
}

$totalMb = [math]::Round(((Get-ChildItem -LiteralPath $PackageDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
Write-Host "`n== Done =="
Write-Host ("Package:  {0}  ({1} MB, {2} rocBLAS kernel files)" -f $PackageDir, $totalMb, $kernelCount)
Write-Host ("Run:      {0}\audiocpp_server.exe --backend hip --list-devices" -f $PackageDir)
