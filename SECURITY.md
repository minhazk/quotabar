# Security

LeftBar is a derivative of dancik/limitbar. Report LeftBar issues privately to this repository's owner; the upstream maintainer does not maintain this derivative.

Do not include credentials, full CLI output, session transcripts, or account identifiers in reports. A CLI version, macOS version, and redacted error description are usually sufficient.

The inherited process isolation is implemented in Sources/LeftBar/Spawn.swift, Sources/LeftBar/Fetchers.swift, and Resources/cli.sb. See README.md for the data sources and privacy behavior. Ad-hoc signing verifies bundle integrity locally; it is not Apple notarization.
