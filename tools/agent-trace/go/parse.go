package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

const maxScanTokenSize = 512 * 1024 * 1024

type ParseContext struct {
	Path    string
	Project string
	Line    int
}

type FileParseStats struct {
	Path      string `json:"path"`
	Project   string `json:"project"`
	Records   int    `json:"records"`
	Malformed int    `json:"malformed"`
}

type RecordVisitor func(*Record, ParseContext) error

func ParseFile(path, project string, visit RecordVisitor) (FileParseStats, error) {
	stats := FileParseStats{Path: path, Project: project}
	file, err := os.Open(path)
	if err != nil {
		return stats, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 1024*1024), maxScanTokenSize)
	lineNo := 0
	for scanner.Scan() {
		lineNo++
		line := scanner.Bytes()
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		record := &Record{}
		if err := json.Unmarshal(line, record); err != nil {
			stats.Malformed++
			continue
		}
		stats.Records++
		if visit != nil {
			if err := visit(record, ParseContext{Path: path, Project: project, Line: lineNo}); err != nil {
				return stats, err
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return stats, fmt.Errorf("scan %s: %w", path, err)
	}
	return stats, nil
}

func WalkTranscripts(root string, visit func(path, project string) error) error {
	root = expandPath(root)
	info, err := os.Stat(root)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		if strings.HasSuffix(info.Name(), ".jsonl") {
			return visit(root, filepath.Base(filepath.Dir(root)))
		}
		return nil
	}

	root = filepath.Clean(root)
	rootIsProject := hasDirectJSONL(root)
	return filepath.WalkDir(root, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == root {
			return nil
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		depth := pathDepth(rel)
		if d.IsDir() {
			return nil
		}
		if !strings.HasSuffix(d.Name(), ".jsonl") {
			return nil
		}
		project := filepath.Base(root)
		if !rootIsProject && depth >= 2 {
			project = strings.Split(rel, string(os.PathSeparator))[0]
		}
		return visit(path, project)
	})
}

func hasDirectJSONL(root string) bool {
	entries, err := os.ReadDir(root)
	if err != nil {
		return false
	}
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".jsonl") {
			return true
		}
	}
	return false
}

func pathDepth(rel string) int {
	if rel == "." || rel == "" {
		return 0
	}
	return strings.Count(rel, string(os.PathSeparator)) + 1
}

func expandPath(path string) string {
	if path == "~" {
		if home, err := os.UserHomeDir(); err == nil {
			return home
		}
	}
	if strings.HasPrefix(path, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, path[2:])
		}
	}
	return path
}

func sessionIDFor(record *Record, path string) string {
	if record.SessionID != "" {
		return record.SessionID
	}
	base := filepath.Base(path)
	return strings.TrimSuffix(base, filepath.Ext(base))
}
