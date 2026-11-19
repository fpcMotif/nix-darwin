{ lib
, buildGoModule
}:

buildGoModule {
  pname = "agent-trace";
  version = "0.1.0";

  src = ../tools/agent-trace/go;

  vendorHash = null;

  meta = {
    description = "Streams Claude Code JSONL transcripts into stats, first prompts, and a flow tree";
    license = lib.licenses.mit;
    mainProgram = "agent-trace";
    platforms = lib.platforms.unix;
  };
}
