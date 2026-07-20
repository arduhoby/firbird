param(
  [string]$CandidatesPath = 'tools\model_staging\bioclip2\turkey_regular_and_migrant_birds.json',
  [string]$OrnitoListPath = 'tools\model_staging\ornito_bird_list.html'
)

$ErrorActionPreference = 'Stop'
$ornitoIds = @{}
foreach ($match in [regex]::Matches((Get-Content $OrnitoListPath -Raw), '<a href="/Bird/Detail/(\d+)">([^<]+)</a>')) {
  $ornitoIds[$match.Groups[2].Value.Trim()] = $match.Groups[1].Value
}
$package = Get-Content $CandidatesPath -Raw | ConvertFrom-Json
foreach ($candidate in $package.candidates) {
  if ($ornitoIds.ContainsKey($candidate.scientificName)) {
    $candidate | Add-Member -NotePropertyName ornitoId -NotePropertyValue $ornitoIds[$candidate.scientificName] -Force
  }
}
$package | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 $CandidatesPath
Write-Output "Enriched $(@($package.candidates | Where-Object { $_.ornitoId }).Count) candidates with Ornito IDs."
