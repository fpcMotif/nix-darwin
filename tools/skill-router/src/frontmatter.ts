export type Frontmatter = {
  name?: string;
  description?: string;
};

const BLOCK_SCALAR = /^[>|][+-]?$/;
const INDENTED = /^\s/;

function foldLines(lines: string[]): string {
  return lines
    .join("\n")
    .trim()
    .split(/\n{2,}/)
    .map((paragraph) => paragraph.replace(/\n/g, " "))
    .join("\n");
}

export function parseFrontmatter(content: string): Frontmatter {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};

  const lines = match[1].split(/\r?\n/);
  const result: Frontmatter = {};
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (INDENTED.test(line)) continue;
    const idx = line.indexOf(":");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const head = line.slice(idx + 1).trim();

    const continuation: string[] = [];
    while (i + 1 < lines.length && (INDENTED.test(lines[i + 1]) || lines[i + 1].trim() === "")) {
      i += 1;
      continuation.push(lines[i].trim());
    }

    let value: string;
    if (BLOCK_SCALAR.test(head)) {
      value = head.startsWith("|") ? continuation.join("\n").trim() : foldLines(continuation);
    } else {
      value = [head.replace(/^['"]|['"]$/g, ""), ...continuation.filter((part) => part !== "")].join(" ").trim();
    }

    if (key === "name") result.name = value;
    if (key === "description") result.description = value;
  }
  return result;
}
