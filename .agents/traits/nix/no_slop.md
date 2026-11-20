---
paths: ["**/*.nix", "!references/**"]
---
# No Slop

Write the smallest Nix that states the intent. Each binding, branch and option earns its place.

Flag:
- A `let` binding, helper function or wrapper used once whose name adds nothing over the inline expression.
- Defensive code for cases that cannot happen: `or null`, `or {}`, `lib.optional true`, `mkIf true`, an `if` on a value the module already guarantees.
- Restating a default: setting an option to its default value, or `lib.mkDefault` with no competing definition.
- Near-duplicate attribute sets or lists that differ in one field. Generate them from one list with `map`, `lib.genAttrs` or `lib.mapAttrs`.
- `rec`, `with pkgs;` or `with lib;` over a large scope, where explicit names would show where each value comes from.
- An abstraction with one caller, such as a custom option, a module argument or a generator function.

Exempt: a repetition that matches a sibling file's established pattern, such as each `pkgs/*-bin.nix` listing its own platforms.
