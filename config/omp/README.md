# OMP model routing

The active editable settings live in `~/.omp/agent/config.yml`.
Nix activation reconciles its routing fields from the shared semantic policy.
Other OMP settings remain writable and are preserved.
The first changed activation saves `config.yml.before-nix-routing`.
Nix also renders repeatable session presets from the same policy.

| Work | Normal model | Effort |
|---|---|---|
| Main, vision, task, design | GPT-6 Astra | high |
| Search, scout, explore, librarian, commit | GPT-6 Sol | medium |
| Check, review, security review, sonic, worker | GPT-6 Sol | high |
| Planning, Oracle | GPT-6 Astra | xhigh |
| Economy fallback | GPT-6 Luna | medium |

## Change routing

Edit `modules/shared/agent-model-routing.nix`.
The OMP adapter renders roles, agent assignments, enabled models, and fallback chains.
Activation applies routing edits to the active global config.
Session presets remain available through `--config`.

1. Activate the changed Nix configuration. Plain `omp` then uses normal routing.

2. Apply the normal preset explicitly for a single session:

   ```sh
   omp --config ~/.config/agent-routing/omp.yml
   ```

3. Start directly with the economy preset when you want lower consumption:

   ```sh
   omp --config ~/.config/agent-routing/omp-economy.yml
   ```

4. Inspect global routing after activation:

   ```sh
   omp config get modelRoles --json
   ```

The economy preset is complete and does not depend on config merge order.
It uses Luna for general work, four concurrent tasks, and no passive advisor.
Search and check jobs remain Sol in both presets. Planning remains Astra.

## Subscription limits and fallback

The normal preset enables usage-aware fallback with a 10% reserve and confirmation at the reserve boundary.
Astra can fall back to Luna. Luna has no automatic fallback.
Sol has no model fallback: exhausted Sol allowance must stop or wait for reset.
Retries are bounded; sessions do not sleep until a distant quota reset.

Every role and fallback chain uses the subscription-backed `openai-codex` provider.
The `/model` picker and `--model` expose GPT-6 Astra, Sol, and Luna, plus the
current Google Antigravity catalog—including Gemini Flash, Claude Opus, and Claude Sonnet.
No other provider is enabled.

GPT-6 models share allowance. Switching models can conserve usage but cannot create another allowance.
Check `omp usage --redact` and `omp models openai-codex` after login and when availability changes.
Unknown quota data does not establish available capacity. Next month's allowance is not guaranteed.

Subscription authentication alone cannot guarantee zero extra spending.
Existing ChatGPT credits can be consumed after included allowance ends.
Disable automatic purchases and verify account credit controls for a strict spending policy.
OMP's reserve check is a convenience, not a billing enforcement boundary.

Sources checked September 12, 2026:

- [Codex pricing and limits](https://developers.openai.com/codex/pricing)
- [Flexible usage credits](https://help.openai.com/en/articles/12642688-using-credits-for-flexible-usage-in-chatgpt-pluspro)

## Verification boundary

The routing unit test resolves every OMP agent through its semantic job.
Nix renders and parses both YAML presets.
The four custom agents are restored from their Nix-owned source definitions.
Live model requests and quota failover require current subscription capacity.
The config subcommand reads global settings; it does not display session overlay resolution.
