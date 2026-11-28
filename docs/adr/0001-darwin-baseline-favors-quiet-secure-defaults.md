# Darwin baseline favors quiet, secure defaults

Status: accepted

Always-on helpers and Spotlight indexing over build trees waste CPU and battery. Disabling macOS download checks creates security exposure. The active Mac's **Darwin baseline** disables CleanMyMac background launchd helpers when manual-only. It excludes development and cache trees from Spotlight with reversible markers. It keeps Gatekeeper, quarantine, firewall, and disk-image verification on.

## Considered options

- **Leave helpers and Spotlight defaults untouched.** Rejected: background updaters and indexers churn over `~/devv` and cache folders during builds.
- **Disable Gatekeeper or quarantine for faster installs.** Rejected: convenience during rare manual installs cannot justify weaker download checks.
- **Suppress background churn with reversible markers and test security defaults (chosen).** Keeps the Mac quiet and restores prior state when an option turns off.

## Consequences and trade-offs

- CleanMyMac runs only when the user launches it; its background monitors stay off.
- Spotlight skips excluded development and cache directories (`~/devv`, `~/.cache`); use `fd` or `rg` inside checkouts.
- **Reversal trigger:** If a project folder needs Spotlight indexing or a scheduled background helper, opt that target out in `hosts/darwin/default.nix`.
