package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

type Options struct {
	Root   string
	Format string
}

type PromptOptions struct {
	Grep   string
	MinLen int
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "agent-trace:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	opts := Options{Root: "~/.claude/projects", Format: "table"}
	clean, err := consumeCommonFlags(args, &opts)
	if err != nil {
		return err
	}
	if opts.Format != "json" && opts.Format != "table" {
		return fmt.Errorf("--format must be json or table")
	}
	if len(clean) == 0 || clean[0] == "--help" || clean[0] == "-h" {
		printUsage()
		return nil
	}

	cmd := clean[0]
	cmdArgs := clean[1:]
	switch cmd {
	case "stats":
		if len(cmdArgs) != 0 {
			return fmt.Errorf("stats takes no positional arguments")
		}
		return RunStats(expandPath(opts.Root), opts.Format)
	case "prompts":
		promptOpts, err := parsePromptFlags(cmdArgs)
		if err != nil {
			return err
		}
		return RunPrompts(expandPath(opts.Root), opts.Format, promptOpts)
	case "flow":
		if len(cmdArgs) != 1 {
			return fmt.Errorf("flow requires exactly one session.jsonl path")
		}
		return RunFlow(expandPath(cmdArgs[0]), opts.Format)
	default:
		return fmt.Errorf("unknown command %q", cmd)
	}
}

func consumeCommonFlags(args []string, opts *Options) ([]string, error) {
	clean := make([]string, 0, len(args))
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--root":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("--root requires a path")
			}
			i++
			opts.Root = args[i]
		case strings.HasPrefix(arg, "--root="):
			opts.Root = strings.TrimPrefix(arg, "--root=")
		case arg == "--format":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("--format requires json or table")
			}
			i++
			opts.Format = args[i]
		case strings.HasPrefix(arg, "--format="):
			opts.Format = strings.TrimPrefix(arg, "--format=")
		default:
			clean = append(clean, arg)
		}
	}
	return clean, nil
}

func parsePromptFlags(args []string) (PromptOptions, error) {
	var opts PromptOptions
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--grep":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--grep requires a pattern")
			}
			i++
			opts.Grep = args[i]
		case strings.HasPrefix(arg, "--grep="):
			opts.Grep = strings.TrimPrefix(arg, "--grep=")
		case arg == "--min-len":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--min-len requires a number")
			}
			i++
			value, err := strconv.Atoi(args[i])
			if err != nil || value < 0 {
				return opts, fmt.Errorf("--min-len must be a non-negative integer")
			}
			opts.MinLen = value
		case strings.HasPrefix(arg, "--min-len="):
			value, err := strconv.Atoi(strings.TrimPrefix(arg, "--min-len="))
			if err != nil || value < 0 {
				return opts, fmt.Errorf("--min-len must be a non-negative integer")
			}
			opts.MinLen = value
		default:
			return opts, fmt.Errorf("unknown prompts argument %q", arg)
		}
	}
	return opts, nil
}

func printUsage() {
	fmt.Fprintln(os.Stderr, "usage: agent-trace [--root PATH] [--format json|table] <stats|prompts|flow> [args]")
	fmt.Fprintln(os.Stderr, "commands:")
	fmt.Fprintln(os.Stderr, "  stats                 aggregate transcript metrics")
	fmt.Fprintln(os.Stderr, "  prompts [--grep PAT] [--min-len N]")
	fmt.Fprintln(os.Stderr, "  flow <session.jsonl>  render uuid/parentUuid tree")
}
