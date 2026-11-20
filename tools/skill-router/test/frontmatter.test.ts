import { expect, test } from "bun:test";
import { parseFrontmatter } from "../src/frontmatter.ts";

const doc = (frontmatter: string): string => `---\n${frontmatter}\n---\n\n# Body\n`;

test("single-line values parse as before", () => {
  expect(parseFrontmatter(doc("name: clean\ndescription: Polish a diff."))).toEqual({
    name: "clean",
    description: "Polish a diff.",
  });
});

test("quotes around a single-line value are stripped", () => {
  expect(parseFrontmatter(doc('name: "jj"\ndescription: \'Use when: committing.\''))).toEqual({
    name: "jj",
    description: "Use when: committing.",
  });
});

test("a folded block joins its lines with spaces", () => {
  const parsed = parseFrontmatter(doc("name: simplify\ndescription: >-\n  Simplify a working diff,\n  then apply the fixes."));
  expect(parsed.description).toBe("Simplify a working diff, then apply the fixes.");
  expect(parsed.name).toBe("simplify");
});

test("a folded block keeps a blank line as a paragraph break", () => {
  const parsed = parseFrontmatter(doc("description: >\n  First paragraph\n  continues.\n\n  Second paragraph."));
  expect(parsed.description).toBe("First paragraph continues.\nSecond paragraph.");
});

test("a literal block keeps its line breaks", () => {
  const parsed = parseFrontmatter(doc("description: |\n  Line one.\n  Line two.\nname: chronicle"));
  expect(parsed.description).toBe("Line one.\nLine two.");
  expect(parsed.name).toBe("chronicle");
});

test("an indented continuation of a plain value is appended", () => {
  const parsed = parseFrontmatter(doc("description: Use when committing\n  or landing a change."));
  expect(parsed.description).toBe("Use when committing or landing a change.");
});

test("content without frontmatter yields an empty object", () => {
  expect(parseFrontmatter("# Just a heading\n")).toEqual({});
});
