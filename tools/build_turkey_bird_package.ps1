param(
  [string]$StagingDirectory = 'tools\model_staging\bioclip2'
)

$ErrorActionPreference = 'Stop'

$wikiPath = Join-Path $StagingDirectory 'turkey_birds_source.wikitext'
$labelsPath = Join-Path $StagingDirectory 'txt_emb_species.json'
$embeddingsPath = Join-Path $StagingDirectory 'txt_emb_species.npy'
$outputEmbeddingsPath = Join-Path $StagingDirectory 'turkey_regular_and_migrant_birds.npy'
$outputCandidatesPath = Join-Path $StagingDirectory 'turkey_regular_and_migrant_birds.json'

$targets = foreach ($line in Get-Content $wikiPath) {
  if ($line -match "^\*\[\[.*?\]\], ''([^']+)''(.*)$") {
    [pscustomobject]@{
      scientificName = $matches[1]
      occurrence = if ($matches[2] -match '\(A\)') { 'accidental' } else { 'regular-or-migratory' }
    }
  }
}

$labelEntries = Get-Content $labelsPath -Raw | ConvertFrom-Json
$labelIndices = @{}
for ($index = 0; $index -lt $labelEntries.Count; $index++) {
  $taxonomy = $labelEntries[$index][0]
  if ($taxonomy.Count -ge 7 -and $taxonomy[5] -and $taxonomy[6]) {
    $labelIndices["$($taxonomy[5]) $($taxonomy[6])"] = $index
  }
}

$selected = foreach ($target in $targets) {
  if ($labelIndices.ContainsKey($target.scientificName)) {
    [pscustomobject]@{
      scientificName = $target.scientificName
      occurrence = $target.occurrence
      sourceIndex = $labelIndices[$target.scientificName]
    }
  }
}

if ($selected.Count -lt 350) {
  throw "Too few Turkey checklist names matched ($($selected.Count)/$($targets.Count)); taxonomy reconciliation is required."
}

$dimensions = 768
$sourceColumns = $labelEntries.Count
$sourceDataOffset = 128
$header = "{'descr': '<f4', 'fortran_order': False, 'shape': ($dimensions, $($selected.Count)), }"
$padding = (16 - (($header.Length + 10 + 1) % 16)) % 16
$header = $header + (' ' * $padding) + "`n"

$input = [System.IO.File]::Open($embeddingsPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
$output = [System.IO.File]::Open($outputEmbeddingsPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
try {
  $output.Write([byte[]](0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59, 0x01, 0x00), 0, 8)
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
  $headerLength = [BitConverter]::GetBytes([UInt16]$headerBytes.Length)
  $output.Write($headerLength, 0, $headerLength.Length)
  $output.Write($headerBytes, 0, $headerBytes.Length)

  $rowBytes = New-Object byte[] ($sourceColumns * 4)
  $valueBytes = New-Object byte[] 4
  for ($row = 0; $row -lt $dimensions; $row++) {
    $input.Position = $sourceDataOffset + ([Int64]$row * $rowBytes.Length)
    $read = 0
    while ($read -lt $rowBytes.Length) {
      $next = $input.Read($rowBytes, $read, $rowBytes.Length - $read)
      if ($next -eq 0) { throw 'Unexpected end of source embeddings.' }
      $read += $next
    }
    foreach ($candidate in $selected) {
      [Array]::Copy($rowBytes, $candidate.sourceIndex * 4, $valueBytes, 0, 4)
      $output.Write($valueBytes, 0, 4)
    }
  }
} finally {
  $input.Dispose()
  $output.Dispose()
}

[ordered]@{
  schemaVersion = 1
  source = 'Wikipedia List of birds of Turkey (Clements 2022)'
  scope = 'Türkiye residents, regular migrants, and accidental records ranked separately'
  embeddingDimensions = $dimensions
  candidates = $selected
  unmatchedChecklistNames = @($targets | Where-Object { -not $labelIndices.ContainsKey($_.scientificName) })
} | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 $outputCandidatesPath

Write-Output "Matched $($selected.Count) of $($targets.Count) Turkey checklist names."
Write-Output "Embeddings: $outputEmbeddingsPath"
Write-Output "Candidates: $outputCandidatesPath"
