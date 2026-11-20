---
paths: ["**/*.nix", "!references/**"]
when:
  - activation
  - writeShellScript
  - runCommand
  - launchd
  - postInstall
---
# Declarative First

State the desired result as module options, derivations and files from Nix, and let Nix compute it. Use imperative steps only where no option or derivation can express the result.

Flag:
- An activation script, launchd job or shell hook that writes a file `home.file`, `xdg.configFile` or `environment.etc` could own.
- An activation step that installs, downloads or mutates state outside the store when a package or option could do it.
- An activation step that is not idempotent: a second run must change nothing.
- Shell that parses or rewrites Nix-managed config at runtime instead of generating it with `builtins.toJSON`, `lib.generators` or `pkgs.formats`.

Exempt: steps an ADR records as imperative on purpose, and state that must stay writable by the app.
