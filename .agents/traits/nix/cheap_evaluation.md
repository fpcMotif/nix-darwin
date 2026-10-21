---
paths: ["**/*.nix", "!references/**"]
when:
  - import
  - fetch
  - callPackage
  - readFile
  - nixpkgs
---
# Cheap Evaluation

Keep evaluation fast and pure. Build work belongs in derivations, never in eval.

Flag:
- A second nixpkgs instance (`import nixpkgs { ... }`, `import <nixpkgs>`) where the module's `pkgs` or an overlay would serve.
- Import from derivation: `import`, `readFile` or `fromJSON` on a derivation output.
- An eval-time fetch without a pinned hash (`builtins.fetchurl`, `fetchTarball`, `fetchGit` without `rev` and `narHash`), or any fetch a flake input or `pkgs.fetch*` could replace.
- An overlay that replaces a widely used nixpkgs attribute when a separate attribute would do, because it rebuilds every dependent from source and loses the binary cache.
- Expensive work repeated per element, such as `lib.filter` or `builtins.elem` over a long list inside `map`, where one `listToAttrs` lookup would serve.
