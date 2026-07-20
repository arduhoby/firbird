param(
  [string]$CandidatesPath = 'tools\model_staging\bioclip2\turkey_regular_and_migrant_birds.json',
  [string]$TaxonomyPath = 'tools\model_staging\birdnet_taxonomy.csv'
)

$ErrorActionPreference = 'Stop'
$package = Get-Content $CandidatesPath -Raw | ConvertFrom-Json
$taxonomyByScientificName = @{}
foreach ($entry in Import-Csv $TaxonomyPath) {
  if ($entry.scientific_name) { $taxonomyByScientificName[$entry.scientific_name] = $entry }
}

foreach ($candidate in $package.candidates) {
  $entry = $taxonomyByScientificName[$candidate.scientificName]
  if ($null -ne $entry) {
    $candidate | Add-Member -NotePropertyName turkishName -NotePropertyValue $entry.common_name_tr -Force
    $candidate | Add-Member -NotePropertyName englishName -NotePropertyValue $entry.common_name_en -Force
    $candidate | Add-Member -NotePropertyName iNaturalistId -NotePropertyValue $entry.inat_id -Force
    $candidate | Add-Member -NotePropertyName imageUrl -NotePropertyValue $entry.image_url -Force
  }
}
$package | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 $CandidatesPath
$matched = @($package.candidates | Where-Object { $_.turkishName }).Count
Write-Output "Enriched $matched of $($package.candidates.Count) candidates with Turkish names."
