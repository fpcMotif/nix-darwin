package main

import (
	"encoding/json"
	"strings"
)

type BoolValue struct {
	Set   bool
	Value bool
}

func (b *BoolValue) UnmarshalJSON(data []byte) error {
	var value bool
	if err := json.Unmarshal(data, &value); err == nil {
		b.Set = true
		b.Value = value
	}
	return nil
}

func (b BoolValue) Bool() bool {
	return b.Set && b.Value
}

type JSONString struct {
	Set   bool
	Value string
	Raw   json.RawMessage
}

func (s *JSONString) UnmarshalJSON(data []byte) error {
	s.Raw = append(s.Raw[:0], data...)
	var value string
	if err := json.Unmarshal(data, &value); err == nil {
		s.Set = true
		s.Value = value
	}
	return nil
}

type MessageContent struct {
	Raw    json.RawMessage
	Text   *string
	Blocks []ContentBlock
}

func (c *MessageContent) UnmarshalJSON(data []byte) error {
	c.Raw = append(c.Raw[:0], data...)
	var text string
	if err := json.Unmarshal(data, &text); err == nil {
		c.Text = &text
		return nil
	}
	var blocks []ContentBlock
	if err := json.Unmarshal(data, &blocks); err == nil {
		c.Blocks = blocks
	}
	return nil
}

type ContentBlock struct {
	Type      string          `json:"type"`
	Name      string          `json:"name,omitempty"`
	ID        string          `json:"id,omitempty"`
	ToolUseID string          `json:"tool_use_id,omitempty"`
	IsError   BoolValue       `json:"is_error,omitempty"`
	Content   json.RawMessage `json:"content,omitempty"`
	Input     json.RawMessage `json:"input,omitempty"`
}

type Usage struct {
	InputTokens              *int64 `json:"input_tokens"`
	OutputTokens             *int64 `json:"output_tokens"`
	CacheCreationInputTokens *int64 `json:"cache_creation_input_tokens"`
	CacheReadInputTokens     *int64 `json:"cache_read_input_tokens"`
}

type Message struct {
	ID      string         `json:"id"`
	Model   string         `json:"model"`
	Role    string         `json:"role"`
	Content MessageContent `json:"content"`
	Usage   *Usage         `json:"usage"`
}

type ToolUseResult struct {
	Raw     json.RawMessage `json:"-"`
	IsError BoolValue       `json:"is_error"`
}

func (t *ToolUseResult) UnmarshalJSON(data []byte) error {
	t.Raw = append(t.Raw[:0], data...)
	var probe struct {
		IsError BoolValue `json:"is_error"`
	}
	_ = json.Unmarshal(data, &probe)
	t.IsError = probe.IsError
	return nil
}

type Record struct {
	Type              string          `json:"type"`
	UUID              string          `json:"uuid"`
	ParentUUID        *string         `json:"parentUuid"`
	SessionID         string          `json:"sessionId"`
	Timestamp         string          `json:"timestamp"`
	CWD               string          `json:"cwd"`
	IsSidechain       BoolValue       `json:"isSidechain"`
	Message           *Message        `json:"message"`
	IsAPIErrorMessage BoolValue       `json:"isApiErrorMessage"`
	APIErrorStatus    json.RawMessage `json:"apiErrorStatus"`
	Error             json.RawMessage `json:"error"`
	IsMeta            BoolValue       `json:"isMeta"`
	ToolUseResult     *ToolUseResult  `json:"toolUseResult"`
	Operation         string          `json:"operation"`
	Content           JSONString      `json:"content"`
}

func (r *Record) Parent() string {
	if r.ParentUUID == nil {
		return ""
	}
	return *r.ParentUUID
}

func (r *Record) HumanPrompt() (string, bool) {
	if r.Type != "user" || r.IsMeta.Bool() || r.Message == nil || r.Message.Content.Text == nil {
		return "", false
	}
	text := *r.Message.Content.Text
	if strings.TrimSpace(text) == "" {
		return "", false
	}
	return text, true
}

func (r *Record) QueuePrompt() (string, bool) {
	if r.Type != "queue-operation" || r.Operation != "enqueue" || !r.Content.Set {
		return "", false
	}
	if strings.TrimSpace(r.Content.Value) == "" {
		return "", false
	}
	return r.Content.Value, true
}

func (r *Record) ToolUseNames() []string {
	if r.Message == nil {
		return nil
	}
	names := make([]string, 0)
	for _, block := range r.Message.Content.Blocks {
		if block.Type != "tool_use" {
			continue
		}
		name := block.Name
		if name == "" {
			name = "(unknown)"
		}
		names = append(names, name)
	}
	return names
}

func (r *Record) HasAPIError() bool {
	if r.Type != "assistant" {
		return false
	}
	return r.IsAPIErrorMessage.Bool() || rawPresent(r.APIErrorStatus) || rawPresent(r.Error)
}

func (r *Record) HasToolError() bool {
	if r.ToolUseResult != nil && r.ToolUseResult.IsError.Bool() {
		return true
	}
	if r.Message == nil {
		return false
	}
	for _, block := range r.Message.Content.Blocks {
		if block.Type == "tool_result" && block.IsError.Bool() {
			return true
		}
	}
	return false
}

func rawPresent(raw json.RawMessage) bool {
	trimmed := strings.TrimSpace(string(raw))
	return trimmed != "" && trimmed != "null"
}

func bucketRecordType(recordType string) string {
	switch recordType {
	case "assistant", "user", "attachment", "last-prompt", "queue-operation", "mode", "system", "pr-link", "custom-title", "summary":
		return recordType
	default:
		return "other"
	}
}

func shortID(id string) string {
	if len(id) <= 8 {
		return id
	}
	return id[:8]
}

func oneLine(text string, limit int) string {
	joined := strings.Join(strings.Fields(text), " ")
	if limit <= 0 {
		return joined
	}
	runes := []rune(joined)
	if len(runes) <= limit {
		return joined
	}
	return string(runes[:limit]) + "..."
}
