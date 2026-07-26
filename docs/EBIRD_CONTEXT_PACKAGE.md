# FirBird eBird context package

FirBird v0.5.0 uses a prepared, offline Turkiye context package for nearby
hotspots and recent observations. The default package covers all 81 provinces;
Marmara remains available as a smaller test scope. The mobile application never
contains an eBird API token and does not call eBird while live audio recording
is active.

## Build

Run the secure helper from the project root:

```powershell
.\tools\download_ebird_context_package.ps1
```

It asks for the key without displaying it. The token is held only for the
build process and is not written to output.

The country-wide eBird hotspot endpoint can return HTTP 500. To avoid that
single large request, the builder downloads eBird `subnational1` regions
separately and merges them. The default full package makes 81 province-level
hotspot requests and 81 recent-observation requests. For a quick Marmara test,
run the builder directly with `-CoverageArea Marmara`; it uses these 11 regions:

- TR-10 Balikesir
- TR-11 Bilecik
- TR-16 Bursa
- TR-17 Canakkale
- TR-22 Edirne
- TR-34 Istanbul
- TR-39 Kirklareli
- TR-41 Kocaeli
- TR-54 Sakarya
- TR-59 Tekirdag
- TR-77 Yalova

The generated directory contains:

- `manifest.json`
- `hotspots.json`
- `recent_observations.json`

The manifest records every covered region, source endpoint template, UTC fetch
time, query parameters, request and record counts, and SHA-256 hashes. Current
API data is recent/summary context; it must not be described as historical
occurrence frequency.

## Runtime meaning

- A nearby recent observation supports a model result but does not prove it.
- No nearby recent observation does not mean that a species is absent.
- Historical weekly frequency will be added only after approved EBD and
  Sampling Event Data are available.
- OpenStreetMap tiles are not included in this package.
