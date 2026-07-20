# FirBird region package format

A FirBird package is a ZIP archive with a root manifest.json file. The installer validates the SHA-256 checksum before extraction, rejects unsafe paths, applies archive size and file-count limits, validates the manifest, and installs through a staging directory.

The first package ID is turkey-all. Release packages must include the full license and attribution metadata before publication.

## Required manifest fields

- schemaVersion
- packageId
- version
- minimumAppVersion
- speciesCount

## Installation guarantees

The previous installed package remains available until a replacement archive has been validated and moved into place. Temporary installation data is removed after a failed installation.
