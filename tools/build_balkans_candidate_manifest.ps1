param(
  [Parameter(Mandatory = $true)]
  [string]$SourcePath,
  [string]$OutputPath = 'tools\model_staging\bioclip2\balkans_candidates.json',
  [string]$ReviewPath = 'tools\model_staging\bioclip2\balkans_review.json'
)

$ErrorActionPreference = 'Stop'

$allowedCountries = @('AL', 'BA', 'BG', 'GR', 'HR', 'ME', 'MK', 'RO', 'RS', 'SI', 'XK')
$allowedLicenses = @('CC0-1.0', 'CC-BY-4.0')
$source = Get-Content -Raw -Encoding utf8 $SourcePath | ConvertFrom-Json

if ($null -eq $source.sources) {
  throw 'Expected a sources array.'
}

$accepted = @()
$rejected = @()
foreach ($entry in $source.sources) {
  if ($entry.countryCode -notin $allowedCountries) {
    $rejected += [pscustomobject]@{ reason = 'Unsupported country'; source = $entry.source }
    continue
  }
  if ($entry.license -notin $allowedLicenses) {
    $rejected += [pscustomobject]@{ reason = 'Unsupported license'; source = $entry.source; license = $entry.license }
    continue
  }
  foreach ($species in $entry.species) {
    if ([string]::IsNullOrWhiteSpace($species.scientificName)) {
      $rejected += [pscustomobject]@{ reason = 'Missing scientific name'; source = $entry.source }
      continue
    }
    $accepted += [pscustomobject]@{
      scientificName = $species.scientificName.Trim()
      countryCode = $entry.countryCode
      occurrence = if ($species.occurrence) { $species.occurrence } else { 'regular' }
      source = $entry.source
      license = $entry.license
      version = $entry.version
    }
  }
}

$candidates = $accepted |
  Group-Object scientificName |
  ForEach-Object {
    $records = $_.Group
    [pscustomobject]@{
      scientificName = $_.Name
      occurrence = 'balkans'
      originScope = 'balkans-regular'
      sourceCountries = @($records.countryCode | Sort-Object -Unique)
      sources = @($records | ForEach-Object {
        [pscustomobject]@{ source = $_.source; license = $_.license; version = $_.version }
      } | Sort-Object source -Unique)
    }
  } |
  Sort-Object scientificName

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
$candidateList = @($candidates)
$rejectedList = @($rejected)
ConvertTo-Json -InputObject $candidateList -Depth 6 | Set-Content -Encoding utf8 $OutputPath
ConvertTo-Json -InputObject $rejectedList -Depth 4 | Set-Content -Encoding utf8 $ReviewPath

Write-Output "Created $($candidateList.Count) Balkan candidates; $($rejectedList.Count) source records require review."
