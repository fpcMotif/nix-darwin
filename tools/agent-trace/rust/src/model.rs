#![allow(dead_code)]

use serde::{Deserialize, Deserializer};
use serde_json::{Map, Value};

#[derive(Debug, Clone, Deserialize, Default)]
pub struct Record {
    #[serde(rename = "type", default)]
    pub record_type: Option<String>,
    #[serde(default)]
    pub uuid: Option<String>,
    #[serde(rename = "parentUuid", default)]
    pub parent_uuid: Option<String>,
    #[serde(rename = "sessionId", default)]
    pub session_id: Option<String>,
    #[serde(default)]
    pub timestamp: Option<String>,
    #[serde(default)]
    pub cwd: Option<String>,
    #[serde(rename = "gitBranch", default)]
    pub git_branch: Option<String>,
    #[serde(default)]
    pub version: Option<String>,
    #[serde(rename = "userType", default)]
    pub user_type: Option<String>,
    #[serde(default)]
    pub entrypoint: Option<String>,
    #[serde(rename = "isSidechain", default)]
    pub is_sidechain: Option<bool>,

    #[serde(rename = "requestId", default)]
    pub request_id: Option<String>,
    #[serde(rename = "isApiErrorMessage", default)]
    pub is_api_error_message: Option<bool>,
    #[serde(rename = "apiErrorStatus", default)]
    pub api_error_status: Option<Value>,
    #[serde(default)]
    pub error: Option<Value>,
    #[serde(rename = "attributionSkill", default)]
    pub attribution_skill: Option<String>,
    #[serde(rename = "attributionMcpServer", default)]
    pub attribution_mcp_server: Option<String>,
    #[serde(rename = "attributionMcpTool", default)]
    pub attribution_mcp_tool: Option<String>,
    #[serde(rename = "attributionPlugin", default)]
    pub attribution_plugin: Option<String>,

    #[serde(default)]
    pub message: Option<Message>,

    #[serde(default)]
    pub operation: Option<String>,
    #[serde(default)]
    pub content: Option<Value>,

    #[serde(rename = "isMeta", default)]
    pub is_meta: Option<bool>,
    #[serde(rename = "permissionMode", default)]
    pub permission_mode: Option<String>,
    #[serde(rename = "promptSource", default)]
    pub prompt_source: Option<String>,
    #[serde(rename = "promptId", default)]
    pub prompt_id: Option<String>,
    #[serde(rename = "toolUseResult", default)]
    pub tool_use_result: Option<Value>,
    #[serde(rename = "sourceToolAssistantUUID", default)]
    pub source_tool_assistant_uuid: Option<String>,
    #[serde(rename = "classifierMetaLines", default)]
    pub classifier_meta_lines: Option<Value>,

    #[serde(flatten, default)]
    pub extra: Map<String, Value>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct Message {
    #[serde(default)]
    pub id: Option<String>,
    #[serde(default)]
    pub model: Option<String>,
    #[serde(default)]
    pub role: Option<String>,
    #[serde(default)]
    pub content: Option<MessageContent>,
    #[serde(default)]
    pub stop_reason: Option<String>,
    #[serde(default)]
    pub stop_sequence: Option<Value>,
    #[serde(default)]
    pub stop_details: Option<Value>,
    #[serde(default)]
    pub usage: Option<Usage>,

    #[serde(flatten, default)]
    pub extra: Map<String, Value>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(untagged)]
pub enum MessageContent {
    Text(String),
    Blocks(Vec<ContentBlock>),
    Other(Value),
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct ContentBlock {
    #[serde(rename = "type", default)]
    pub block_type: Option<String>,
    #[serde(default)]
    pub text: Option<String>,
    #[serde(default)]
    pub thinking: Option<String>,
    #[serde(default)]
    pub id: Option<String>,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub input: Option<Value>,
    #[serde(rename = "tool_use_id", default)]
    pub tool_use_id: Option<String>,
    #[serde(default)]
    pub content: Option<Value>,
    #[serde(rename = "is_error", default)]
    pub is_error: Option<bool>,

    #[serde(flatten, default)]
    pub extra: Map<String, Value>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct Usage {
    #[serde(default, deserialize_with = "opt_u64")]
    pub input_tokens: Option<u64>,
    #[serde(default, deserialize_with = "opt_u64")]
    pub output_tokens: Option<u64>,
    #[serde(default, deserialize_with = "opt_u64")]
    pub cache_creation_input_tokens: Option<u64>,
    #[serde(default, deserialize_with = "opt_u64")]
    pub cache_read_input_tokens: Option<u64>,
    #[serde(default)]
    pub service_tier: Option<String>,
    #[serde(default)]
    pub speed: Option<Value>,

    #[serde(flatten, default)]
    pub extra: Map<String, Value>,
}

impl Record {
    pub fn type_bucket(&self) -> &'static str {
        match self.record_type.as_deref() {
            Some("assistant") => "assistant",
            Some("user") => "user",
            Some("attachment") => "attachment",
            Some("last-prompt") => "last-prompt",
            Some("queue-operation") => "queue-operation",
            Some("mode") => "mode",
            Some("system") => "system",
            Some("pr-link") => "pr-link",
            Some("custom-title") => "custom-title",
            Some("summary") => "summary",
            _ => "other",
        }
    }

    pub fn display_type(&self) -> &str {
        self.record_type.as_deref().unwrap_or("unknown")
    }

    pub fn is_sidechain(&self) -> bool {
        self.is_sidechain.unwrap_or(false)
    }

    pub fn is_api_error(&self) -> bool {
        self.is_api_error_message.unwrap_or(false)
            || self.api_error_status.is_some()
            || self.error.is_some()
    }

    pub fn tool_result_error_count(&self) -> usize {
        self.content_blocks()
            .map(|blocks| {
                blocks
                    .iter()
                    .filter(|block| {
                        block.block_type.as_deref() == Some("tool_result")
                            && block.is_error.unwrap_or(false)
                    })
                    .count()
            })
            .unwrap_or(0)
    }

    pub fn human_prompt(&self) -> Option<&str> {
        if self.record_type.as_deref() != Some("user") || self.is_meta.unwrap_or(false) {
            return None;
        }

        match self.message.as_ref()?.content.as_ref()? {
            MessageContent::Text(text) => Some(text.as_str()),
            _ => None,
        }
    }

    pub fn queue_prompt(&self) -> Option<String> {
        if self.record_type.as_deref() != Some("queue-operation")
            || self.operation.as_deref() != Some("enqueue")
        {
            return None;
        }

        self.content.as_ref().map(value_to_text)
    }

    pub fn tool_names(&self) -> Vec<&str> {
        self.content_blocks()
            .map(|blocks| {
                blocks
                    .iter()
                    .filter(|block| block.block_type.as_deref() == Some("tool_use"))
                    .filter_map(|block| block.name.as_deref())
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn content_blocks(&self) -> Option<&[ContentBlock]> {
        match self.message.as_ref()?.content.as_ref()? {
            MessageContent::Blocks(blocks) => Some(blocks.as_slice()),
            _ => None,
        }
    }
}

pub fn value_to_text(value: &Value) -> String {
    match value {
        Value::Null => String::new(),
        Value::Bool(value) => value.to_string(),
        Value::Number(value) => value.to_string(),
        Value::String(value) => value.clone(),
        Value::Array(values) => values
            .iter()
            .map(value_to_text)
            .collect::<Vec<_>>()
            .join(" "),
        Value::Object(_) => value.to_string(),
    }
}

fn opt_u64<'de, D>(deserializer: D) -> Result<Option<u64>, D::Error>
where
    D: Deserializer<'de>,
{
    let value = Option::<Value>::deserialize(deserializer)?;
    let Some(value) = value else {
        return Ok(None);
    };

    match value {
        Value::Null => Ok(None),
        Value::Number(number) => {
            if let Some(value) = number.as_u64() {
                Ok(Some(value))
            } else if let Some(value) = number.as_i64() {
                Ok(u64::try_from(value).ok())
            } else {
                Ok(number.as_f64().and_then(|value| {
                    if value.is_finite() && value >= 0.0 {
                        Some(value as u64)
                    } else {
                        None
                    }
                }))
            }
        }
        Value::String(value) => Ok(value.parse::<u64>().ok()),
        _ => Ok(None),
    }
}
