# Used by the "Deploy Selected Apps" workflow.
# Turns the apps chosen in the workflow run into AL-Go's excludeAppIds for the target environment: every app in the
# downloaded build that wasn't chosen is excluded, so AL-Go's own Deploy action publishes only the chosen ones.
#
# Apps are chosen by folder name (e.g. ShopifyUOMCorrection) or by the name in app.json, comma-separated; * means all.
# Matching uses app IDs, read from app.json in the repository and from the manifest inside each built .app file,
# so an app renamed between the build and now is still found.
Param(
    [string] $SelectedApps = $env:SelectedApps,
    [string] $EnvironmentName = $env:EnvironmentName,
    [string] $DeploymentEnvironmentsJson = $env:DeploymentEnvironmentsJson,
    [string] $SettingsJson = $env:Settings,
    [string] $RepositoryFolder = $env:GITHUB_WORKSPACE,
    [string] $ArtifactsFolder = (Join-Path $env:GITHUB_WORKSPACE '.artifacts')
)

$ErrorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"; Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.IO.Compression

function Get-AppFromAppFile([string] $Path) {
    # A .app file is a short NAVX header followed by a zip archive.
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $zipStart = -1
    for ($i = 0; $i -lt [Math]::Min(1024, $bytes.Length - 3); $i++) {
        if ($bytes[$i] -eq 0x50 -and $bytes[$i + 1] -eq 0x4B -and $bytes[$i + 2] -eq 0x03 -and $bytes[$i + 3] -eq 0x04) {
            $zipStart = $i
            break
        }
    }
    if ($zipStart -lt 0) {
        throw "$Path is not a valid Business Central app file."
    }
    $stream = [System.IO.MemoryStream]::new($bytes, $zipStart, $bytes.Length - $zipStart)
    $zip = [System.IO.Compression.ZipArchive]::new($stream)
    try {
        $entry = $zip.GetEntry('NavxManifest.xml')
        if (-not $entry) {
            throw "$Path has no NavxManifest.xml."
        }
        $reader = [System.IO.StreamReader]::new($entry.Open())
        try {
            [xml] $manifest = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $zip.Dispose()
    }
    [PSCustomObject]@{
        Id      = ([string] $manifest.Package.App.Id).ToLowerInvariant()
        Name    = [string] $manifest.Package.App.Name
        Version = [string] $manifest.Package.App.Version
        File    = Split-Path $Path -Leaf
    }
}

function Write-Summary([string] $Text) {
    Write-Host $Text
    if ($env:GITHUB_STEP_SUMMARY) {
        Add-Content -Encoding UTF8 -Path $env:GITHUB_STEP_SUMMARY -Value $Text
    }
}

# Apps in the repository: folder name, app.json name and id.
$repoApps = @(Get-ChildItem -Path $RepositoryFolder -Directory | ForEach-Object {
        $appJsonPath = Join-Path $_.FullName 'app.json'
        if (Test-Path $appJsonPath -PathType Leaf) {
            $appJson = Get-Content -Path $appJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
            [PSCustomObject]@{ Folder = $_.Name; Name = [string] $appJson.name; Id = ([string] $appJson.id).ToLowerInvariant() }
        }
    })

# Apps in the build. Only the Apps artifact counts, not TestApps or Dependencies.
$builtApps = @(Get-ChildItem -Path $ArtifactsFolder -Recurse -Filter '*.app' |
    Where-Object { (Split-Path $_.DirectoryName -Leaf) -match '-Apps-' } |
    ForEach-Object { Get-AppFromAppFile -Path $_.FullName })
if ($builtApps.Count -eq 0) {
    throw "The downloaded build contains no apps. Check that the chosen version has a successful CI/CD build."
}

$tokens = @($SelectedApps -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($tokens.Count -eq 0 -or $tokens -contains '*') {
    $selectedIds = @($builtApps | ForEach-Object { $_.Id })
}
else {
    $selectedIds = @()
    foreach ($token in $tokens) {
        $match = @($repoApps | Where-Object { $_.Folder -eq $token -or $_.Name -eq $token })
        if ($match.Count -eq 0) {
            $valid = ($repoApps | ForEach-Object { $_.Folder } | Sort-Object) -join ', '
            throw "'$token' is not an app in this repository. Use folder names, comma-separated: $valid"
        }
        $selectedIds += $match[0].Id
    }
    $selectedIds = @($selectedIds | Select-Object -Unique)

    $notBuilt = @($selectedIds | Where-Object { $builtApps.Id -notcontains $_ })
    if ($notBuilt.Count -gt 0) {
        $names = ($repoApps | Where-Object { $notBuilt -contains $_.Id } | ForEach-Object { $_.Folder }) -join ', '
        $inBuild = ($builtApps | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', '
        throw "Not in the chosen build: $names. Push the app and wait for a successful CI/CD run, or choose another version. The build contains: $inBuild"
    }
}

$deployApps = @($builtApps | Where-Object { $selectedIds -contains $_.Id })
$skipApps = @($builtApps | Where-Object { $selectedIds -notcontains $_.Id })
$excludeIds = @($skipApps | ForEach-Object { $_.Id })

# A DeployTo<environment> setting is applied on top of the environment settings by AL-Go's Deploy action, so an
# excludeAppIds there would replace this list. Merge it in and write the merged list to both places.
$envName = $EnvironmentName.Split(' ')[0]
$settingsName = "DeployTo$envName"
$settings = $null
if ($SettingsJson) {
    $settings = $SettingsJson | ConvertFrom-Json
    if (($settings.PSObject.Properties.Name -contains $settingsName) -and ($settings.$settingsName.PSObject.Properties.Name -contains 'excludeAppIds')) {
        $excludeIds = @(@($excludeIds) + @($settings.$settingsName.excludeAppIds | ForEach-Object { ([string] $_).ToLowerInvariant() }) | Select-Object -Unique)
        $settings.$settingsName.excludeAppIds = $excludeIds
    }
}

$deploymentEnvironments = $DeploymentEnvironmentsJson | ConvertFrom-Json
$environmentSettings = $deploymentEnvironments.$EnvironmentName
if (-not $environmentSettings) {
    throw "Environment '$EnvironmentName' was not found in the deployment settings."
}
if ($environmentSettings.PSObject.Properties.Name -contains 'excludeAppIds') {
    $environmentSettings.excludeAppIds = $excludeIds
}
else {
    $environmentSettings | Add-Member -NotePropertyName 'excludeAppIds' -NotePropertyValue $excludeIds
}

Write-Summary "### Apps deployed to $EnvironmentName"
$deployApps | ForEach-Object { Write-Summary "- $($_.Name) $($_.Version)" }
if ($skipApps.Count -gt 0) {
    Write-Summary "### Apps in the build but not deployed"
    $skipApps | ForEach-Object { Write-Summary "- $($_.Name) $($_.Version)" }
}

if ($env:GITHUB_OUTPUT) {
    $json = ConvertTo-Json -InputObject $deploymentEnvironments -Depth 20 -Compress
    Add-Content -Encoding UTF8 -Path $env:GITHUB_OUTPUT -Value "deploymentEnvironmentsJson=$json"
}
if ($env:GITHUB_ENV -and $settings) {
    $settingsOut = ConvertTo-Json -InputObject $settings -Depth 20 -Compress
    Add-Content -Encoding UTF8 -Path $env:GITHUB_ENV -Value "Settings=$settingsOut"
}

# Returned for local testing.
[PSCustomObject]@{ Deploy = $deployApps; Skip = $skipApps; ExcludeAppIds = $excludeIds; DeploymentEnvironments = $deploymentEnvironments }
