# dev-shell template

Seed for a per-project pinned dev environment:

```bash
nix flake init -t ~/nix-config#dev-shell   # or <github:fpcMotif/nix-darwin>#dev-shell
direnv allow                               # auto-enters the shell on cd
```

Add the project's toolchain to `packages` in `flake.nix`, then commit both
`flake.nix` and the generated `flake.lock`. The lock file is what makes the
environment reproducible across machines (Mac, Linux, WSL, containers).

Without direnv, enter the shell manually with `nix develop`.
