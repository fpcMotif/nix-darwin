#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Time a shell's first prompt and first command in a real pseudo-terminal.

`shell -i -c exit` never draws a prompt, so it cannot show when a terminal is
ready. This starts the shell the way a terminal does, waits for the prompt
marker, types one command, and waits for that command's output. Repeated runs
give a distribution.

Commands are typed with a leading space, which both zsh (HIST_IGNORE_SPACE)
and fish keep out of history.
"""

import argparse
import os
import pty
import select
import signal
import statistics
import sys
import time

COMMAND = b" printf '%s%s\\n' FIRST CMD\r"
COMMAND_OUTPUT = b"FIRSTCMD"

# Primary device attributes request. fish 4 sends it after its other terminal
# queries and waits for the answer, which a real terminal gives at once.
DA1_QUERIES = (b"\x1b[c", b"\x1b[0c")
DA1_ANSWER = b"\x1b[?62;22c"


def read_until(fd: int, marker: bytes, deadline: float, buf: bytearray) -> float | None:
    """Read from fd into buf until marker appears; return the time it did."""
    while marker not in buf:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return None
        ready, _, _ = select.select([fd], [], [], remaining)
        if not ready:
            continue
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            return None
        if not chunk:
            return None
        if any(query in chunk for query in DA1_QUERIES):
            os.write(fd, DA1_ANSWER)
        buf.extend(chunk)
    return time.monotonic()


def one_run(
    argv: list[str], env: dict[str, str], cwd: str, marker: bytes, timeout: float
) -> tuple[float, float]:
    """Return (ms to first prompt, ms from typing to command output)."""
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(cwd)
        os.execvpe(argv[0], argv, env)
    start = time.monotonic()
    buf = bytearray()
    try:
        prompt_at = read_until(fd, marker, start + timeout, buf)
        if prompt_at is None:
            raise TimeoutError(
                f"no prompt marker within {timeout}s; output: {bytes(buf[-400:])!r}"
            )
        buf.clear()
        typed_at = time.monotonic()
        os.write(fd, COMMAND)
        output_at = read_until(fd, COMMAND_OUTPUT, typed_at + timeout, buf)
        if output_at is None:
            raise TimeoutError(
                f"no command output within {timeout}s; output: {bytes(buf[-400:])!r}"
            )
        return (prompt_at - start) * 1000, (output_at - typed_at) * 1000
    finally:
        # The measurement is done; kill rather than wait for a clean exit.
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        os.waitpid(pid, 0)
        os.close(fd)


def summary(label: str, samples: list[float]) -> str:
    ordered = sorted(samples)
    p90 = ordered[min(len(ordered) - 1, int(len(ordered) * 0.9))]
    return (
        f"{label:<14} median {statistics.median(ordered):7.1f} ms  mean {statistics.fmean(ordered):7.1f} ms  "
        f"p90 {p90:7.1f} ms  min {ordered[0]:7.1f} ms  max {ordered[-1]:7.1f} ms  (n={len(ordered)})"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--runs", type=int, default=20)
    parser.add_argument("--warmup", type=int, default=3)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument(
        "--marker", default="❯", help="text the prompt prints (default: ❯)"
    )
    parser.add_argument(
        "--cwd", default=os.getcwd(), help="directory the shell starts in"
    )
    parser.add_argument(
        "--set",
        action="append",
        default=[],
        metavar="KEY=VALUE",
        help="extra child environment",
    )
    parser.add_argument("argv", nargs="+", help="shell command line, e.g. /bin/zsh -l")
    args = parser.parse_args()

    # A terminal launched from the Dock starts from launchd's small environment.
    env = {
        "HOME": os.environ["HOME"],
        "USER": os.environ.get("USER", ""),
        "LOGNAME": os.environ.get("USER", ""),
        "TERM": "xterm-256color",
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
    }
    for item in args.set:
        key, _, value = item.partition("=")
        env[key] = value

    marker = args.marker.encode()
    for _ in range(args.warmup):
        one_run(args.argv, env, args.cwd, marker, args.timeout)
    prompts, commands = [], []
    for _ in range(args.runs):
        prompt_ms, command_ms = one_run(args.argv, env, args.cwd, marker, args.timeout)
        prompts.append(prompt_ms)
        commands.append(command_ms)

    print(
        f"First prompt and first command: {' '.join(args.argv)} (warmup {args.warmup}, runs {args.runs})"
    )
    print(summary("first prompt", prompts))
    print(summary("command lag", commands))
    return 0


if __name__ == "__main__":
    sys.exit(main())
