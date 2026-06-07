# Darwin baseline favors quiet, secure defaults

The active Mac's Darwin baseline should prefer a quiet, secure default over convenience helpers that run continuously. CleanMyMac launchd helpers are disabled when configured as manual-only, Spotlight is steered away from development/cache trees with reversible managed markers, and Gatekeeper/quarantine plus disk-image verification stay enabled so future maintenance does not accidentally normalize background churn or weakened download checks.

> Note: this ADR originally also covered an opt-in, Nix-vendored Dropbox client with its launchd updaters suppressed. That scaffold was removed; Dropbox is now installed natively and left to self-update. See `docs/adr/0005`.
