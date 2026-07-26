$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDirectory = Join-Path $projectRoot 'assets\ebird_context'

$secureToken = Read-Host 'Paste the eBird API key' -AsSecureString
$tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
  $secureToken
)

try {
  $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    $tokenPointer
  ).Trim()
  $plainToken = $plainToken -replace '[^A-Za-z0-9_-]', ''
  if ([string]::IsNullOrWhiteSpace($plainToken)) {
    throw 'The eBird API key cannot be empty.'
  }
  if ($plainToken -notmatch '^[A-Za-z0-9_-]{8,64}$') {
    throw 'The eBird API key format is invalid. Copy only the key value.'
  }
  $env:EBIRD_API_TOKEN = $plainToken
  & "$PSScriptRoot\build_ebird_context_package.ps1" `
    -OutputDirectory $outputDirectory `
    -CoverageArea Turkey `
    -LookbackDays 30
} finally {
  Remove-Item Env:EBIRD_API_TOKEN -ErrorAction SilentlyContinue
  if ($tokenPointer -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
  }
}
