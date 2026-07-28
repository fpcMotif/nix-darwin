import argparse
import json
import sys

from . import __version__
from . import flow as flow_mod
from . import prompts as prompts_mod
from . import stats as stats_mod


def _json_dump(value):
    return json.dumps(value, indent=2, ensure_ascii=False)


def build_parser():
    parser = argparse.ArgumentParser(
        prog="agent-trace",
        description="Stream Claude Code JSONL transcripts for stats, prompt inventory, and flow rendering.",
    )
    parser.add_argument("--root", dest="global_root", default="~/.claude/projects", help="transcript root (default: ~/.claude/projects)")
    parser.add_argument("--format", dest="global_format", choices=("json", "table"), default="table", help="output format")
    parser.add_argument("--version", action="version", version="agent-trace " + __version__)

    subparsers = parser.add_subparsers(dest="command", required=True)

    def add_common_options(command_parser):
        command_parser.add_argument("--root", default=None, help=argparse.SUPPRESS)
        command_parser.add_argument("--format", choices=("json", "table"), default=None, help=argparse.SUPPRESS)

    stats_parser = subparsers.add_parser("stats", help="aggregate transcript statistics")
    add_common_options(stats_parser)

    prompts_parser = subparsers.add_parser("prompts", help="list first human prompt per session")
    add_common_options(prompts_parser)
    prompts_parser.add_argument("--grep", default=None, help="case-insensitive substring filter for prompt text")
    prompts_parser.add_argument("--min-len", default=0, type=int, help="minimum prompt length")

    flow_parser = subparsers.add_parser("flow", help="render a uuid/parentUuid tree for one session")
    flow_parser.add_argument("session", help="path to a session .jsonl file")
    add_common_options(flow_parser)

    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    root = args.root if getattr(args, "root", None) is not None else args.global_root
    output_format = args.format if getattr(args, "format", None) is not None else args.global_format


    if args.command == "stats":
        data = stats_mod.aggregate(root)
        if output_format == "json":
            print(_json_dump(stats_mod.to_jsonable(data)))
        else:
            print(stats_mod.format_table(data))
        return 0

    if args.command == "prompts":
        data = prompts_mod.collect(root, grep=args.grep, min_len=args.min_len)
        if output_format == "json":
            print(_json_dump(data))
        else:
            print(prompts_mod.format_table(data))
        return 0

    if args.command == "flow":
        data = flow_mod.render(args.session)
        if output_format == "json":
            print(_json_dump(data))
        else:
            print(flow_mod.format_table(data))
        return 0

    parser.error("unknown command: " + str(args.command))
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        try:
            sys.stdout.close()
        except BrokenPipeError:
            pass
        sys.exit(0)
