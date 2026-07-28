package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"text/tabwriter"
)

type TokenTotals struct {
	Input         int64 `json:"input"`
	Output        int64 `json:"output"`
	CacheRead     int64 `json:"cacheRead"`
	CacheCreation int64 `json:"cacheCreation"`
}

type StatsAggregate struct {
	Root             string                   `json:"root"`
	Files            int                      `json:"files"`
	Sessions         int                      `json:"sessions"`
	Records          int                      `json:"records"`
	Malformed        int                      `json:"malformed"`
	RecordsByType    map[string]int           `json:"recordsByType"`
	ToolUses         map[string]int           `json:"toolUses"`
	Models           map[string]int           `json:"models"`
	Tokens           TokenTotals              `json:"tokens"`
	APIErrors        int                      `json:"apiErrors"`
	ToolResultErrors int                      `json:"toolResultErrors"`
	Projects         map[string]*ProjectStats `json:"projects"`
	sessions         map[string]struct{}      `json:"-"`
}

type ProjectStats struct {
	Files            int            `json:"files"`
	Sessions         int            `json:"sessions"`
	Records          int            `json:"records"`
	Malformed        int            `json:"malformed"`
	RecordsByType    map[string]int `json:"recordsByType"`
	APIErrors        int            `json:"apiErrors"`
	ToolResultErrors int            `json:"toolResultErrors"`
	Tokens           TokenTotals    `json:"tokens"`
	sessions         map[string]struct{}
}

func NewStats(root string) *StatsAggregate {
	return &StatsAggregate{
		Root:          root,
		RecordsByType: make(map[string]int),
		ToolUses:      make(map[string]int),
		Models:        make(map[string]int),
		Projects:      make(map[string]*ProjectStats),
		sessions:      make(map[string]struct{}),
	}
}

func (s *StatsAggregate) project(name string) *ProjectStats {
	project := s.Projects[name]
	if project == nil {
		project = &ProjectStats{RecordsByType: make(map[string]int), sessions: make(map[string]struct{})}
		s.Projects[name] = project
	}
	return project
}

func RunStats(root, format string) error {
	stats := NewStats(root)
	err := WalkTranscripts(root, func(path, project string) error {
		stats.Files++
		projectStats := stats.project(project)
		projectStats.Files++
		fileStats, err := ParseFile(path, project, func(record *Record, ctx ParseContext) error {
			stats.AddRecord(record, ctx)
			return nil
		})
		stats.Malformed += fileStats.Malformed
		projectStats.Malformed += fileStats.Malformed
		return err
	})
	if err != nil {
		return err
	}
	stats.Finish()
	if format == "json" {
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		return encoder.Encode(stats)
	}
	return stats.PrintTable()
}

func (s *StatsAggregate) AddRecord(record *Record, ctx ParseContext) {
	projectStats := s.project(ctx.Project)
	s.Records++
	projectStats.Records++

	sessionID := sessionIDFor(record, ctx.Path)
	s.sessions[sessionID] = struct{}{}
	projectStats.sessions[sessionID] = struct{}{}

	recordType := bucketRecordType(record.Type)
	s.RecordsByType[recordType]++
	projectStats.RecordsByType[recordType]++

	if record.Type == "assistant" && record.Message != nil {
		if record.Message.Model != "" {
			s.Models[record.Message.Model]++
		}
		addUsage(&s.Tokens, record.Message.Usage)
		addUsage(&projectStats.Tokens, record.Message.Usage)
	}
	for _, name := range record.ToolUseNames() {
		s.ToolUses[name]++
	}
	if record.HasAPIError() {
		s.APIErrors++
		projectStats.APIErrors++
	}
	if record.HasToolError() {
		s.ToolResultErrors++
		projectStats.ToolResultErrors++
	}
}

func (s *StatsAggregate) Finish() {
	s.Sessions = len(s.sessions)
	for _, project := range s.Projects {
		project.Sessions = len(project.sessions)
	}
}

func addUsage(tokens *TokenTotals, usage *Usage) {
	if usage == nil {
		return
	}
	if usage.InputTokens != nil {
		tokens.Input += *usage.InputTokens
	}
	if usage.OutputTokens != nil {
		tokens.Output += *usage.OutputTokens
	}
	if usage.CacheReadInputTokens != nil {
		tokens.CacheRead += *usage.CacheReadInputTokens
	}
	if usage.CacheCreationInputTokens != nil {
		tokens.CacheCreation += *usage.CacheCreationInputTokens
	}
}

func (s *StatsAggregate) PrintTable() error {
	writer := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintf(writer, "Root:\t%s\n", s.Root)
	fmt.Fprintf(writer, "Files:\t%d\n", s.Files)
	fmt.Fprintf(writer, "Sessions:\t%d\n", s.Sessions)
	fmt.Fprintf(writer, "Records:\t%d\n", s.Records)
	fmt.Fprintf(writer, "Malformed:\t%d\n", s.Malformed)
	fmt.Fprintf(writer, "API errors:\t%d\n", s.APIErrors)
	fmt.Fprintf(writer, "Tool result errors:\t%d\n", s.ToolResultErrors)
	fmt.Fprintf(writer, "Tokens:\tinput=%d output=%d cache-read=%d cache-creation=%d\n", s.Tokens.Input, s.Tokens.Output, s.Tokens.CacheRead, s.Tokens.CacheCreation)

	fmt.Fprintln(writer, "\nRecords by type")
	fmt.Fprintln(writer, "TYPE\tCOUNT")
	for _, item := range sortedCounts(s.RecordsByType) {
		fmt.Fprintf(writer, "%s\t%d\n", item.Key, item.Value)
	}

	fmt.Fprintln(writer, "\nTool use histogram")
	fmt.Fprintln(writer, "TOOL\tCOUNT")
	for _, item := range sortedCounts(s.ToolUses) {
		fmt.Fprintf(writer, "%s\t%d\n", item.Key, item.Value)
	}

	fmt.Fprintln(writer, "\nModels")
	fmt.Fprintln(writer, "MODEL\tCOUNT")
	for _, item := range sortedCounts(s.Models) {
		fmt.Fprintf(writer, "%s\t%d\n", item.Key, item.Value)
	}

	fmt.Fprintln(writer, "\nProjects")
	fmt.Fprintln(writer, "PROJECT\tFILES\tSESSIONS\tRECORDS\tMALFORMED\tAPI_ERRORS\tTOOL_ERRORS\tINPUT\tOUTPUT")
	projectNames := make([]string, 0, len(s.Projects))
	for name := range s.Projects {
		projectNames = append(projectNames, name)
	}
	sort.Strings(projectNames)
	for _, name := range projectNames {
		project := s.Projects[name]
		fmt.Fprintf(writer, "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", name, project.Files, project.Sessions, project.Records, project.Malformed, project.APIErrors, project.ToolResultErrors, project.Tokens.Input, project.Tokens.Output)
	}
	return writer.Flush()
}

type countItem struct {
	Key   string
	Value int
}

func sortedCounts(counts map[string]int) []countItem {
	items := make([]countItem, 0, len(counts))
	for key, value := range counts {
		items = append(items, countItem{Key: key, Value: value})
	}
	sort.Slice(items, func(i, j int) bool {
		if items[i].Value == items[j].Value {
			return items[i].Key < items[j].Key
		}
		return items[i].Value > items[j].Value
	})
	return items
}
