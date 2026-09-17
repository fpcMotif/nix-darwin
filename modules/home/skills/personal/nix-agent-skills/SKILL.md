---
name: nix-agent-skills
description: "Add, update, and verify declarative agent skills across all agent targets in ~/nix-config using agent-skills-nix"
---

# Declarative Agent Skills Management via Nix

Procedure for adding, updating, and verifying agent skills across all AI agent targets (`~/.claude/skills`, `~/.agents/skills`, `~/.cursor/skills`, `~/.pi/agent/skills`, etc.) using `agent-skills-nix` in `~/nix-config`.

## Adding an Upstream Git Skill

1. Add flake input in `~/nix-config/flake.nix`:
   ```nix
   <skill-name> = {
     url = "github:<owner>/<repo>";
     flake = false;
   };
   ```

2. Wire source and enable in `~/nix-config/modules/home/claude.nix`:
   ```nix
   sources = {
     <skill-name> = mkSource "<skill-name>" "." null;
   };

   skills = {
     enable = enabledMattpocockSkills ++ [ "<skill-name>" ];
   };
   ```

3. Update lockfile and stage changes:
   ```bash
   cd ~/nix-config
   nix flake lock --update-input <skill-name>
   git add flake.nix flake.lock modules/home/claude.nix
   ```

4. Build and activate Home Manager generation:
   ```bash
   nix build --no-link .#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage
   $(nix eval --raw .#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage)/activate
   ```

5. Verify multi-agent health:
   ```bash
   just verify-skills
   ```

## Updating Existing Pinned Skills

```bash
nix flake update <skill-name> --flake ~/nix-config
cd ~/nix-config && $(nix eval --raw .#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage)/activate
```

## Auditing Skill Quality & Frontmatter

Run `skill-doctor` on specific skill targets:
```bash
bunx skill-doctor ~/.claude/skills/<skill-name>
```

Common fixes:
- Replace angle brackets in `description` (e.g. `<site>`) with `[site]` to prevent XML parser errors.
- Ensure skill name is kebab-case.
- Replace relative markdown links pointing outside the skill bundle with code blocks.
