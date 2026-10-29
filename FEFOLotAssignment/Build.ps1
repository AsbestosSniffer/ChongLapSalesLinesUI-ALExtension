param(
    [switch] $IncludeTests,
    [string] $CompilerPath,
    [string] $DotnetPath,
    [string] $PackageCachePath = (Join-Path $PSScriptRoot '..\.alpackages')
)
$ErrorActionPreference = 'Stop'
if (-not $CompilerPath) {
    $extension = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.vscode\extensions') -Directory -Filter 'ms-dynamics-smb.al-*' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $extension) { throw 'Set -CompilerPath to the AL extension bin\alc.dll.' }
    $CompilerPath = Join-Path $extension.FullName 'bin\alc.dll'
}
if (-not $DotnetPath) {
    $dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnetCommand) { $DotnetPath = $dotnetCommand.Source }
    else {
        $runtimeRoot = Join-Path $env:APPDATA 'Code\User\globalStorage\ms-dotnettools.vscode-dotnet-runtime\.dotnet'
        $runtime = Get-ChildItem -LiteralPath $runtimeRoot -Filter dotnet.exe -Recurse |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $runtime) { throw 'Set -DotnetPath to a compatible dotnet.exe.' }
        $DotnetPath = $runtime.FullName
    }
}
$manifest = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'app.json') | ConvertFrom-Json
$outputDirectory = Join-Path $PSScriptRoot '.build'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$suffix = if ($IncludeTests) { '.Tests' } else { '' }
$outputFile = Join-Path $outputDirectory ("FEFO.{0}{1}.app" -f $manifest.version, $suffix)
$compilerArguments = @(
    "/project:$PSScriptRoot",
    "/packagecachepath:$([System.IO.Path]::GetFullPath($PackageCachePath))",
    "/out:$outputFile",
    '/generatecode+',
    '/warnaserror+'
)
if ($IncludeTests) { $compilerArguments += '/define:FEFO_TESTS' }
& $DotnetPath $CompilerPath @compilerArguments
if ($LASTEXITCODE -ne 0) { throw "AL compilation failed (exit $LASTEXITCODE)." }
Write-Output "Built $outputFile"
