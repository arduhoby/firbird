param(
  [Parameter(Mandatory = $true)]
  [string]$EbdArchive,
  [string]$HotspotsPath = 'assets\ebird_context\hotspots.json',
  [string]$TurkishCatalogPath = 'assets\audio_catalog\turkey-birdnet-v1.json',
  [string]$OutputPath = 'build\ebird_context_1y\recent_observations.json'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Write-Utf8Json {
  param([string]$Path, [object]$Value)
  $directory = Split-Path -Parent $Path
  [System.IO.Directory]::CreateDirectory($directory) | Out-Null
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText(
    $Path,
    ($Value | ConvertTo-Json -Depth 5 -Compress),
    $encoding
  )
}

function Parse-Count {
  param([string]$Value)
  $number = 0
  if ([int]::TryParse($Value, [ref]$number)) { return $number }
  return $null
}

$resolvedArchive = [System.IO.Path]::GetFullPath($EbdArchive)
$resolvedHotspots = [System.IO.Path]::GetFullPath($HotspotsPath)
$resolvedTurkishCatalog = [System.IO.Path]::GetFullPath($TurkishCatalogPath)
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
if (-not [System.IO.File]::Exists($resolvedArchive)) {
  throw "EBD archive was not found: $resolvedArchive"
}

$hotspotById = @{}
foreach ($hotspot in (Get-Content -Raw -LiteralPath $resolvedHotspots | ConvertFrom-Json)) {
  $hotspotById[[string]$hotspot.id] = $hotspot
}

$turkishNameByScientificName = @{}
if ([System.IO.File]::Exists($resolvedTurkishCatalog)) {
  $catalog = Get-Content -Raw -LiteralPath $resolvedTurkishCatalog | ConvertFrom-Json
  foreach ($species in @($catalog.species)) {
    if ($species.scientificName -and $species.turkishName) {
      $turkishNameByScientificName[[string]$species.scientificName] = [string]$species.turkishName
    }
  }
}

$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedArchive)
try {
  $dataEntry = @($archive.Entries | Where-Object {
    $_.Name -like 'ebd_*_smp_relJun-2026.txt'
  }) | Select-Object -First 1
  if ($null -eq $dataEntry) { throw 'Observation table was not found in EBD archive.' }

  $reader = [System.IO.StreamReader]::new($dataEntry.Open(), [System.Text.UTF8Encoding]::new($false), $true)
  try {
    $headers = $reader.ReadLine().Split("`t")
    $column = @{}
    for ($index = 0; $index -lt $headers.Count; $index++) { $column[$headers[$index]] = $index }
    foreach ($required in @('TAXON CONCEPT ID', 'COMMON NAME', 'SCIENTIFIC NAME', 'OBSERVATION COUNT', 'LOCALITY', 'LOCALITY ID', 'LOCALITY TYPE', 'LATITUDE', 'LONGITUDE', 'OBSERVATION DATE', 'TIME OBSERVATIONS STARTED', 'OBSERVER ID', 'APPROVED', 'REVIEWED')) {
      if (-not $column.ContainsKey($required)) { throw "Required EBD column is missing: $required" }
    }

    $latestByHotspotAndTaxon = @{}
    $matchedRows = 0
    while (-not $reader.EndOfStream) {
      $fields = $reader.ReadLine().Split("`t")
      if ($fields.Count -lt $headers.Count) { continue }
      $locationId = $fields[$column['LOCALITY ID']]
      if (-not $hotspotById.ContainsKey($locationId)) { continue }
      if ($fields[$column['LOCALITY TYPE']] -ne 'H') { continue }
      if ($fields[$column['APPROVED']] -ne '1') { continue }

      $taxon = $fields[$column['TAXON CONCEPT ID']]
      $dateText = $fields[$column['OBSERVATION DATE']]
      $timeText = $fields[$column['TIME OBSERVATIONS STARTED']]
      $observedAt = if ([string]::IsNullOrWhiteSpace($timeText)) { $dateText } else { "$dateText $timeText" }
      $key = "$locationId|$taxon"
      $matchedRows++
      if ($latestByHotspotAndTaxon.ContainsKey($key) -and $latestByHotspotAndTaxon[$key].observedAt -ge $observedAt) { continue }

      $latitude = 0.0
      $longitude = 0.0
      if (-not [double]::TryParse($fields[$column['LATITUDE']], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$latitude)) { continue }
      if (-not [double]::TryParse($fields[$column['LONGITUDE']], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$longitude)) { continue }
      $latestByHotspotAndTaxon[$key] = [ordered]@{
        speciesCode = $taxon
        scientificName = $fields[$column['SCIENTIFIC NAME']]
        turkishName = $turkishNameByScientificName[$fields[$column['SCIENTIFIC NAME']]]
        commonName = $fields[$column['COMMON NAME']]
        locationId = $locationId
        locationName = $fields[$column['LOCALITY']]
        observedAt = $observedAt
        latitude = $latitude
        longitude = $longitude
        count = Parse-Count $fields[$column['OBSERVATION COUNT']]
        reviewed = ($fields[$column['REVIEWED']] -eq '1')
        observerName = $fields[$column['OBSERVER ID']]
      }
    }
  } finally {
    $reader.Dispose()
  }
} finally {
  $archive.Dispose()
}

$observations = @($latestByHotspotAndTaxon.Values | Sort-Object locationId, observedAt -Descending)
if ($observations.Count -eq 0) { throw 'No approved hotspot observations matched the existing hotspot package.' }
Write-Utf8Json -Path $resolvedOutput -Value $observations
Write-Output "Matched source rows: $matchedRows"
Write-Output "Latest hotspot/species summaries: $($observations.Count)"
Write-Output "Output: $resolvedOutput"
