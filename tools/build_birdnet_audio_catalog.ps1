param(
  [string]$SourceCandidatesPath = 'tools\model_staging\turkey_0.1.0\candidates.json',
  [string]$BirdNetLabelsPath = 'assets\models\birdnet_labels.txt',
  [string]$OutputPath = 'assets\audio_catalog\turkey-birdnet-v1.json'
)

$ErrorActionPreference = 'Stop'

function Repair-Utf8Mojibake([string]$Value) {
  $markers = [char[]]@([char]0x00C2, [char]0x00C3, [char]0x00C4, [char]0x00C5)
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value.IndexOfAny($markers) -lt 0) {
    return $Value
  }
  try {
    $windows1252 = [System.Text.Encoding]::GetEncoding(1252)
    $repaired = [System.Text.Encoding]::UTF8.GetString($windows1252.GetBytes($Value))
    if ($repaired.Contains([char]0xFFFD)) { return $Value }
    return $repaired
  } catch {
    return $Value
  }
}

if (-not (Test-Path -LiteralPath $SourceCandidatesPath)) {
  throw "Candidate source not found: $SourceCandidatesPath"
}
if (-not (Test-Path -LiteralPath $BirdNetLabelsPath)) {
  throw "BirdNET labels not found: $BirdNetLabelsPath"
}

$source = Get-Content -LiteralPath $SourceCandidatesPath -Raw | ConvertFrom-Json
$labels = Get-Content -LiteralPath $BirdNetLabelsPath
$labelsByScientificName = @{}
foreach ($label in $labels) {
  $parts = $label.Trim().Split('_')
  if ($parts.Count -lt 2) { continue }
  $firstPart = $parts[0].Trim()
  $scientificName = if ($firstPart.Contains(' ')) {
    $firstPart
  } elseif ($parts.Count -ge 3 -and $parts[1] -match '^[a-z-]+$') {
    "$firstPart $($parts[1])"
  } else {
    continue
  }
  $key = $scientificName.ToLowerInvariant()
  if (-not $labelsByScientificName.ContainsKey($key)) {
    $labelsByScientificName[$key] = [System.Collections.Generic.List[string]]::new()
  }
  $labelsByScientificName[$key].Add($label)
}

$selected = [System.Collections.Generic.List[object]]::new()
$unmatched = [System.Collections.Generic.List[string]]::new()
foreach ($candidate in $source.candidates) {
  $scientificName = [string]$candidate.scientificName
  $matches = @($labelsByScientificName[$scientificName.ToLowerInvariant()])
  if ($matches.Count -ne 1) {
    $unmatched.Add($scientificName)
    continue
  }
  $selected.Add([ordered]@{
      scientificName = $scientificName
      turkishName = Repair-Utf8Mojibake ([string]$candidate.turkishName)
      englishName = [string]$candidate.englishName
      occurrence = [string]$candidate.occurrence
      imageUrl = $candidate.imageUrl
      ornitoId = $candidate.ornitoId
      birdNetLabel = $matches[0]
    })
}

if ($selected.Count -lt 350) {
  throw "Too few Turkey candidates match BirdNET labels ($($selected.Count)/$($source.candidates.Count))."
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

[ordered]@{
  schemaVersion = 1
  id = 'turkey-birdnet-audio'
  version = '1.0.1'
  model = 'BirdNET GLOBAL 6K V2.4'
  sourceCandidates = 'tools/model_staging/turkey_0.1.0/candidates.json'
  sourceLabels = 'assets/models/birdnet_labels.txt'
  sourceCandidateCount = @($source.candidates).Count
  matchedBirdNetSpeciesCount = $selected.Count
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  species = $selected
  unmatchedSourceSpecies = $unmatched
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8

Write-Output "FirBird BirdNET audio catalog created: $OutputPath"
Write-Output "BirdNET-compatible Turkey species: $($selected.Count)/$($source.candidates.Count)"
if ($unmatched.Count -gt 0) {
  Write-Output "Unmatched source species: $($unmatched.Count)"
}
