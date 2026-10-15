## Python

- Run every Python command through `uv`.
- Script: `uv run script.py`. Declare standalone dependencies in PEP 723 metadata.
- One-liner: `uv run --with PACKAGE python -c '...'`.
- Project: `uv sync`, `uv add PACKAGE`, `uv run pytest`.
- Save substantial Python as a `.py` file before execution.
- Check changed files with `ruff check --fix`, `ruff format`, and `uvx ty check`.
- Annotate the parameters and return type of each public function.
- Use a dataclass or TypedDict for structured data instead of a bare dict.
- Verify a small sample before the full workload.
