export async function findGitRoot(start: string): Promise<string | null> {
  const proc = Bun.spawn(["git", "-C", start, "rev-parse", "--show-toplevel"], {
    stdout: "pipe",
    stderr: "ignore",
  });
  const code = await proc.exited;
  if (code !== 0) return null;
  return (await new Response(proc.stdout).text()).trim() || null;
}
