package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
)

type FlowEntry struct {
	ID        string `json:"id"`
	ParentID  string `json:"parentId,omitempty"`
	Depth     int    `json:"depth"`
	Line      int    `json:"line"`
	Timestamp string `json:"timestamp,omitempty"`
	Type      string `json:"type"`
	Sidechain bool   `json:"sidechain"`
	APIError  bool   `json:"apiError"`
	ToolError bool   `json:"toolError"`
	Details   string `json:"details,omitempty"`
	children  []*FlowEntry
}

type FlowOutput struct {
	Path      string       `json:"path"`
	Records   int          `json:"records"`
	Malformed int          `json:"malformed"`
	Nodes     []*FlowEntry `json:"nodes"`
}

func RunFlow(path, format string) error {
	project := ""
	nodesByID := make(map[string]*FlowEntry)
	ordered := make([]*FlowEntry, 0)
	fileStats, err := ParseFile(path, project, func(record *Record, ctx ParseContext) error {
		id := record.UUID
		if id == "" {
			id = fmt.Sprintf("line:%d", ctx.Line)
		}
		if _, exists := nodesByID[id]; exists {
			id = fmt.Sprintf("%s#line:%d", id, ctx.Line)
		}
		entry := &FlowEntry{
			ID:        id,
			ParentID:  record.Parent(),
			Line:      ctx.Line,
			Timestamp: record.Timestamp,
			Type:      bucketRecordType(record.Type),
			Sidechain: record.IsSidechain.Bool(),
			APIError:  record.HasAPIError(),
			ToolError: record.HasToolError(),
			Details:   describeRecord(record),
		}
		nodesByID[id] = entry
		ordered = append(ordered, entry)
		return nil
	})
	if err != nil {
		return err
	}

	roots := buildFlowTree(ordered, nodesByID)
	rows := flattenFlow(roots, ordered)
	if format == "json" {
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		return encoder.Encode(FlowOutput{Path: path, Records: fileStats.Records, Malformed: fileStats.Malformed, Nodes: rows})
	}
	return printFlowTable(path, fileStats, rows)
}

func buildFlowTree(ordered []*FlowEntry, nodesByID map[string]*FlowEntry) []*FlowEntry {
	roots := make([]*FlowEntry, 0)
	for _, node := range ordered {
		if node.ParentID != "" && node.ParentID != node.ID {
			if parent := nodesByID[node.ParentID]; parent != nil {
				parent.children = append(parent.children, node)
				continue
			}
		}
		roots = append(roots, node)
	}
	sort.Slice(roots, func(i, j int) bool { return roots[i].Line < roots[j].Line })
	for _, node := range ordered {
		sort.Slice(node.children, func(i, j int) bool { return node.children[i].Line < node.children[j].Line })
	}
	return roots
}

func flattenFlow(roots, ordered []*FlowEntry) []*FlowEntry {
	rows := make([]*FlowEntry, 0, len(ordered))
	visited := make(map[string]bool)
	var walk func(*FlowEntry, int)
	walk = func(node *FlowEntry, depth int) {
		if visited[node.ID] {
			return
		}
		visited[node.ID] = true
		node.Depth = depth
		rows = append(rows, node)
		for _, child := range node.children {
			walk(child, depth+1)
		}
	}
	for _, root := range roots {
		walk(root, 0)
	}
	for _, node := range ordered {
		if !visited[node.ID] {
			walk(node, 0)
		}
	}
	return rows
}

func describeRecord(record *Record) string {
	parts := make([]string, 0)
	switch record.Type {
	case "assistant":
		if record.Message != nil && record.Message.Model != "" {
			parts = append(parts, "model="+record.Message.Model)
		}
		if names := record.ToolUseNames(); len(names) > 0 {
			parts = append(parts, "tools="+strings.Join(names, ","))
		}
	case "user":
		if text, ok := record.HumanPrompt(); ok {
			parts = append(parts, "prompt=\""+oneLine(text, 120)+"\"")
		} else if record.HasToolError() {
			parts = append(parts, "tool_result_error")
		} else if record.Message != nil && len(record.Message.Content.Blocks) > 0 {
			parts = append(parts, fmt.Sprintf("tool_results=%d", len(record.Message.Content.Blocks)))
		}
	case "queue-operation":
		if record.Operation != "" {
			parts = append(parts, "op="+record.Operation)
		}
		if text, ok := record.QueuePrompt(); ok {
			parts = append(parts, "content=\""+oneLine(text, 120)+"\"")
		}
	default:
		if record.Message != nil && record.Message.Content.Text != nil {
			parts = append(parts, "text=\""+oneLine(*record.Message.Content.Text, 120)+"\"")
		}
	}
	return strings.Join(parts, " ")
}

func printFlowTable(path string, stats FileParseStats, rows []*FlowEntry) error {
	fmt.Printf("file: %s\n", path)
	fmt.Printf("records: %d malformed: %d\n", stats.Records, stats.Malformed)
	for _, row := range rows {
		flags := make([]string, 0, 3)
		if row.Sidechain {
			flags = append(flags, "sidechain")
		}
		if row.APIError {
			flags = append(flags, "API_ERROR")
		}
		if row.ToolError {
			flags = append(flags, "TOOL_ERROR")
		}
		flagText := ""
		if len(flags) > 0 {
			flagText = " [" + strings.Join(flags, ",") + "]"
		}
		fmt.Printf("%s- %s %s %s%s", strings.Repeat("  ", row.Depth), row.Timestamp, shortID(row.ID), row.Type, flagText)
		if row.Details != "" {
			fmt.Printf(" %s", row.Details)
		}
		fmt.Println()
	}
	return nil
}
