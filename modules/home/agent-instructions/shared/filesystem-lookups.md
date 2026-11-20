## Filesystem and Nix lookups

This host is macOS, so `stat`, `sed`, `date`, and `xargs` take BSD flags. Answer an ownership question in one or two calls, then act.

- **File details**: Use `eza -l PATH` or `stat -f '%z %Sm %N' PATH`. GNU `stat -c` fails here.
- **Nix owner**: To find what keeps a binary in the Nix store, run `readlink -f "$(command -v NAME)"`, then `nix-store --query --roots STORE_PATH` on that one path. To list every root of a package, run `nix-store --gc --print-roots | rg NAME` once. Stop when a root names the owner.
- **Scan scope**: Scan one repository or one named directory. Query Nix roots for one store path, or use the single `--print-roots` call above. `~/devv` holds 65k files of sibling checkouts, so search one checkout in it by name.
