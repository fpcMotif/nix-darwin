#!/usr/bin/env bun
/**
 * drafts-ledger — read, search, export, enrich, chunk and write the Drafts.app store.
 *
 * Zero dependencies (bun:sqlite + fetch). Every network or write step honours --dry-run.
 * Reads a *copy* of the store (DB + WAL + SHM) so the app is never locked and reads are never stale.
 */
import { Database } from "bun:sqlite";
import { parseArgs } from "node:util";
import { mkdtempSync, mkdirSync, existsSync, readFileSync, writeFileSync, appendFileSync, copyFileSync, rmSync } from "node:fs";
import { tmpdir, homedir } from "node:os";
import { join, basename } from "node:path";

// ---------- constants ----------
const HOME = homedir();
const DEFAULT_STORE = join(HOME, "Library/Group Containers/GTFQ98J4YG.com.agiletortoise.Drafts/DraftStore.sqlite");
const CACHE_DIR = process.env.DRAFTS_LEDGER_CACHE ?? join(HOME, ".cache/drafts-ledger");
const CORE_DATA_EPOCH = 978307200; // 2001-01-01 in unix seconds
const FOLDERS: Record<string, number> = { inbox: 0, archive: 1, trash: 10000 };
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36";

type Bucket = "github" | "x" | "arxiv" | "youtube" | "cn-social" | "hn" | "reddit" | "substack" | "appstore" | "web" | "text-only";
const CN = new Set(["xiaohongshu.com", "xhslink.com", "weibo.com", "weibo.cn", "okjike.com", "jike.city", "t.me", "bilibili.com", "b23.tv", "zhihu.com", "xiaoyuzhoufm.com", "mp.weixin.qq.com", "douban.com", "juejin.cn", "v2ex.com", "sspai.com"]);
const WEB_SKIP = new Set(["instagram.com", "threads.com", "drive.google.com", "docs.google.com", "claude.ai", "chatgpt.com", "amazon.co.jp", "amazon.com", "open.spotify.com", "music.apple.com", "apps.apple.com", "facebook.com", "linkedin.com", "t.me", "xiaohongshu.com", "weibo.com"]);

interface Item {
  uuid: string; date: string; modified: string; folder: number; flagged: number; tags: string[];
  url: string | null; domain: string; bucket: Bucket; extra: string; n_urls: number;
  repo?: string; repo_path?: string; x_user?: string; x_id?: string; dup_count?: number; meta?: string;
}

// ---------- helpers ----------
const out = (s: string) => process.stdout.write(s + "\n");
const err = (s: string) => process.stderr.write(s + "\n");
const die = (s: string, code = 1): never => { err(`error: ${s}`); process.exit(code); };
const URL_RE = /https?:\/\/[^\s<>()\[\]"']+/g;

function normDomain(u: string): string {
  let d = "";
  try { d = new URL(u).hostname.toLowerCase(); } catch { return ""; }
  for (const p of ["www.", "mobile.", "m."]) if (d.startsWith(p)) d = d.slice(p.length);
  if (["twitter.com", "fxtwitter.com", "vxtwitter.com"].includes(d)) d = "x.com";
  return d;
}
function bucketOf(d: string, rules?: Record<string, string[]>): Bucket {
  if (!d) return "text-only";
  if (rules) for (const [b, doms] of Object.entries(rules)) if (doms.some(x => d === x || d.endsWith("." + x))) return b as Bucket;
  if (d === "github.com" || d === "gist.github.com" || d.endsWith(".github.io")) return "github";
  if (d === "x.com") return "x";
  if (d === "arxiv.org" || d.endsWith(".arxiv.org")) return "arxiv";
  if (d === "youtube.com" || d === "youtu.be") return "youtube";
  if (CN.has(d) || d.endsWith(".zhihu.com")) return "cn-social";
  if (d === "news.ycombinator.com") return "hn";
  if (d === "reddit.com") return "reddit";
  if (d === "substack.com" || d.endsWith(".substack.com")) return "substack";
  if (d === "apps.apple.com" || d === "testflight.apple.com") return "appstore";
  return "web";
}
const TRACKING = new Set(["si", "s", "ref", "ref_src", "feature", "fbclid", "gclid", "igshid", "mc_cid", "mc_eid", "spm", "from", "share_token", "xhsshare"]);
/** Same page ⇒ same key: drop hash and tracking params, keep the params that identify content (youtube v=, list=). */
function canonical(u: string): string {
  try {
    const x = new URL(u);
    if (!/^#(\/|!|narrow)/.test(x.hash)) x.hash = ""; // keep SPA-style route fragments (Zulip #narrow, #/path, #!)
    for (const k of [...x.searchParams.keys()]) if (TRACKING.has(k) || k.startsWith("utm_")) x.searchParams.delete(k);
    x.hostname = normDomain(u) || x.hostname;
    return x.toString().replace(/\/$/, "");
  } catch { return u; }
}
function parseSince(s: string | undefined, fallback: string): string {
  if (!s) return fallback;
  const m = /^(\d+)([dwmy])$/.exec(s);
  if (m) {
    const n = +m[1], d = new Date();
    if (m[2] === "d") d.setDate(d.getDate() - n);
    if (m[2] === "w") d.setDate(d.getDate() - 7 * n);
    if (m[2] === "m") d.setMonth(d.getMonth() - n);
    if (m[2] === "y") d.setFullYear(d.getFullYear() - n);
    return d.toISOString().slice(0, 10);
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  return die(`bad date '${s}': use YYYY-MM-DD or 2m / 6w / 30d / 1y`);
}
const toCoreData = (iso: string) => Math.floor(Date.parse(iso + "T00:00:00Z") / 1000) - CORE_DATA_EPOCH;
const fromCoreData = (t: number) => new Date((t + CORE_DATA_EPOCH) * 1000).toISOString().slice(0, 16).replace("T", " ");
const parseTags = (cached: string | null) => (cached ?? "").split(/ZZZ/).map(s => s.trim()).filter(Boolean);
function splitList(v: string | undefined): string[] { return (v ?? "").split(",").map(s => s.trim()).filter(Boolean); }

async function pool<T, R>(items: T[], n: number, fn: (t: T, i: number) => Promise<R>): Promise<R[]> {
  const res: R[] = new Array(items.length); let next = 0;
  await Promise.all(Array.from({ length: Math.min(n, items.length) }, async () => {
    while (next < items.length) { const i = next++; res[i] = await fn(items[i], i); }
  }));
  return res;
}
async function getText(url: string, ms = 12000, maxBytes = 250_000): Promise<string> {
  const r = await fetch(url, { headers: { "User-Agent": UA, "Accept": "text/html,application/json;q=0.9,*/*;q=0.8", "Accept-Language": "en,zh;q=0.8,ja;q=0.7" }, signal: AbortSignal.timeout(ms), redirect: "follow" });
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  const buf = new Uint8Array(await r.arrayBuffer());
  return new TextDecoder("utf-8", { fatal: false }).decode(buf.subarray(0, maxBytes));
}
function decodeEntities(s: string): string {
  return s.replace(/&(amp|lt|gt|quot|#39|#x27|nbsp);/g, m => ({ "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&#39;": "'", "&#x27;": "'", "&nbsp;": " " }[m] ?? m))
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n));
}

// ---------- store ----------
function openStore(storePath: string, inPlace: boolean): { db: Database; cleanup: () => void; copied: boolean } {
  if (!existsSync(storePath)) die(`store not found: ${storePath}`);
  if (inPlace) return { db: new Database(storePath, { readonly: true }), cleanup: () => {}, copied: false };
  const dir = mkdtempSync(join(tmpdir(), "drafts-ledger-"));
  const dst = join(dir, "DraftStore.sqlite");
  copyFileSync(storePath, dst);
  for (const sfx of ["-wal", "-shm"]) if (existsSync(storePath + sfx)) copyFileSync(storePath + sfx, dst + sfx);
  const db = new Database(dst); // default read/write flags so the copied WAL replays
  return { db, cleanup: () => { try { db.close(); rmSync(dir, { recursive: true, force: true }); } catch {} }, copied: true };
}

interface Filters { since: string; until?: string; folder: string; tag?: string; match?: string; minLinks?: number; maxLinks?: number; dateField: "created" | "modified" | "either"; dedupe?: boolean; }
function loadItems(db: Database, f: Filters, rules?: Record<string, string[]>): { items: Item[]; raw: number; dups: number; excluded: number } {
  const where: string[] = []; const params: any[] = [];
  const since = toCoreData(f.since); const until = f.until ? toCoreData(f.until) + 86400 : null;
  const dateCond = (col: string) => until ? `(${col} >= ? AND ${col} < ?)` : `${col} >= ?`;
  const push = (col: string) => { params.push(since); if (until) params.push(until); return dateCond(col); };
  if (f.dateField === "either") where.push(`(${push("ZCREATED_AT")} OR ${push("ZMODIFIED_AT")})`);
  else where.push(push(f.dateField === "created" ? "ZCREATED_AT" : "ZMODIFIED_AT"));
  if (f.folder !== "all") { const fo = FOLDERS[f.folder]; if (fo === undefined) die(`bad folder '${f.folder}': inbox | archive | trash | all`); where.push("ZFOLDER = ?"); params.push(fo); }
  else where.push("ZFOLDER != 10000");
  if (f.tag) { where.push("ZCACHED_TAGS LIKE ?"); params.push(`%ZZZ${f.tag}ZZZ%`); }
  if (f.match) { where.push("ZCONTENT LIKE ?"); params.push(`%${f.match}%`); }
  const rows = db.query(`SELECT ZUUID uuid, ZCREATED_AT c, ZMODIFIED_AT m, ZFOLDER folder, ZFLAGGED flagged, ZCACHED_TAGS tags, ZCONTENT content FROM ZMANAGEDDRAFT WHERE ${where.join(" AND ")} ORDER BY ZCREATED_AT DESC`).all(...params) as any[];
  const seen = new Map<string, Item>(); const items: Item[] = []; let dups = 0, excluded = 0;
  for (const r of rows) {
    const content: string = r.content ?? "";
    const urls = content.match(URL_RE) ?? [];
    const n = urls.length;
    if ((f.minLinks !== undefined && n < f.minLinks) || (f.maxLinks !== undefined && n > f.maxLinks)) { excluded++; continue; }
    const url = urls[0]?.replace(/[.,;:]+$/, "") ?? null;
    const extra = content.replace(URL_RE, "").replace(/^> ?/gm, "").replace(/\n{2,}/g, "\n").trim().slice(0, 700);
    const d = url ? normDomain(url) : "";
    const it: Item = { uuid: r.uuid, date: fromCoreData(r.c).slice(0, 10), modified: fromCoreData(r.m).slice(0, 10), folder: r.folder, flagged: r.flagged, tags: parseTags(r.tags), url, domain: d, bucket: bucketOf(d, rules), extra, n_urls: n };
    if (it.bucket === "github" && url && d === "github.com") {
      const parts = new URL(url).pathname.split("/").filter(Boolean);
      if (parts.length >= 2 && !["orgs", "topics", "features", "settings", "search", "marketplace", "sponsors", "apps", "trending", "explore", "collections", "login", "events", "notifications"].includes(parts[0])) { it.repo = `${parts[0]}/${parts[1]}`; it.repo_path = parts.slice(2).join("/").slice(0, 80); }
    }
    if (it.bucket === "x" && url) {
      const m = /x\.com\/([^/]+)\/status\/(\d+)/.exec(url.replace("twitter.com", "x.com"));
      if (m) { it.x_user = m[1]; it.x_id = m[2]; } else { const m2 = /x\.com\/([^/?#]+)/.exec(url.replace("twitter.com", "x.com")); if (m2) it.x_user = m2[1]; }
    }
    const key = url ? canonical(url) : content.slice(0, 200);
    const prev = f.dedupe === false ? undefined : seen.get(key);
    if (prev) { dups++; prev.dup_count = (prev.dup_count ?? 1) + 1; continue; }
    seen.set(key, it); items.push(it);
  }
  return { items, raw: rows.length, dups, excluded };
}

// ---------- enrichment ----------
type Kind = "repos" | "tweets" | "youtube" | "arxiv" | "web";
const ALL_KINDS: Kind[] = ["repos", "tweets", "youtube", "arxiv", "web"];
function cacheLoad(kind: Kind): Map<string, any> {
  const p = join(CACHE_DIR, `${kind}.jsonl`); const m = new Map();
  if (existsSync(p)) for (const l of readFileSync(p, "utf8").split("\n")) { if (!l) continue; try { const o = JSON.parse(l); if (o.key) m.set(o.key, o); } catch {} }
  return m;
}
function cacheAppend(kind: Kind, o: any) { mkdirSync(CACHE_DIR, { recursive: true }); appendFileSync(join(CACHE_DIR, `${kind}.jsonl`), JSON.stringify(o) + "\n"); }
function keyFor(kind: Kind, it: Item): string | null {
  if (kind === "repos") return it.repo ?? null;
  if (kind === "tweets") return it.x_id ? `${it.x_user}/status/${it.x_id}` : null;
  if (kind === "youtube") return it.bucket === "youtube" && it.url ? it.url : null;
  if (kind === "arxiv") { const m = it.bucket === "arxiv" ? /(\d{4}\.\d{4,5})/.exec(it.url ?? "") : null; return m ? m[1] : null; }
  if (kind === "web") return ["web", "substack", "hn", "reddit", "cn-social"].includes(it.bucket) && it.url && !WEB_SKIP.has(it.domain) ? it.url : null;
  return null;
}
async function fetchKind(kind: Kind, keys: string[], concurrency: number, onDone: (k: string, o: any) => void) {
  if (kind === "repos") {
    for (let b = 0; b < keys.length; b += 100) {
      const batch = keys.slice(b, b + 100);
      const q = "query { " + batch.map((r, n) => { const [o, name] = r.split("/", 2); return `r${n}: repository(owner:${JSON.stringify(o)}, name:${JSON.stringify(name)}) { nameWithOwner description stargazerCount forkCount primaryLanguage { name } pushedAt isArchived repositoryTopics(first: 6) { nodes { topic { name } } } }`; }).join(" ") + " }";
      const p = Bun.spawnSync(["gh", "api", "graphql", "-f", `query=${q}`]);
      let data: any = {};
      try { data = JSON.parse(p.stdout.toString() || "{}").data ?? {}; } catch { batch.forEach(k => onDone(k, { key: k, error: (p.stderr.toString() || "gh failed").slice(0, 200) })); continue; }
      batch.forEach((k, n) => { const v = data[`r${n}`]; onDone(k, v ? { key: k, desc: (v.description ?? "").slice(0, 300), stars: v.stargazerCount, forks: v.forkCount, lang: v.primaryLanguage?.name ?? null, pushed: (v.pushedAt ?? "").slice(0, 10), archived: v.isArchived, topics: (v.repositoryTopics?.nodes ?? []).map((t: any) => t.topic.name) } : { key: k, error: "not found" }); });
      await Bun.sleep(1000);
    }
  } else if (kind === "arxiv") {
    for (let b = 0; b < keys.length; b += 50) {
      const batch = keys.slice(b, b + 50);
      try {
        const x = await getText(`http://export.arxiv.org/api/query?id_list=${batch.join(",")}&max_results=50`, 40000, 5_000_000);
        for (const e of x.split("<entry>").slice(1)) {
          const g = (tag: string) => { const m = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`).exec(e); return m ? decodeEntities(m[1]).replace(/\s+/g, " ").trim() : ""; };
          const id = g("id").split("/abs/").pop()!.replace(/v\d+$/, "");
          const cat = /<arxiv:primary_category[^>]*term="([^"]+)"/.exec(e)?.[1] ?? "";
          const authors = [...e.matchAll(/<author>\s*<name>([^<]+)<\/name>/g)].map(m => m[1]).slice(0, 4);
          if (batch.includes(id)) onDone(id, { key: id, title: g("title"), summary: g("summary").slice(0, 400), cat, published: g("published").slice(0, 10), authors });
        }
        batch.forEach(k => onDone(k, undefined)); // mark missing ones as failed if not delivered
      } catch (ex: any) { batch.forEach(k => onDone(k, { key: k, error: String(ex).slice(0, 120) })); }
      await Bun.sleep(3000);
    }
  } else {
    await pool(keys, concurrency, async k => {
      try {
        if (kind === "tweets") {
          const d = await (await fetch(`https://api.fxtwitter.com/${k}`, { signal: AbortSignal.timeout(20000) })).json() as any;
          const t = d.tweet ?? {}, a = t.author ?? {}, q = t.quote ?? {};
          onDone(k, { key: k, user: a.screen_name, name: a.name, bio: (a.description ?? "").slice(0, 160), followers: a.followers, text: t.text, likes: t.likes, views: t.views, created: t.created_at, quote_user: q.author?.screen_name, quote_text: (q.text ?? "").slice(0, 500), code: d.code });
          await Bun.sleep(250);
        } else if (kind === "youtube") {
          const d = await (await fetch(`https://www.youtube.com/oembed?url=${encodeURIComponent(k)}&format=json`, { signal: AbortSignal.timeout(15000) })).json() as any;
          onDone(k, { key: k, title: d.title, author: d.author_name });
        } else {
          const h = await getText(k, 10000);
          const og = /<meta[^>]+property=["']og:title["'][^>]*content=["']([^"']{3,200})/i.exec(h)?.[1];
          const t = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(h)?.[1] ?? "";
          const m = /<meta[^>]+(?:property|name)=["'](?:og:description|description|twitter:description)["'][^>]*content=["']([^"']{10,400})/i.exec(h) ?? /<meta[^>]+content=["']([^"']{10,400})["'][^>]+(?:property|name)=["'](?:og:description|description)["']/i.exec(h);
          onDone(k, { key: k, title: decodeEntities(og ?? t).replace(/\s+/g, " ").trim().slice(0, 160), desc: m ? decodeEntities(m[1]).replace(/\s+/g, " ").trim().slice(0, 320) : "" });
        }
      } catch (ex: any) { onDone(k, { key: k, error: String(ex?.message ?? ex).slice(0, 120) }); }
    });
  }
}
function metaLine(it: Item, caches: Record<Kind, Map<string, any>>): string {
  const k = (kind: Kind) => { const key = keyFor(kind, it); return key ? caches[kind].get(key) : undefined; };
  let meta = "";
  const r = k("repos"), a = k("arxiv"), t = k("tweets"), y = k("youtube"), w = k("web");
  if (r && !r.error) { meta = `[${r.stars}★ ${r.lang ?? "-"}] ${r.desc}` + (r.topics?.length ? ` topics=${r.topics.join(",")}` : "") + (r.archived ? " ARCHIVED" : "") + (it.repo_path ? ` path=${it.repo_path}` : ""); }
  else if (a && !a.error) meta = `[${a.cat} ${a.published}] ${a.title} — ${(a.summary ?? "").slice(0, 220)}`;
  else if (t && !t.error) { meta = `@${t.user} (${t.name}; ${(t.bio ?? "").slice(0, 80)}) [${t.likes}♥]: ${(t.text ?? "").slice(0, 600)}` + (t.quote_text ? ` || QT @${t.quote_user}: ${t.quote_text.slice(0, 250)}` : ""); }
  else if (y && !y.error) meta = `${y.author} — ${y.title}`;
  else if (w && !w.error) meta = `${w.title}` + (w.desc ? ` — ${w.desc}` : "");
  return meta.replace(/\s+/g, " ").trim();
}
function chunkLine(it: Item): string {
  const ex = it.extra.replace(/\n/g, " / ").slice(0, 400);
  return `${it.date} | ${it.url ?? "(no url)"}` + (it.meta ? ` | ${it.meta}` : "") + (ex ? ` | NOTE: ${ex}` : "") + (it.dup_count ? ` | dup×${it.dup_count}` : "") + (it.tags.length ? ` | tags=${it.tags.join(",")}` : "");
}

// ---------- drafts:// write-back ----------
function draftsUrl(action: string, params: Record<string, string | string[] | undefined>): string {
  const qs = Object.entries(params).flatMap(([k, v]) => v === undefined ? [] : (Array.isArray(v) ? v : [v]).map(x => `${k}=${encodeURIComponent(x)}`)).join("&");
  return `drafts://x-callback-url/${action}?${qs}`;
}
function openUrl(url: string, dryRun: boolean, preview: string) {
  if (dryRun) { out(`[dry-run] would open drafts:// URL (${url.length} chars)\n  action: ${url.slice(0, url.indexOf("?"))}\n  preview: ${preview.slice(0, 200).replace(/\n/g, "⏎")}${preview.length > 200 ? "…" : ""}`); return; }
  const p = Bun.spawnSync(["open", url]);
  if (p.exitCode !== 0) die(`open failed: ${p.stderr.toString()}`);
  out(`opened ${url.slice(0, url.indexOf("?"))} (${url.length} chars)`);
}

// ---------- markdown → html (minimal) ----------
function esc(s: string) { return s.replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!)); }
function md(s: string): string {
  const inline = (t: string) => esc(t).replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g, '<a href="$2">$1</a>').replace(/(?<![\w/])(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>').replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/(?<!\*)\*(?!\*)([^*\n]+)\*/g, "<em>$1</em>").replace(/`([^`]+)`/g, "<code>$1</code>");
  const o: string[] = []; let para: string[] = []; let lst: string | null = null;
  const flush = () => { if (para.length) { o.push(`<p>${inline(para.join(" "))}</p>`); para = []; } };
  const closeList = () => { if (lst) { o.push(`</${lst}>`); lst = null; } };
  for (const raw of s.split("\n")) {
    const l = raw.trimEnd();
    if (!l.trim()) { flush(); closeList(); continue; }
    let m = /^(#{1,6})\s+(.*)/.exec(l);
    if (m) { flush(); closeList(); const lvl = Math.min(m[1].length + 2, 5); o.push(`<h${lvl}>${inline(m[2].replace(/#+$/, "").trim())}</h${lvl}>`); continue; }
    m = /^\s*(?:[-*•]|\d+[.)])\s+(.*)/.exec(l);
    if (m) { flush(); const tag = /^\s*\d/.test(l) ? "ol" : "ul"; if (lst !== tag) { closeList(); o.push(`<${tag}>`); lst = tag; } o.push(`<li>${inline(m[1])}</li>`); continue; }
    closeList(); para.push(l.trim());
  }
  flush(); closeList(); return o.join("\n");
}

// ---------- render (digest.json → html + md) ----------
function render(D: any, opts: { title: string; sub: string }): { html: string; md: string } {
  const ORDER = ["github", "x", "web", "arxiv", "youtube", "notes"];
  const LABEL: Record<string, string> = { github: "GitHub", x: "x.com", web: "Web & blogs", arxiv: "arXiv", youtube: "YouTube", notes: "Own notes" };
  const B = D.buckets ?? {}; const bw = D.best_writing ?? { groups: [], sources_to_follow: [], method_note: "" }; const sg = D.skill_gaps ?? { install_or_adopt: [], skills_to_write: [], knowledge_gaps: [], workflow_gaps: [], already_covered: [] };
  const dropped = D.dropped_by_verification ?? {}; const restored = D.restored ?? [];
  const keys = ORDER.filter(k => B[k]).concat(Object.keys(B).filter(k => !ORDER.includes(k)));
  const total = keys.reduce((s, k) => s + (B[k].items ?? 0), 0);
  const dom = (u: string) => normDomain(u ?? "");
  const link = (t: string, u?: string) => u && u.startsWith("http") ? `<a href="${esc(u)}">${esc(t)}</a>` : esc(t);
  const pill = (p: string) => { const q = (p ?? "").toLowerCase(); const c = q.startsWith("h") ? "hi" : q.startsWith("m") ? "md" : "lo"; return `<span class="pill ${c}">${esc(p || "—")}</span>`; };
  const nDropped = Object.values(dropped).reduce((s: number, v: any) => s + v.length, 0);
  const nPieces = bw.groups.reduce((s: number, g: any) => s + g.pieces.length, 0);
  const nMust = bw.groups.reduce((s: number, g: any) => s + g.pieces.filter((p: any) => p.must_read).length, 0);
  const nKept = keys.reduce((s, k) => s + (B[k].top_highlights ?? []).length, 0) + nPieces + sg.install_or_adopt.length;
  const bar = keys.map(k => `<span class="seg seg-${k}" style="flex:${B[k].items}" title="${LABEL[k] ?? k}: ${B[k].items}"></span>`).join("");
  const legend = keys.map(k => `<span class="lg"><i class="sw seg-${k}"></i>${LABEL[k] ?? k} <b>${(B[k].items ?? 0).toLocaleString()}</b></span>`).join("");
  const bucketSection = (k: string) => {
    const b = B[k]; const maxc = Math.max(1, ...(b.top_themes ?? []).map((t: any) => t.approx_count));
    const themes = (b.top_themes ?? []).map((t: any) => `<li><span class="tn">${esc(t.name)}</span><span class="tc">${t.approx_count}</span><span class="tb"><i style="width:${(100 * t.approx_count / maxc).toFixed(1)}%"></i></span><span class="td">${esc(t.description)} <em class="trend">${esc(t.trend ?? "")}</em></span></li>`).join("");
    const hl = (b.top_highlights ?? []).map((h: any) => `<li><span class="kind">${esc(h.kind ?? "")}</span><span class="ht">${link(h.title, h.url)} <span class="dom">${esc(dom(h.url))}</span></span><span class="hw">${esc(h.why)}</span></li>`).join("");
    const people = (b.key_people ?? []).map((p: any) => `<li><b>${esc(p.handle)}</b> <span>${esc(p.why)}</span></li>`).join("");
    const skills = (b.skills_implied ?? []).map((s: string) => `<li>${esc(s)}</li>`).join("");
    return `<section id="b-${k}" class="bucket"><header class="sh"><span class="eyebrow">${esc(k)} · ${(b.items ?? 0).toLocaleString()} captures · ${b.chunks_read ?? "?"} chunks read</span><h2>${esc(LABEL[k] ?? k)}</h2></header><div class="prose">${md(b.overview ?? "")}</div><h3>Themes, ranked by captures</h3><ol class="themes">${themes}</ol><h3>Highlights <span class="note">verified against the capture log</span></h3><ol class="hl">${hl}</ol><div class="two"><div><h3>Recurring people and sources</h3><ul class="people">${people}</ul></div><div><h3>Skills this bucket implies</h3><ul class="skills">${skills}</ul><h3>July vs August</h3><div class="prose small">${md(b.july_vs_august ?? "")}</div></div></div></section>`;
  };
  const groups = bw.groups.map((g: any) => `<h3>${esc(g.topic)}</h3><ol class="hl best">${g.pieces.map((p: any) => `<li class="${p.must_read ? "must" : ""}"><span class="mark" title="must read">${p.must_read ? "●" : "○"}</span><span class="ht">${link(p.title, p.url)} <span class="dom">${esc(p.source || dom(p.url))}</span></span><span class="hw">${esc(p.why)}</span></li>`).join("")}</ol>`).join("");
  const sources = bw.sources_to_follow.map((s: any) => `<li><b>${link(s.name, s.url)}</b> <span>${esc(s.why)}</span></li>`).join("");
  const gapList = (items: any[], body: (i: any) => string, withPill = true) => items.map(i => `<li>${withPill ? pill(i.priority) : ""}<div>${body(i)}</div></li>`).join("");
  const inst = gapList(sg.install_or_adopt, i => `<b>${link(i.name, i.url)}</b> <span class="dom">${esc(dom(i.url))}</span><p>${esc(i.what)}</p><p class="why"><b>Why for you:</b> ${esc(i.why_for_f)}</p><p class="ev">Evidence: ${esc(i.evidence)}</p>`);
  const write = gapList(sg.skills_to_write, i => `<b>${esc(i.name)}</b><p>${esc(i.what)}</p><p class="why"><b>Why for you:</b> ${esc(i.why_for_f)}</p><p class="ev">Seed links: ${(i.seed_urls ?? []).map((u: string) => `<a href="${esc(u)}">${esc(dom(u))}${esc(u.replace(/^https?:\/\/[^/]+/, "").slice(0, 40))}</a>`).join(" · ")}</p>`);
  const know = gapList(sg.knowledge_gaps, i => `<b>${esc(i.topic)}</b><p class="ev">Evidence: ${esc(i.evidence)}</p><p>${esc(i.why_gap)}</p><p class="why"><b>First step:</b> ${esc(i.first_step)}</p>`);
  const wf = gapList(sg.workflow_gaps, i => `<p><b>${esc(i.observation)}</b></p><p class="why">${esc(i.fix)}</p>`, false);
  const covered = sg.already_covered.map((s: string) => `<li>${esc(s)}</li>`).join("");
  const critic = D.critic ?? { missing: [], overall: "" };
  const crit = critic.missing.map((m: any) => `<li>${pill(m.severity)}<div><b>${esc(m.issue)}</b></div></li>`).join("");
  const addenda = (D.addenda ?? []).map((a: any) => `<details open><summary>${pill(a.severity)} ${esc(a.issue)}</summary><div class="prose small">${md(a.addendum)}</div></details>`).join("");
  const dropList = (name: string) => (dropped[name] ?? []).map((d: any) => `<li><span class="ht">${link(d.title || "(untitled)", d.url)}</span><span class="hw">${esc(d.reason ?? "")}</span></li>`).join("");
  const droppedHtml = [["best", "Curated writing"], ["highlights", "Bucket highlights"], ["install", "Install recommendations"]].filter(([k]) => dropped[k]?.length).map(([k, n]) => `<h4>${n} (${dropped[k].length})</h4><ol class="hl small">${dropList(k)}</ol>`).join("");
  const restoredHtml = restored.length ? `<h4>Restored after the critic's review (${restored.length})</h4><p class="prose small">The refuter rejected these for an embellished description, not a wrong URL; the critic re-checked the captured metadata and they are back with the description rewritten from it.</p><ol class="hl small">${restored.map((d: any) => `<li><span class="ht">${link(d.title || "(untitled)", d.url)}</span><span class="hw">Refuter said: ${esc(d.reason ?? "")}</span></li>`).join("")}</ol>` : "";
  const toc = keys.map(k => `<a href="#b-${k}">${esc(LABEL[k] ?? k)}<span>${(B[k].items ?? 0).toLocaleString()}</span></a>`).join("");
  const nGaps = sg.install_or_adopt.length + sg.skills_to_write.length + sg.knowledge_gaps.length;
  const css = `:root{--paper:#F2F4F7;--surface:#FFFFFF;--ink:#141A22;--ink-2:#4A5563;--ink-3:#7B8794;--rule:#D7DCE3;--accent:#C9841A;--accent-ink:#8A5710;--link:#3B5B8C;--ok:#2E7D5B;--bad:#B23A3A;--warn:#B7791F;--c-github:#3B5B8C;--c-x:#141A22;--c-web:#C9841A;--c-arxiv:#2E7D5B;--c-youtube:#B23A3A;--c-notes:#7B8794;--display:"Fraunces",Georgia,"Times New Roman",serif;--body:"Atkinson Hyperlegible","Helvetica Neue",Arial,sans-serif;--mono:"JetBrains Mono","SF Mono",Menlo,monospace}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--paper:#12161C;--surface:#1A2028;--ink:#E6E9EE;--ink-2:#B4BCC8;--ink-3:#7F8A98;--rule:#2B333E;--accent:#E5A33A;--accent-ink:#F0BE6A;--link:#8FB0E0;--ok:#5FBF92;--bad:#E07A7A;--warn:#E0B060;--c-github:#8FB0E0;--c-x:#E6E9EE;--c-web:#E5A33A;--c-arxiv:#5FBF92;--c-youtube:#E07A7A;--c-notes:#7F8A98}}
:root[data-theme="dark"]{--paper:#12161C;--surface:#1A2028;--ink:#E6E9EE;--ink-2:#B4BCC8;--ink-3:#7F8A98;--rule:#2B333E;--accent:#E5A33A;--accent-ink:#F0BE6A;--link:#8FB0E0;--ok:#5FBF92;--bad:#E07A7A;--warn:#E0B060;--c-github:#8FB0E0;--c-x:#E6E9EE;--c-web:#E5A33A;--c-arxiv:#5FBF92;--c-youtube:#E07A7A;--c-notes:#7F8A98}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:var(--body);font-size:16px;line-height:1.55;-webkit-font-smoothing:antialiased}a{color:var(--link);text-decoration-color:color-mix(in oklab,var(--link) 40%,transparent);text-underline-offset:2px}a:hover{text-decoration-color:var(--link)}:focus-visible{outline:2px solid var(--accent);outline-offset:2px}code{font-family:var(--mono);font-size:.88em;background:color-mix(in oklab,var(--ink) 7%,transparent);padding:0 .3em;border-radius:3px}
.wrap{display:grid;grid-template-columns:200px minmax(0,76ch);gap:48px;max-width:1160px;margin:0 auto;padding:40px 24px 96px}@media (max-width:900px){.wrap{grid-template-columns:minmax(0,1fr);gap:24px}nav.rail{position:static;border:0;padding:0}}
nav.rail{position:sticky;top:24px;align-self:start;font-size:13px;border-right:1px solid var(--rule);padding-right:16px}nav.rail a{display:flex;justify-content:space-between;gap:8px;color:var(--ink-2);text-decoration:none;padding:5px 0}nav.rail a span{font-family:var(--mono);color:var(--ink-3);font-size:12px}nav.rail a:hover{color:var(--ink)}nav.rail .grp{margin-top:14px;font-family:var(--mono);font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-3)}
main{min-width:0}h1{font-family:var(--display);font-variation-settings:"opsz" 144,"SOFT" 40;font-weight:400;font-size:clamp(34px,5vw,52px);line-height:1.05;margin:0 0 10px;letter-spacing:-.01em;text-wrap:balance}h2{font-family:var(--display);font-variation-settings:"opsz" 72;font-weight:500;font-size:30px;line-height:1.15;margin:0;text-wrap:balance}h3{font-family:var(--body);font-weight:700;font-size:15px;letter-spacing:.02em;margin:34px 0 10px}h3 .note{font-weight:400;color:var(--ink-3);font-size:13px;margin-left:8px}h4{font-size:14px;margin:22px 0 6px;color:var(--ink-2)}
.prose h4,.prose h5{font-family:var(--display);font-weight:600;font-size:19px;margin:26px 0 6px;color:var(--ink)}.prose p{margin:0 0 14px;max-width:72ch}.prose ul,.prose ol{padding-left:22px;margin:0 0 14px}.prose li{margin:4px 0}.prose.small{font-size:14.5px;color:var(--ink-2)}
.eyebrow{font-family:var(--mono);font-size:11.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--accent-ink)}.lede{color:var(--ink-2);font-size:17px;max-width:66ch;margin:0 0 22px}.ledger{border-top:1px solid var(--rule);border-bottom:1px solid var(--rule);padding:16px 0;margin:0 0 36px}.bar{display:flex;height:14px;gap:2px;border-radius:2px;overflow:hidden;margin-bottom:10px}.seg{display:block;min-width:2px}.seg-github{background:var(--c-github)}.seg-x{background:var(--c-x)}.seg-web{background:var(--c-web)}.seg-arxiv{background:var(--c-arxiv)}.seg-youtube{background:var(--c-youtube)}.seg-notes{background:var(--c-notes)}
.legend{display:flex;flex-wrap:wrap;gap:6px 18px;font-size:13px;color:var(--ink-2)}.lg b{font-family:var(--mono);font-weight:600;color:var(--ink);font-variant-numeric:tabular-nums}.sw{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:6px;vertical-align:-1px}.facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px 22px;font-size:13.5px;color:var(--ink-2);margin-top:14px}.facts b{display:block;font-family:var(--mono);font-size:20px;font-weight:600;color:var(--ink);font-variant-numeric:tabular-nums;line-height:1.2}
section{margin:0 0 64px;padding-top:8px}section.bucket{border-top:3px solid var(--rule);padding-top:22px}#b-github{border-color:var(--c-github)}#b-x{border-color:var(--c-x)}#b-web{border-color:var(--c-web)}#b-arxiv{border-color:var(--c-arxiv)}#b-youtube{border-color:var(--c-youtube)}#b-notes{border-color:var(--c-notes)}.sh{margin-bottom:18px}.sh .eyebrow{display:block;margin-bottom:6px}
ol.themes{list-style:none;padding:0;margin:0;display:grid;gap:8px}ol.themes li{display:grid;grid-template-columns:minmax(0,1fr) 52px 120px;grid-template-areas:"n c b" "d d d";gap:2px 12px;align-items:center;padding:8px 0;border-bottom:1px solid var(--rule)}ol.themes .tn{grid-area:n;font-weight:700;font-size:15px}ol.themes .tc{grid-area:c;font-family:var(--mono);font-variant-numeric:tabular-nums;text-align:right;color:var(--ink-2);font-size:13px}ol.themes .tb{grid-area:b;height:8px;background:color-mix(in oklab,var(--ink) 8%,transparent);border-radius:2px;overflow:hidden}ol.themes .tb i{display:block;height:100%;background:var(--accent)}ol.themes .td{grid-area:d;font-size:14px;color:var(--ink-2)}ol.themes .trend{color:var(--ink-3);font-style:normal}ol.themes .trend::before{content:"↳ ";color:var(--accent)}
ol.hl{list-style:none;padding:0;margin:0}ol.hl li{display:grid;grid-template-columns:76px minmax(0,1fr);grid-template-areas:"k t" ". w";gap:1px 12px;padding:9px 0;border-bottom:1px solid var(--rule)}ol.hl .kind{grid-area:k;font-family:var(--mono);font-size:11px;color:var(--ink-3);text-transform:lowercase;padding-top:4px;word-break:break-word}ol.hl .ht{grid-area:t;font-weight:700;font-size:15.5px;line-height:1.35}ol.hl .dom{font-family:var(--mono);font-weight:400;font-size:11.5px;color:var(--ink-3);margin-left:6px;white-space:nowrap}ol.hl .hw{grid-area:w;font-size:14px;color:var(--ink-2)}ol.hl.best li{grid-template-columns:22px minmax(0,1fr)}ol.hl .mark{grid-area:k;color:var(--accent);font-size:13px;padding-top:3px}ol.hl.small .ht{font-size:14px;font-weight:400}ol.hl.small .hw{font-size:13px}
.two{display:grid;grid-template-columns:1fr 1fr;gap:0 32px}@media (max-width:700px){.two{grid-template-columns:1fr}}ul.people,ul.skills{list-style:none;padding:0;margin:0;font-size:14px}ul.people li{padding:6px 0;border-bottom:1px solid var(--rule)}ul.people span{color:var(--ink-2)}ul.skills li{display:inline-block;margin:0 6px 6px 0;padding:3px 9px;border:1px solid var(--rule);border-radius:999px;font-size:13px;color:var(--ink-2);background:var(--surface)}
ol.gap{list-style:none;padding:0;margin:0}ol.gap li{display:grid;grid-template-columns:64px minmax(0,1fr);gap:12px;padding:14px 0;border-bottom:1px solid var(--rule)}ol.gap p{margin:4px 0 0;font-size:14.5px;color:var(--ink-2)}ol.gap p.why{color:var(--ink)}ol.gap p.ev{font-size:13px;color:var(--ink-3)}.pill{display:inline-block;font-family:var(--mono);font-size:10.5px;letter-spacing:.06em;text-transform:uppercase;padding:3px 7px;border-radius:3px;margin-top:3px;border:1px solid}.pill.hi{color:var(--bad);border-color:var(--bad)}.pill.md{color:var(--warn);border-color:var(--warn)}.pill.lo{color:var(--ink-3);border-color:var(--rule)}
ul.covered{font-size:14px;color:var(--ink-2);padding-left:20px}details{border:1px solid var(--rule);border-radius:4px;padding:10px 14px;margin:10px 0;background:var(--surface)}summary{cursor:pointer;font-weight:700;font-size:14.5px}.method{font-size:13.5px;color:var(--ink-3);border-left:3px solid var(--rule);padding-left:12px;margin:14px 0}footer{font-size:13px;color:var(--ink-3);border-top:1px solid var(--rule);padding-top:16px;font-family:var(--mono)}@media (prefers-reduced-motion:no-preference){html{scroll-behavior:smooth}}`;
  const html = `<title>${esc(opts.title)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght,SOFT@9..144,300..700,0..100&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&family=JetBrains+Mono:wght@400;600&display=swap">
<style>${css}</style>
<div class="wrap"><nav class="rail" aria-label="Sections"><div class="grp">Digest</div><a href="#narrative">Narrative<span></span></a><a href="#best">Best writing<span>${nPieces}</span></a><a href="#gaps">Skill gaps<span>${nGaps}</span></a><div class="grp">Buckets</div>${toc}<div class="grp">Audit</div><a href="#critic">Critic &amp; addenda<span>${(D.addenda ?? []).length}</span></a><a href="#dropped">Dropped by verification<span>${nDropped}</span></a></nav>
<main><header><span class="eyebrow">${esc(opts.sub)}</span><h1>${esc(opts.title)}</h1><p class="lede">Every link saved to Drafts in the window, read chunk by chunk, synthesized per source, then curated for the best writing and the skills the captures keep asking for. Every highlight and recommendation was re-checked against the raw capture log and audited by a completeness critic; what still failed is listed at the end.</p>
<div class="ledger"><div class="bar">${bar}</div><div class="legend">${legend}</div><div class="facts"><div><b>${total.toLocaleString()}</b>unique single-link captures</div><div><b>${nMust}</b>must-read pieces of ${nPieces} curated</div><div><b>${nKept}</b>claims verified, ${nDropped} dropped</div><div><b>${D.stats?.chunks ?? "?"}</b>chunks read, ${keys.length} buckets synthesized</div></div></div></header>
<section id="narrative"><header class="sh"><span class="eyebrow">Narrative</span><h2>What the period was about</h2></header><div class="prose">${md(D.narrative ?? "")}</div></section>
<section id="best"><header class="sh"><span class="eyebrow">Curated · ${nPieces} pieces · ● = must read</span><h2>The excellent tech and AI writing</h2></header>${groups}<h3>Sources worth following</h3><ul class="people">${sources}</ul><p class="method">${esc(bw.method_note ?? "")}</p></section>
<section id="gaps"><header class="sh"><span class="eyebrow">Skill gaps · ranked by priority</span><h2>Skills you need but are missing</h2></header><h3>Install or adopt <span class="note">in your captures, not in your installed skills</span></h3><ol class="gap">${inst}</ol><h3>Skills to write yourself</h3><ol class="gap">${write}</ol><h3>Knowledge gaps <span class="note">saved often, not yet practiced</span></h3><ol class="gap">${know}</ol><h3>Workflow gaps <span class="note">from capture behaviour itself</span></h3><ol class="gap">${wf}</ol><h3>Already covered <span class="note">installed skills the captures keep rediscovering</span></h3><ul class="covered">${covered}</ul></section>
${keys.map(bucketSection).join("")}
<section id="critic"><header class="sh"><span class="eyebrow">Audit</span><h2>Completeness critic and addenda</h2></header><div class="prose small"><p>${esc(critic.overall ?? "")}</p></div><ol class="gap">${crit}</ol>${addenda}</section>
<section id="dropped"><header class="sh"><span class="eyebrow">Audit · ${nDropped} items</span><h2>Dropped by verification</h2></header><p class="prose small">Each curated piece, bucket highlight and install recommendation was handed to an independent refuter that grepped the capture log for the URL and compared the claim with the captured metadata. These did not survive; reasons are the refuter's own words.</p>${droppedHtml}${restoredHtml}</section>
<footer>${esc(D.footer ?? "Built with drafts-ledger.")}</footer></main></div>`;
  // markdown twin
  const L: string[] = [`# ${opts.title}`, "", `${total.toLocaleString()} single-link captures. ` + keys.map(k => `${LABEL[k] ?? k} ${(B[k].items ?? 0).toLocaleString()}`).join(" · "), "", "## Narrative", "", D.narrative ?? "", "", `## The excellent tech and AI writing (${nPieces} pieces, ★ = must read)`, ""];
  for (const g of bw.groups) { L.push(`### ${g.topic}`); for (const p of g.pieces) L.push(`- ${p.must_read ? "★ " : ""}[${p.title}](${p.url}) — ${p.source ?? ""}. ${p.why}`); L.push(""); }
  L.push("### Sources worth following"); for (const s of bw.sources_to_follow) L.push(`- **${s.name}**${s.url ? ` (${s.url})` : ""} — ${s.why}`);
  L.push("", "## Skills you need but are missing", "", "### Install or adopt"); for (const i of sg.install_or_adopt) L.push(`- [${i.priority}] [${i.name}](${i.url}) — ${i.what} **Why:** ${i.why_for_f} _Evidence: ${i.evidence}_`);
  L.push("", "### Skills to write yourself"); for (const i of sg.skills_to_write) L.push(`- [${i.priority}] **${i.name}** — ${i.what} **Why:** ${i.why_for_f} Seeds: ${(i.seed_urls ?? []).join(", ")}`);
  L.push("", "### Knowledge gaps"); for (const i of sg.knowledge_gaps) L.push(`- [${i.priority}] **${i.topic}** — ${i.why_gap} _Evidence: ${i.evidence}_ **First step:** ${i.first_step}`);
  L.push("", "### Workflow gaps"); for (const i of sg.workflow_gaps) L.push(`- **${i.observation}** → ${i.fix}`);
  L.push("", "### Already covered", ...sg.already_covered.map((s: string) => `- ${s}`));
  for (const k of keys) { const b = B[k]; L.push("", `## ${LABEL[k] ?? k} (${(b.items ?? 0).toLocaleString()} captures)`, "", b.overview ?? "", "", "**Themes:** " + (b.top_themes ?? []).map((t: any) => `${t.name} (${t.approx_count})`).join("; "), "", "**Highlights:**"); for (const h of b.top_highlights ?? []) L.push(`- [${h.title}](${h.url}) — ${h.why}`); L.push("", "**People:** " + (b.key_people ?? []).map((p: any) => `${p.handle} (${p.why})`).join("; "), "", "**Skills implied:** " + (b.skills_implied ?? []).join(", "), "", "**July vs August:** " + (b.july_vs_august ?? "")); }
  if (D.addenda?.length) { L.push("", "## Addenda from the completeness critic"); for (const a of D.addenda) L.push("", `### [${a.severity}] ${a.issue}`, "", a.addendum); }
  return { html, md: L.join("\n") };
}

// ---------- CLI ----------
const HELP = `drafts-ledger — read, search, export, enrich, chunk and write the Drafts.app store

USAGE
  drafts-ledger <command> [options]

COMMANDS
  stats                    counts by bucket, month, domain, x.com author, tag
  export                   items as jsonl | json | md | urls | csv   (--out FILE)
  search <text>            drafts whose content contains <text> (case-insensitive LIKE)
  get <uuid>               print one draft (content + tags + dates)
  enrich <items.jsonl>     add metadata: repos (gh graphql), tweets (fxtwitter), youtube (oembed), arxiv (export api), web (title/description). Cached in ${CACHE_DIR}
  chunk <items.jsonl>      write agent-sized chunk files + manifest.json into --out DIR
  render <digest.json>     render a digest (workflow output) to --out FILE.html and FILE.md
  create                   new draft from --file | --text | stdin, via drafts:// URL scheme
  append <uuid>            append --file | --text to a draft   (prepend: same, at the top)
  prepend <uuid>
  open <uuid>              open a draft in the app

FILTERS (stats, export, search)
  --since 2m|6w|30d|YYYY-MM-DD   default 2m       --until YYYY-MM-DD
  --folder inbox|archive|trash|all  default all   (trash always excluded unless named)
  --date created|modified|either  default either  --tag NAME   --match TEXT
  --max-links N   keep drafts with at most N urls (e.g. 9 = drop link dumps)
  --min-links N   --bucket a,b,c   --domain example.com   --rules rules.json (bucket→domains)
  --no-dedupe     keep every draft (default folds repeat saves of one canonical URL into dup×N)

OPTIONS
  --store PATH     Drafts sqlite store (default: Group Container)   --in-place  open the live store read-only instead of copying
  --format F       export: jsonl|json|md|urls|csv (default jsonl)  --out PATH   file or dir
  --kinds a,b      enrich: repos,tweets,youtube,arxiv,web (default all)   --concurrency N (default 8)   --no-cache
  --size N         chunk size (default 120)   --group bucket|week|none (default bucket)
  --title T --sub S   render header text   --tag T (repeatable, create)   --dry-run   --json   -h, --help

DRY RUN
  enrich: report cache hits and requests per kind, no network.  create/append/prepend/open: print the drafts:// call, do not open.
  export/chunk/render with --out: report what would be written, write nothing.

EXAMPLES
  drafts-ledger stats --since 2m --max-links 9
  drafts-ledger export --since 2026-07-05 --max-links 9 --out items.jsonl
  drafts-ledger enrich items.jsonl --dry-run && drafts-ledger enrich items.jsonl --out enriched.jsonl
  drafts-ledger chunk enriched.jsonl --out chunks/ --size 120
  drafts-ledger render digest.json --out digest.html --title "Capture Ledger, July–August 2026"
  drafts-ledger create --file digest.md --tag summary --tag github --dry-run
  drafts-ledger search "hashline" --since 3m`;

const { values: v, positionals: pos } = parseArgs({
  args: Bun.argv.slice(2), allowPositionals: true, strict: false,
  options: {
    since: { type: "string" }, until: { type: "string" }, folder: { type: "string", default: "all" }, date: { type: "string", default: "either" }, tag: { type: "string", multiple: true }, match: { type: "string" },
    "max-links": { type: "string" }, "min-links": { type: "string" }, bucket: { type: "string" }, domain: { type: "string" }, rules: { type: "string" },
    store: { type: "string", default: DEFAULT_STORE }, "in-place": { type: "boolean", default: false }, format: { type: "string", default: "jsonl" }, out: { type: "string" },
    kinds: { type: "string" }, concurrency: { type: "string", default: "8" }, "no-cache": { type: "boolean", default: false }, size: { type: "string", default: "120" }, group: { type: "string", default: "bucket" },
    title: { type: "string" }, sub: { type: "string" }, file: { type: "string" }, text: { type: "string" }, "no-dedupe": { type: "boolean", default: false }, "dry-run": { type: "boolean", default: false }, json: { type: "boolean", default: false }, help: { type: "boolean", short: "h", default: false },
  },
});
const cmd = pos[0];
if (v.help || !cmd) { out(HELP); process.exit(0); }
const dry = !!v["dry-run"];
const filters = (): Filters => ({ since: parseSince(v.since as string | undefined, parseSince("2m", "")), until: v.until ? parseSince(v.until as string, "") : undefined, folder: v.folder as string, tag: (v.tag as string[] | undefined)?.[0], match: v.match as string | undefined, minLinks: v["min-links"] ? +v["min-links"] : undefined, maxLinks: v["max-links"] ? +v["max-links"] : undefined, dateField: v.date as any, dedupe: !v["no-dedupe"] });
const rules = v.rules ? JSON.parse(readFileSync(v.rules as string, "utf8")) : undefined;
const readItems = (p: string): Item[] => readFileSync(p, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l));
const readInput = (): string => v.file ? readFileSync(v.file as string, "utf8") : v.text ? String(v.text) : readFileSync(0, "utf8");
function postFilter(items: Item[]): Item[] {
  const bs = splitList(v.bucket as string | undefined); const ds = splitList(v.domain as string | undefined);
  return items.filter(i => (!bs.length || bs.includes(i.bucket)) && (!ds.length || ds.some(d => i.domain === d || i.domain.endsWith("." + d))));
}
function withStore<T>(fn: (db: Database) => T): T { const s = openStore(v.store as string, !!v["in-place"]); try { return fn(s.db); } finally { s.cleanup(); } }

switch (cmd) {
  case "stats": {
    const f = filters();
    const { items: all, raw, dups, excluded } = withStore(db => loadItems(db, f, rules));
    const items = postFilter(all);
    const count = (key: (i: Item) => string | undefined) => { const c = new Map<string, number>(); for (const i of items) { const k = key(i); if (k) c.set(k, (c.get(k) ?? 0) + 1); } return [...c.entries()].sort((a, b) => b[1] - a[1]); };
    const stats = { window: [f.since, f.until ?? "now"], raw_drafts: raw, unique_items: items.length, duplicates_folded: dups, excluded_by_link_count: excluded, with_note: items.filter(i => i.extra.length > 40).length, tagged: items.filter(i => i.tags.length).length, buckets: count(i => i.bucket), months: count(i => i.date.slice(0, 7)).sort(), top_domains: count(i => i.domain).slice(0, 30), top_x_authors: count(i => i.x_user).slice(0, 25), tags: count(i => i.tags.join(",") || undefined).slice(0, 20), unique_repos: new Set(items.map(i => i.repo).filter(Boolean)).size };
    if (v.json) { out(JSON.stringify(stats, null, 1)); break; }
    out(`window ${stats.window.join(" → ")}  raw ${raw}  unique ${items.length}  dups ${dups}  excluded(link count) ${excluded}  with note ${stats.with_note}  tagged ${stats.tagged}  repos ${stats.unique_repos}`);
    out("buckets   " + stats.buckets.map(([k, n]) => `${k}=${n}`).join("  "));
    out("months    " + stats.months.map(([k, n]) => `${k}=${n}`).join("  "));
    out("domains   " + stats.top_domains.map(([k, n]) => `${k}(${n})`).join("  "));
    out("x authors " + stats.top_x_authors.map(([k, n]) => `${k}(${n})`).join("  "));
    if (stats.tags.length) out("tags      " + stats.tags.map(([k, n]) => `${k}(${n})`).join("  "));
    break;
  }
  case "export": {
    const f = filters();
    const { items: all, raw, dups, excluded } = withStore(db => loadItems(db, f, rules));
    const items = postFilter(all);
    const fmt = v.format as string;
    let body = "";
    if (fmt === "jsonl") body = items.map(i => JSON.stringify(i)).join("\n") + "\n";
    else if (fmt === "json") body = JSON.stringify(items, null, 1);
    else if (fmt === "urls") body = items.filter(i => i.url).map(i => i.url).join("\n") + "\n";
    else if (fmt === "csv") body = "date,bucket,domain,url,dup,tags,note\n" + items.map(i => [i.date, i.bucket, i.domain, i.url ?? "", i.dup_count ?? 1, i.tags.join(";"), i.extra.replace(/\n/g, " ")].map(x => `"${String(x).replace(/"/g, '""')}"`).join(",")).join("\n") + "\n";
    else if (fmt === "md") body = items.map(i => `- ${i.date} ${i.url ? `<${i.url}>` : "(note)"}${i.dup_count ? ` ×${i.dup_count}` : ""}${i.extra ? ` — ${i.extra.replace(/\n/g, " ").slice(0, 200)}` : ""}`).join("\n") + "\n";
    else die(`bad --format '${fmt}'`);
    err(`raw ${raw}  unique ${items.length}  dups ${dups}  excluded ${excluded}`);
    if (v.out) { if (dry) out(`[dry-run] would write ${body.length} chars (${items.length} items, ${fmt}) to ${v.out}`); else { writeFileSync(v.out as string, body); out(`wrote ${items.length} items → ${v.out}`); } }
    else process.stdout.write(body);
    break;
  }
  case "search": {
    const q = pos[1] ?? die("search needs <text>");
    const f = { ...filters(), match: q };
    const { items } = withStore(db => loadItems(db, f, rules));
    const hits = postFilter(items);
    if (v.json) { out(JSON.stringify(hits, null, 1)); break; }
    for (const i of hits) out(`${i.date}  ${i.uuid}  ${i.url ?? "(note)"}${i.dup_count ? `  ×${i.dup_count}` : ""}${i.extra ? `\n    ${i.extra.replace(/\n/g, " ").slice(0, 160)}` : ""}`);
    err(`${hits.length} matches`);
    break;
  }
  case "get": {
    const uuid = pos[1] ?? die("get needs <uuid>");
    const row = withStore(db => db.query("SELECT ZUUID uuid, ZCREATED_AT c, ZMODIFIED_AT m, ZFOLDER folder, ZFLAGGED flagged, ZCACHED_TAGS tags, ZCONTENT content FROM ZMANAGEDDRAFT WHERE ZUUID = ?").get(uuid) as any);
    if (!row) die(`no draft ${uuid}`);
    const o = { uuid: row.uuid, created: fromCoreData(row.c), modified: fromCoreData(row.m), folder: Object.keys(FOLDERS).find(k => FOLDERS[k] === row.folder) ?? row.folder, flagged: !!row.flagged, tags: parseTags(row.tags), content: row.content };
    out(v.json ? JSON.stringify(o, null, 1) : `${o.uuid}  created ${o.created}  modified ${o.modified}  folder ${o.folder}  tags ${o.tags.join(", ") || "-"}\n\n${o.content}`);
    break;
  }
  case "enrich": {
    const src = pos[1] ?? die("enrich needs <items.jsonl>");
    const items = readItems(src);
    const kinds = (splitList(v.kinds as string | undefined) as Kind[]).filter(Boolean); const useKinds = kinds.length ? kinds : ALL_KINDS;
    const caches = Object.fromEntries(ALL_KINDS.map(k => [k, v["no-cache"] ? new Map() : cacheLoad(k)])) as Record<Kind, Map<string, any>>;
    const plan = useKinds.map(k => { const keys = [...new Set(items.map(i => keyFor(k, i)).filter(Boolean) as string[])]; const need = keys.filter(x => !caches[k].has(x)); return { kind: k, total: keys.length, cached: keys.length - need.length, need }; });
    out(plan.map(p => `${p.kind.padEnd(8)} ${String(p.total).padStart(5)} keys  ${String(p.cached).padStart(5)} cached  ${String(p.need.length).padStart(5)} to fetch${p.kind === "repos" ? ` (${Math.ceil(p.need.length / 100)} graphql batches)` : p.kind === "arxiv" ? ` (${Math.ceil(p.need.length / 50)} api batches)` : ""}`).join("\n"));
    if (dry) { out(`[dry-run] no requests made. Samples: ` + plan.filter(p => p.need.length).map(p => `${p.kind}: ${p.need.slice(0, 2).join(", ")}`).join(" | ")); break; }
    const conc = +(v.concurrency as string);
    for (const p of plan) {
      if (!p.need.length) continue;
      let done = 0; const errs: string[] = [];
      await fetchKind(p.kind, p.need, p.kind === "tweets" ? Math.min(conc, 4) : conc, (k, o) => { if (o === undefined) { if (!caches[p.kind].has(k)) { caches[p.kind].set(k, { key: k, error: "not returned" }); } return; } caches[p.kind].set(k, o); if (!o.error) cacheAppend(p.kind, o); else errs.push(`${k}: ${o.error}`); done++; if (done % 100 === 0) err(`  ${p.kind} ${done}/${p.need.length}`); });
      err(`${p.kind}: fetched ${done}, errors ${errs.length}${errs.length ? " (first: " + errs.slice(0, 2).join("; ") + ")" : ""}`);
    }
    for (const it of items) it.meta = metaLine(it, caches);
    const body = items.map(i => JSON.stringify(i)).join("\n") + "\n";
    const hit = items.filter(i => i.meta).length;
    if (v.out) { writeFileSync(v.out as string, body); out(`wrote ${items.length} items (${hit} with metadata) → ${v.out}`); } else process.stdout.write(body);
    break;
  }
  case "chunk": {
    const src = pos[1] ?? die("chunk needs <items.jsonl>"); const dir = (v.out as string) ?? die("chunk needs --out DIR");
    const items = readItems(src); const size = +(v.size as string); const mode = v.group as string;
    const GROUP: Record<string, string> = { github: "github", x: "x", arxiv: "arxiv", youtube: "youtube", "text-only": "notes" };
    const groups = new Map<string, Item[]>();
    for (const it of items) { const g = mode === "bucket" ? (GROUP[it.bucket] ?? "web") : mode === "week" ? `w${it.date}`.slice(0, 8) : "all"; if (!groups.has(g)) groups.set(g, []); groups.get(g)!.push(it); }
    const manifest: any[] = [];
    if (!dry) mkdirSync(dir, { recursive: true });
    for (const [g, ls] of groups) {
      ls.sort((a, b) => a.date.localeCompare(b.date));
      for (let n = 0, s = 0; s < ls.length; n++, s += size) {
        const part = ls.slice(s, s + size); const id = `${g}-${String(n + 1).padStart(2, "0")}`; const p = join(dir, `${id}.txt`);
        const text = `# bucket=${g} chunk=${n + 1} items=${part.length} dates=${part[0].date}..${part[part.length - 1].date}\n# format: date | url | metadata (title/desc/stars/tweet text) | NOTE: user's own text captured with it | dup×N | tags\n` + part.map(chunkLine).join("\n") + "\n";
        if (!dry) writeFileSync(p, text);
        manifest.push({ id, bucket: g, path: p, n: part.length, from: part[0].date, to: part[part.length - 1].date, chars: text.length });
      }
    }
    if (!dry) writeFileSync(join(dir, "manifest.json"), JSON.stringify(manifest.map(({ chars, ...m }) => m), null, 1));
    out(`${dry ? "[dry-run] would write" : "wrote"} ${manifest.length} chunks (${items.length} items) → ${dir}: ` + [...groups.keys()].map(g => `${g}=${manifest.filter(m => m.bucket === g).length}`).join(" ") + (dry ? "" : `\nmanifest: ${join(dir, "manifest.json")}`));
    if (v.json) out(JSON.stringify(manifest, null, 1));
    break;
  }
  case "render": {
    const src = pos[1] ?? die("render needs <digest.json>"); const outp = (v.out as string) ?? die("render needs --out FILE.html");
    const D = JSON.parse(readFileSync(src, "utf8"));
    const { html, md: mdTxt } = render(D, { title: (v.title as string) ?? D.title ?? "Capture Ledger", sub: (v.sub as string) ?? D.subtitle ?? "Drafts app · single-link captures" });
    const mdPath = outp.replace(/\.html?$/, "") + ".md";
    if (dry) { out(`[dry-run] would write ${html.length} chars → ${outp} and ${mdTxt.length} chars → ${mdPath}`); break; }
    writeFileSync(outp, html); writeFileSync(mdPath, mdTxt); out(`wrote ${outp} (${html.length} chars) and ${mdPath} (${mdTxt.length} chars)`);
    break;
  }
  case "create": {
    const text = readInput(); if (!text.trim()) die("empty text");
    const url = draftsUrl("create", { text, tag: v.tag as string[] | undefined });
    if (url.length > 200_000) err(`warning: URL is ${url.length} chars; very large drafts may fail to open`);
    openUrl(url, dry, text);
    break;
  }
  case "append": case "prepend": {
    const uuid = pos[1] ?? die(`${cmd} needs <uuid>`); const text = readInput();
    openUrl(draftsUrl(cmd, { uuid, text }), dry, text);
    break;
  }
  case "open": {
    const uuid = pos[1] ?? die("open needs <uuid>");
    openUrl(draftsUrl("open", { uuid }), dry, uuid);
    break;
  }
  default: die(`unknown command '${cmd}'\n\n${HELP}`);
}
