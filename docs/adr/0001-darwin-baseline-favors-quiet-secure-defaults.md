# Darwin baseline favors quiet, secure defaults

The active Mac's Darwin baseline should prefer a quiet, secure default over convenience helpers that run continuously. Dropbox installation stays opt-in, CleanMyMac and Dropbox launchd helpers are disabled when configured as manual-only/background-suppressed, Spotlight is steered away from development/cache trees with reversible managed markers, and Gatekeeper/quarantine plus disk-image verification stay enabled so future maintenance does not accidentally normalize background churn or weakened download checks.
