## Python

- Run every Python command through `uv`.
- Script: `uv run script.py`. Declare standalone dependencies in PEP 723 metadata.
- One-liner: `uv run --with PACKAGE python -c '...'`.
- Project: `uv sync`, `uv add PACKAGE`, `uv run pytest`.
- Interpreter: set `requires-python` in `pyproject.toml` and pin with `uv python pin VERSION`.
- mise: in a project with `mise.toml`, mise pins only the uv version (`mise use uv@VERSION`). Run uv there as `mise exec -- uv ...`. When that uv reports `unrecognized subcommand 'check'`, bump the pin with `mise use uv@latest`.
- Save substantial Python as a `.py` file before execution.
- Check changed files with `ruff check --fix`, `ruff format`, and `uv check`. `uv check` runs ty for you.
- Script check: `uv check --script FILE.py`. The script needs PEP 723 metadata. `uv init --script FILE.py` adds it.
- Ruff: when the project lists ruff as a dependency, run `uv run ruff` for the locked version.
- Annotate the parameters and return type of each public function.
- Use a dataclass or TypedDict for structured data instead of a bare dict.
- Verify a small sample before the full workload.
