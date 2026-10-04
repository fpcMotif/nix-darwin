import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

type Handler = (event: unknown, ctx: unknown) => unknown;

const extensionPath = process.argv[2];
const repo = mkdtempSync(join(tmpdir(), "doc-lock-extension-"));
process.env.XDG_STATE_HOME = join(repo, ".state");
for (const key of ["DOC_LOCK_OFF", "DOC_LOCK_SESSION"]) delete process.env[key];

const git = (...args: string[]) =>
  execFileSync("git", args, {
    cwd: repo,
    env: { ...process.env, GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@t", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@t" },
  });
git("init", "-q");
writeFileSync(join(repo, ".gitignore"), ".state/\n");
writeFileSync(join(repo, "a.ts"), "const a = 1;\n");
writeFileSync(join(repo, "notes.md"), "# Notes\n");
git("add", "-A");
git("commit", "-qm", "init");

const handlers = new Map<string, Handler>();
const extension = await import(extensionPath);
extension.default({ on: (event: string, handler: Handler) => handlers.set(event, handler) });
const ctx = (session: string) => ({ cwd: repo, sessionManager: { getSessionId: () => session } });
const toolCall = (session: string, toolName: string, input: unknown) =>
  handlers.get("tool_call")!({ toolName, input }, ctx(session)) as { block?: boolean; reason?: string } | undefined;
const input = (session: string, text: string, source: string) => handlers.get("input")!({ text, source }, ctx(session));

const commentEdit = { path: "a.ts", edits: [{ oldText: "const a = 1;", newText: "// new\nconst a = 1;" }] };
input("s2", "please update the ADR", "interactive");
input("s3", "please update the ADR", "extension");

const checks: [string, boolean][] = [
  ["pi edit adding a comment blocks", toolCall("s1", "edit", commentEdit)?.block === true],
  ["the block reason names the comment", (toolCall("s1", "edit", commentEdit)?.reason ?? "").includes("// new")],
  ["code-only edit passes", toolCall("s1", "edit", { path: "a.ts", edits: [{ oldText: "const a = 1;", newText: "const a = 2;" }] }) === undefined],
  ["hashline comment blocks", toolCall("s1", "edit", { input: "[a.ts#1a2b]\nPUT <1:\n+// new", path: "a.ts", paths: ["a.ts"] })?.block === true],
  ["Markdown write blocks", toolCall("s1", "write", { path: "notes.md", content: "# x\n" })?.block === true],
  ["other tools pass", toolCall("s1", "bash", { command: "echo '// x' > a.ts" }) === undefined],
  ["typed docs request opens the lock", toolCall("s2", "write", { path: "notes.md", content: "# x\n" }) === undefined],
  ["machine input opens nothing", toolCall("s3", "write", { path: "notes.md", content: "# x\n" })?.block === true],
  ["checker startup failure blocks edits", (handlers.get("tool_call")!(
    { toolName: "write", input: { path: "notes.md", content: "# x\n" } },
    { ...ctx("missing-cwd"), cwd: join(repo, "missing") },
  ) as { block?: boolean } | undefined)?.block === true],
];

const failed = checks.filter(([, ok]) => !ok);
for (const [name] of failed) console.log(`FAIL ${name}`);
console.log(`doc-lock extension: ${checks.length - failed.length}/${checks.length} passed`);
process.exit(failed.length === 0 ? 0 : 1);
