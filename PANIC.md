# PANIC: rolling back an auto-update gone wrong

The `.github/workflows/auto-update.yml` opens a PR every day and auto-merges
it once `build.yml` is green. CI catches build-time regressions but not
runtime ones (a bumped binary may build fine and crash on first invocation).
This doc is the panic button for that case.

## 1. Pin one input back to a known-good version, no rebuild needed

Fastest mitigation. Targets a single misbehaving input without reverting other
bumps that landed in the same PR.

```bash
sudo nix run nix-darwin -- switch \
  --flake "$HOME/nix-config#Martins-Mac-mini" \
  --override-input claude-code github:sadjow/claude-code-nix?ref=v2.1.121
```

Substitute the input name (`claude-code`, `nixpkgs`, etc.) and a tag/ref you
trust. The override sticks for that single rebuild only — it does not touch
`flake.lock`, so a subsequent `nix flake update` will re-introduce the new
version.

To make the pin survive across rebuilds, edit `flake.nix` to add the `?ref=…`
back and commit.

## 2. Revert the most recent auto-merged PR

Reverses every bump in the last nightly. Use when you cannot tell which agent
broke and want a fast restore.

```bash
gh pr list --label auto-update --state merged --limit 1 \
  --json number -q '.[0].number' \
  | xargs -I {} gh pr revert {}
```

Then `git pull` on `main` and rebuild.

## 3. Stop the workflow

Renaming disables the workflow without deleting it.

```bash
git mv .github/workflows/auto-update.yml \
       .github/workflows/auto-update.yml.disabled
git commit -m "chore: pause auto-update"
git push
```

Re-enable by reverting the rename.

## 4. Recompute a stale Cachix substitution

If `claude-code.cachix.org` serves a corrupted derivation, override the
substituter for one rebuild:

```bash
sudo nix run nix-darwin -- switch \
  --flake "$HOME/nix-config#Martins-Mac-mini" \
  --option substituters https://cache.nixos.org \
  --option trusted-public-keys 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY='
```

Then file an issue at <https://github.com/sadjow/claude-code-nix/issues>.

## 5. Manual updater debugging

Each agent has its own `scripts/update-*.sh`. Run it locally to reproduce the
failure shown in the workflow log:

```bash
bash scripts/update-droid.sh   # or whichever bumper failed
```

The scripts bail loudly on parser anomalies; the error message names the
expected pattern and the input that didn't match.
