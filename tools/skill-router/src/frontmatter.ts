export type Frontmatter = {
  name?: string;
  description?: string;
};

export function parseFrontmatter(content: string): Frontmatter {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};

  const block = match[1];
  const result: Frontmatter = {};
  for (const line of block.split("\n")) {
    const idx = line.indexOf(":");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim().replace(/^['"]|['"]$/g, "");
    if (key === "name") result.name = value;
    if (key === "description") result.description = value;
  }
  return result;
}
