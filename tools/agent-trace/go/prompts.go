package main

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"sort"
	"text/tabwriter"
	"time"
)

type PromptRow struct {
	Timestamp string `json:"timestamp"`
	Project   string `json:"project"`
	SessionID string `json:"sessionId"`
	Source    string `json:"source"`
	Length    int    `json:"length"`
	Prompt    string `json:"prompt"`
	order     int
	sortTime  time.Time
	hasTime   bool
}

type promptCandidates struct {
	queue *PromptRow
	user  *PromptRow
}

func RunPrompts(root, format string, opts PromptOptions) error {
	var matcher *regexp.Regexp
	if opts.Grep != "" {
		compiled, err := regexp.Compile(opts.Grep)
		if err != nil {
			return err
		}
		matcher = compiled
	}

	candidates := make(map[string]*promptCandidates)
	order := 0
	err := WalkTranscripts(root, func(path, project string) error {
		_, err := ParseFile(path, project, func(record *Record, ctx ParseContext) error {
			order++
			sessionID := sessionIDFor(record, ctx.Path)
			candidate := candidates[sessionID]
			if candidate == nil {
				candidate = &promptCandidates{}
				candidates[sessionID] = candidate
			}
			if text, ok := record.QueuePrompt(); ok {
				row := makePromptRow(record, ctx.Project, sessionID, "queue", text, order)
				if candidate.queue == nil || row.order < candidate.queue.order {
					candidate.queue = row
				}
			}
			if text, ok := record.HumanPrompt(); ok {
				row := makePromptRow(record, ctx.Project, sessionID, "user", text, order)
				if candidate.user == nil || row.order < candidate.user.order {
					candidate.user = row
				}
			}
			return nil
		})
		return err
	})
	if err != nil {
		return err
	}

	rows := make([]*PromptRow, 0, len(candidates))
	for _, candidate := range candidates {
		row := candidate.user
		if candidate.queue != nil {
			row = candidate.queue
		}
		if row == nil {
			continue
		}
		if row.Length < opts.MinLen {
			continue
		}
		if matcher != nil && !matcher.MatchString(row.Prompt) {
			continue
		}
		rows = append(rows, row)
	}
	sortPromptRows(rows)

	if format == "json" {
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		return encoder.Encode(rows)
	}
	return printPromptsTable(rows)
}

func makePromptRow(record *Record, project, sessionID, source, text string, order int) *PromptRow {
	parsed, hasTime := parseTimestamp(record.Timestamp)
	return &PromptRow{
		Timestamp: record.Timestamp,
		Project:   project,
		SessionID: sessionID,
		Source:    source,
		Length:    len(text),
		Prompt:    text,
		order:     order,
		sortTime:  parsed,
		hasTime:   hasTime,
	}
}

func sortPromptRows(rows []*PromptRow) {
	sort.Slice(rows, func(i, j int) bool {
		left := rows[i]
		right := rows[j]
		if left.hasTime && right.hasTime && !left.sortTime.Equal(right.sortTime) {
			return left.sortTime.Before(right.sortTime)
		}
		if left.Timestamp != right.Timestamp {
			return left.Timestamp < right.Timestamp
		}
		if left.Project != right.Project {
			return left.Project < right.Project
		}
		return left.SessionID < right.SessionID
	})
}

func printPromptsTable(rows []*PromptRow) error {
	writer := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(writer, "TIMESTAMP\tPROJECT\tSESSION\tSOURCE\tLEN\tPROMPT")
	for _, row := range rows {
		fmt.Fprintf(writer, "%s\t%s\t%s\t%s\t%d\t%s\n", row.Timestamp, row.Project, row.SessionID, row.Source, row.Length, oneLine(row.Prompt, 180))
	}
	return writer.Flush()
}

func parseTimestamp(value string) (time.Time, bool) {
	if value == "" {
		return time.Time{}, false
	}
	parsed, err := time.Parse(time.RFC3339Nano, value)
	if err != nil {
		return time.Time{}, false
	}
	return parsed, true
}
