param(
  [ValidateSet('Marmara', 'Turkey')]
  [string]$CoverageArea = 'Turkey',
  [ValidateRange(1, 30)]
  [int]$LookbackDays = 30,
  [string]$OutputDirectory = 'build\ebird_context',
  [string]$PackageVersion = (Get-Date -Format 'yyyy.MM.dd')
)

$ErrorActionPreference = 'Stop'

# eBird uses ISO 3166-2 province codes for Turkiye subnational1 regions.
# The country-wide hotspot endpoint is returning HTTP 500, so the package is
# built by downloading province regions and merging them.
$marmaraRegions = @(
  [pscustomobject]@{ code = 'TR-10'; name = 'Balikesir' },
  [pscustomobject]@{ code = 'TR-11'; name = 'Bilecik' },
  [pscustomobject]@{ code = 'TR-16'; name = 'Bursa' },
  [pscustomobject]@{ code = 'TR-17'; name = 'Canakkale' },
  [pscustomobject]@{ code = 'TR-22'; name = 'Edirne' },
  [pscustomobject]@{ code = 'TR-34'; name = 'Istanbul' },
  [pscustomobject]@{ code = 'TR-39'; name = 'Kirklareli' },
  [pscustomobject]@{ code = 'TR-41'; name = 'Kocaeli' },
  [pscustomobject]@{ code = 'TR-54'; name = 'Sakarya' },
  [pscustomobject]@{ code = 'TR-59'; name = 'Tekirdag' },
  [pscustomobject]@{ code = 'TR-77'; name = 'Yalova' }
)

$turkeyRegions = @(
  [pscustomobject]@{ code = 'TR-01'; name = 'Adana' },
  [pscustomobject]@{ code = 'TR-02'; name = 'Adiyaman' },
  [pscustomobject]@{ code = 'TR-03'; name = 'Afyonkarahisar' },
  [pscustomobject]@{ code = 'TR-04'; name = 'Agri' },
  [pscustomobject]@{ code = 'TR-05'; name = 'Amasya' },
  [pscustomobject]@{ code = 'TR-06'; name = 'Ankara' },
  [pscustomobject]@{ code = 'TR-07'; name = 'Antalya' },
  [pscustomobject]@{ code = 'TR-08'; name = 'Artvin' },
  [pscustomobject]@{ code = 'TR-09'; name = 'Aydin' },
  [pscustomobject]@{ code = 'TR-10'; name = 'Balikesir' },
  [pscustomobject]@{ code = 'TR-11'; name = 'Bilecik' },
  [pscustomobject]@{ code = 'TR-12'; name = 'Bingol' },
  [pscustomobject]@{ code = 'TR-13'; name = 'Bitlis' },
  [pscustomobject]@{ code = 'TR-14'; name = 'Bolu' },
  [pscustomobject]@{ code = 'TR-15'; name = 'Burdur' },
  [pscustomobject]@{ code = 'TR-16'; name = 'Bursa' },
  [pscustomobject]@{ code = 'TR-17'; name = 'Canakkale' },
  [pscustomobject]@{ code = 'TR-18'; name = 'Cankiri' },
  [pscustomobject]@{ code = 'TR-19'; name = 'Corum' },
  [pscustomobject]@{ code = 'TR-20'; name = 'Denizli' },
  [pscustomobject]@{ code = 'TR-21'; name = 'Diyarbakir' },
  [pscustomobject]@{ code = 'TR-22'; name = 'Edirne' },
  [pscustomobject]@{ code = 'TR-23'; name = 'Elazig' },
  [pscustomobject]@{ code = 'TR-24'; name = 'Erzincan' },
  [pscustomobject]@{ code = 'TR-25'; name = 'Erzurum' },
  [pscustomobject]@{ code = 'TR-26'; name = 'Eskisehir' },
  [pscustomobject]@{ code = 'TR-27'; name = 'Gaziantep' },
  [pscustomobject]@{ code = 'TR-28'; name = 'Giresun' },
  [pscustomobject]@{ code = 'TR-29'; name = 'Gumushane' },
  [pscustomobject]@{ code = 'TR-30'; name = 'Hakkari' },
  [pscustomobject]@{ code = 'TR-31'; name = 'Hatay' },
  [pscustomobject]@{ code = 'TR-32'; name = 'Isparta' },
  [pscustomobject]@{ code = 'TR-33'; name = 'Mersin' },
  [pscustomobject]@{ code = 'TR-34'; name = 'Istanbul' },
  [pscustomobject]@{ code = 'TR-35'; name = 'Izmir' },
  [pscustomobject]@{ code = 'TR-36'; name = 'Kars' },
  [pscustomobject]@{ code = 'TR-37'; name = 'Kastamonu' },
  [pscustomobject]@{ code = 'TR-38'; name = 'Kayseri' },
  [pscustomobject]@{ code = 'TR-39'; name = 'Kirklareli' },
  [pscustomobject]@{ code = 'TR-40'; name = 'Kirsehir' },
  [pscustomobject]@{ code = 'TR-41'; name = 'Kocaeli' },
  [pscustomobject]@{ code = 'TR-42'; name = 'Konya' },
  [pscustomobject]@{ code = 'TR-43'; name = 'Kutahya' },
  [pscustomobject]@{ code = 'TR-44'; name = 'Malatya' },
  [pscustomobject]@{ code = 'TR-45'; name = 'Manisa' },
  [pscustomobject]@{ code = 'TR-46'; name = 'Kahramanmaras' },
  [pscustomobject]@{ code = 'TR-47'; name = 'Mardin' },
  [pscustomobject]@{ code = 'TR-48'; name = 'Mugla' },
  [pscustomobject]@{ code = 'TR-49'; name = 'Mus' },
  [pscustomobject]@{ code = 'TR-50'; name = 'Nevsehir' },
  [pscustomobject]@{ code = 'TR-51'; name = 'Nigde' },
  [pscustomobject]@{ code = 'TR-52'; name = 'Ordu' },
  [pscustomobject]@{ code = 'TR-53'; name = 'Rize' },
  [pscustomobject]@{ code = 'TR-54'; name = 'Sakarya' },
  [pscustomobject]@{ code = 'TR-55'; name = 'Samsun' },
  [pscustomobject]@{ code = 'TR-56'; name = 'Siirt' },
  [pscustomobject]@{ code = 'TR-57'; name = 'Sinop' },
  [pscustomobject]@{ code = 'TR-58'; name = 'Sivas' },
  [pscustomobject]@{ code = 'TR-59'; name = 'Tekirdag' },
  [pscustomobject]@{ code = 'TR-60'; name = 'Tokat' },
  [pscustomobject]@{ code = 'TR-61'; name = 'Trabzon' },
  [pscustomobject]@{ code = 'TR-62'; name = 'Tunceli' },
  [pscustomobject]@{ code = 'TR-63'; name = 'Sanliurfa' },
  [pscustomobject]@{ code = 'TR-64'; name = 'Usak' },
  [pscustomobject]@{ code = 'TR-65'; name = 'Van' },
  [pscustomobject]@{ code = 'TR-66'; name = 'Yozgat' },
  [pscustomobject]@{ code = 'TR-67'; name = 'Zonguldak' },
  [pscustomobject]@{ code = 'TR-68'; name = 'Aksaray' },
  [pscustomobject]@{ code = 'TR-69'; name = 'Bayburt' },
  [pscustomobject]@{ code = 'TR-70'; name = 'Karaman' },
  [pscustomobject]@{ code = 'TR-71'; name = 'Kirikkale' },
  [pscustomobject]@{ code = 'TR-72'; name = 'Batman' },
  [pscustomobject]@{ code = 'TR-73'; name = 'Sirnak' },
  [pscustomobject]@{ code = 'TR-74'; name = 'Bartin' },
  [pscustomobject]@{ code = 'TR-75'; name = 'Ardahan' },
  [pscustomobject]@{ code = 'TR-76'; name = 'Igdir' },
  [pscustomobject]@{ code = 'TR-77'; name = 'Yalova' },
  [pscustomobject]@{ code = 'TR-78'; name = 'Karabuk' },
  [pscustomobject]@{ code = 'TR-79'; name = 'Kilis' },
  [pscustomobject]@{ code = 'TR-80'; name = 'Osmaniye' },
  [pscustomobject]@{ code = 'TR-81'; name = 'Duzce' }
)

$coverageRegions = if ($CoverageArea -eq 'Marmara') {
  $marmaraRegions
} else {
  $turkeyRegions
}

$apiToken = [Environment]::GetEnvironmentVariable('EBIRD_API_TOKEN')
if ([string]::IsNullOrWhiteSpace($apiToken)) {
  throw 'EBIRD_API_TOKEN is not set. The token is read only at build time and is never written to the package.'
}
$apiToken = ($apiToken.Trim() -replace '[^A-Za-z0-9_-]', '')
if ($apiToken -notmatch '^[A-Za-z0-9_-]{8,64}$') {
  throw 'EBIRD_API_TOKEN has an invalid format.'
}

$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
  [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
  [System.IO.Path]::GetFullPath(
    (Join-Path (Get-Location) $OutputDirectory)
  )
}
[System.IO.Directory]::CreateDirectory($resolvedOutput) | Out-Null

$headers = @{ 'X-eBirdApiToken' = $apiToken }
$hotspotEndpointTemplate = 'https://api.ebird.org/v2/ref/hotspot/{regionCode}?fmt=json'
$recentEndpointTemplate = "https://api.ebird.org/v2/data/obs/{regionCode}/recent?back=$LookbackDays&hotspot=true&includeProvisional=false&maxResults=10000"
$fetchedAt = (Get-Date).ToUniversalTime().ToString('o')

function Invoke-EbirdApi {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$RequestName
  )

  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      return Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get
    } catch {
      if ($attempt -eq 3) {
        throw "$RequestName failed after 3 attempts: $($_.Exception.Message)"
      }
      Start-Sleep -Seconds (2 * $attempt)
    }
  }
}

function Write-Utf8Json {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Json
  )

  $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Json, $utf8WithoutBom)
}

function Get-FirstScalar {
  param([AllowNull()][object]$Value)

  if ($null -eq $Value) {
    return $null
  }
  if ($Value -is [System.Array]) {
    return @($Value) | Select-Object -First 1
  }
  return $Value
}

function Get-ApiItems {
  param([AllowNull()][object]$Value)

  if ($null -eq $Value) {
    return
  }
  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    foreach ($item in $Value) {
      Get-ApiItems -Value $item
    }
    return
  }
  Write-Output -NoEnumerate $Value
}

$rawHotspots = New-Object System.Collections.Generic.List[object]
$rawObservations = New-Object System.Collections.Generic.List[object]

foreach ($region in $coverageRegions) {
  Write-Output "Downloading eBird data: $($region.name) [$($region.code)]"

  $hotspotEndpoint = $hotspotEndpointTemplate.Replace(
    '{regionCode}',
    $region.code
  )
  $regionHotspots = @(
    Invoke-EbirdApi `
      -Uri $hotspotEndpoint `
      -RequestName "eBird Hotspot API ($($region.code))"
  )
  foreach ($hotspotBatch in $regionHotspots) {
    foreach ($hotspot in @(Get-ApiItems -Value $hotspotBatch)) {
      $rawHotspots.Add($hotspot)
    }
  }

  $recentEndpoint = $recentEndpointTemplate.Replace(
    '{regionCode}',
    $region.code
  )
  $regionObservations = @(
    Invoke-EbirdApi `
      -Uri $recentEndpoint `
      -RequestName "eBird Recent Observations API ($($region.code))"
  )
  foreach ($observationBatch in $regionObservations) {
    foreach ($observation in @(Get-ApiItems -Value $observationBatch)) {
      $rawObservations.Add($observation)
    }
  }
}

$hotspots = @(
  $rawHotspots |
    Where-Object {
      $_.locId -and $_.locName -and $null -ne $_.lat -and $null -ne $_.lng
    } |
    Sort-Object locId -Unique |
    ForEach-Object {
      $latitude = Get-FirstScalar $_.lat
      $longitude = Get-FirstScalar $_.lng
      if ($null -ne $latitude -and $null -ne $longitude) {
        [ordered]@{
          id = [string](Get-FirstScalar $_.locId)
          name = [string](Get-FirstScalar $_.locName)
          latitude = [double]$latitude
          longitude = [double]$longitude
          subnational1Code = if ($_.subnational1Code) { [string](Get-FirstScalar $_.subnational1Code) } else { $null }
          latestObservationAt = if ($_.latestObsDt) { [string](Get-FirstScalar $_.latestObsDt) } else { $null }
          allTimeSpeciesCount = if ($null -ne $_.numSpeciesAllTime) { [int](Get-FirstScalar $_.numSpeciesAllTime) } else { $null }
        }
      }
    }
)

$observations = @(
  $rawObservations |
    Where-Object {
      $_.speciesCode -and $_.sciName -and $_.comName -and
      $_.locId -and $_.locName -and $_.obsDt -and
      $null -ne $_.lat -and $null -ne $_.lng
    } |
    Sort-Object speciesCode, locId, obsDt -Unique |
    ForEach-Object {
      $latitude = Get-FirstScalar $_.lat
      $longitude = Get-FirstScalar $_.lng
      if ($null -ne $latitude -and $null -ne $longitude) {
        [ordered]@{
          speciesCode = [string](Get-FirstScalar $_.speciesCode)
          scientificName = [string](Get-FirstScalar $_.sciName)
          commonName = [string](Get-FirstScalar $_.comName)
          locationId = [string](Get-FirstScalar $_.locId)
          locationName = [string](Get-FirstScalar $_.locName)
          observedAt = [string](Get-FirstScalar $_.obsDt)
          latitude = [double]$latitude
          longitude = [double]$longitude
          count = if ($null -ne $_.howMany) { [int](Get-FirstScalar $_.howMany) } else { $null }
          reviewed = [bool](Get-FirstScalar $_.obsReviewed)
        }
      }
    }
)

if ($hotspots.Count -eq 0) {
  throw "The $CoverageArea package contains no hotspots; output was not updated."
}
if ($observations.Count -eq 0) {
  throw "The $CoverageArea package contains no recent observations; output was not updated."
}
$minimumExpectedRecords = [Math]::Max(10, [Math]::Floor($coverageRegions.Count / 2))
if ($hotspots.Count -lt $minimumExpectedRecords) {
  throw "Only $($hotspots.Count) hotspots were normalized for $($coverageRegions.Count) regions; output was not updated."
}
if ($observations.Count -lt $minimumExpectedRecords) {
  throw "Only $($observations.Count) recent observations were normalized for $($coverageRegions.Count) regions; output was not updated."
}

$hotspotsPath = Join-Path $resolvedOutput 'hotspots.json'
$observationsPath = Join-Path $resolvedOutput 'recent_observations.json'
$manifestPath = Join-Path $resolvedOutput 'manifest.json'

Write-Utf8Json `
  -Path $hotspotsPath `
  -Json (ConvertTo-Json -InputObject @($hotspots) -Depth 5 -Compress)
Write-Utf8Json `
  -Path $observationsPath `
  -Json (ConvertTo-Json -InputObject @($observations) -Depth 5 -Compress)

$hotspotsHash = (Get-FileHash -LiteralPath $hotspotsPath -Algorithm SHA256).Hash.ToLowerInvariant()
$observationsHash = (Get-FileHash -LiteralPath $observationsPath -Algorithm SHA256).Hash.ToLowerInvariant()
$coverageRegionRecords = @(
  $coverageRegions | ForEach-Object {
    [ordered]@{
      code = $_.code
      name = $_.name
    }
  }
)

$manifest = [ordered]@{
  schemaVersion = 1
  packageId = 'turkey-ebird-context'
  version = $PackageVersion
  minimumAppVersion = '0.5.0'
  regionCode = 'TR'
  coverageArea = $CoverageArea
  coverageRegions = $coverageRegionRecords
  generatedAt = $fetchedAt
  lookbackDays = $LookbackDays
  counts = [ordered]@{
    coverageRegions = $coverageRegions.Count
    hotspots = $hotspots.Count
    recentObservations = $observations.Count
  }
  sources = @(
    [ordered]@{
      name = 'eBird Hotspot API'
      endpointTemplate = $hotspotEndpointTemplate
      strategy = 'subnational1 fan-out'
      requestCount = $coverageRegions.Count
      regions = @($coverageRegions.code)
      fetchedAt = $fetchedAt
      recordCount = $hotspots.Count
    },
    [ordered]@{
      name = 'eBird Recent Observations API'
      endpointTemplate = $recentEndpointTemplate
      strategy = 'subnational1 fan-out'
      requestCount = $coverageRegions.Count
      regions = @($coverageRegions.code)
      fetchedAt = $fetchedAt
      recordCount = $observations.Count
      parameters = [ordered]@{
        back = $LookbackDays
        hotspot = $true
        includeProvisional = $false
        maxResultsPerRegion = 10000
      }
    }
  )
  files = [ordered]@{
    hotspots = [ordered]@{
      name = 'hotspots.json'
      sha256 = $hotspotsHash
    }
    recentObservations = [ordered]@{
      name = 'recent_observations.json'
      sha256 = $observationsHash
    }
  }
  notices = @(
    "Coverage area: $CoverageArea.",
    'Contains limited, recent and summary outputs from the eBird API.',
    'Absence of a recent record does not mean that a species is absent.',
    'The API token is not included in this package.'
  )
}

Write-Utf8Json `
  -Path $manifestPath `
  -Json ($manifest | ConvertTo-Json -Depth 10)

Write-Output "FirBird eBird Marmara context package created: $resolvedOutput"
Write-Output "Provinces: $($coverageRegions.Count)"
Write-Output "Hotspots: $($hotspots.Count)"
Write-Output "Recent hotspot observations: $($observations.Count)"
Write-Output "Source date (UTC): $fetchedAt"
