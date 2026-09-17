#!/usr/bin/env python3
"""Renders an audit's open cases as one self-contained HTML page for a human to judge.

Three panes per case — source, artefact, destination — because a reviewer holding only the
artefact can say whether it looks good but never whether anything is missing.

Images are inlined as data URIs by default, so the output is a single file that opens over
`file://` with no server. That is not only convenience: a served page resolves every image
through a path the generator had to guess, and guessing it wrong yields a page that renders
with silent holes. Inlining removes the guess. `--link` keeps references instead when the
page would be too large, and then every reference is checked before the file is written.

Usage:
    review_pack.py cases.json -o review.html          # inline (default)
    review_pack.py cases.json -o review.html --link --root .
    review_pack.py --schema                           # print the cases.json contract
"""

from __future__ import annotations

import argparse
import base64
import html
import json
import mimetypes
import sys
import urllib.parse
from pathlib import Path
from typing import Any

SCHEMA = """cases.json contract
===================

{
  "title":    "Figure fidelity — 12 crop calls that are yours to make",
  "subtitle": "Left: the real source. Middle: what was extracted. Right: where it lands.",

  "resolved": ["FBR-AM-001 p17 — crop now carries all three data rows"],
      # optional; shown as a banner so a fixed case reads as fixed rather than vanishing

  "cases": [{
    "id":     "FCN-PQ-004-p11",            # optional; falls back to the index
    "issue":  "cropped",                    # any label; drives the colour and the ask
    "title":  "FCN-PQ-004 · page 11",       # shown in the header and the nav
    "subtitle": "FCN-PQ-004 环保应急制度.pdf",  # optional, dimmed beside the title

    "note":    "Reviewer: left portion of the hierarchy is cut off",   # optional
    "finding": "Confirmed — the leftmost box fails the 40pt long-side test",  # optional
    "ask":     "Is the missing part real content, or is the crop good enough?",

    "source":      {"label": "Source page", "image": "pages/p011.png",
                    "link": "…/doc.pdf#page=11", "link_label": "Open the PDF at page 11"},
    "artefacts":   [{"id": "fig-p011-01", "image": "…/fig-p011-01.png",
                     "category": "flow", "caption": "Emergency command structure",
                     "meta": "vector · 10.2% of page"}],
    "destination": {"label": "Markdown", "text": "#### 组织机构…",
                    "link": "…/doc.md", "link_label": "Open the Markdown"}
  }]
}

Every pane is optional and takes `image`, `text`, or both. An empty `artefacts` list
renders as "nothing was extracted", which is the right thing to show for a missed item.
`category` renders as a coloured chip; any string works.
"""

ISSUE_COLOURS = {
    "cropped": "#b45309",
    "contaminated": "#7c2d12",
    "missed": "#991b1b",
    "wrong": "#9f1239",
    "unverified": "#3f6212",
}
FALLBACK_COLOUR = "#374151"

CATEGORY_COLOURS = {
    "instruction": "#2563eb",
    "lookup": "#7c3aed",
    "flow": "#059669",
    "template": "#d97706",
    "chrome": "#6b7280",
    "scanned-page": "#0891b2",
    "unlabelled": "#dc2626",
}


class MissingAsset(Exception):
    """A pane names a file that is not there."""


def _resolve(root: Path, ref: str) -> Path:
    path = Path(ref)
    return path if path.is_absolute() else root / path


def _data_uri(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "image/png"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def _img_src(ref: str, root: Path, inline: bool, missing: list[str]) -> str | None:
    path = _resolve(root, ref)
    if not path.exists():
        missing.append(str(path))
        return None
    return _data_uri(path) if inline else urllib.parse.quote(ref)


def _pane(
    pane: dict[str, Any] | None, ordinal: int, default_label: str, root: Path,
    inline: bool, missing: list[str], empty: str = "",
) -> str:
    if not pane:
        return (
            f'<div class="pane"><h3>{ordinal} · {html.escape(default_label)}</h3>'
            f'<div class="none">{html.escape(empty)}</div></div>'
        )
    label = html.escape(pane.get("label") or default_label)
    body = ""
    if pane.get("image"):
        src = _img_src(pane["image"], root, inline, missing)
        if src:
            body += f'<img class="pg" src="{src}" loading="lazy">'
    if pane.get("text"):
        body += f'<pre class="txt">{html.escape(pane["text"])}</pre>'
    inner = body or '<div class="none">—</div>'
    return f'<div class="pane"><h3>{ordinal} · {label}</h3>{inner}</div>'


def _artefact_pane(
    case: dict[str, Any], root: Path, inline: bool, missing: list[str]
) -> str:
    artefacts = case.get("artefacts") or []
    if not artefacts:
        return (
            '<div class="pane"><h3>2 · What was extracted <span class="sub">nothing</span></h3>'
            '<div class="none">Nothing was extracted from this source.<br>'
            "The reviewer says there should be.</div></div>"
        )
    figures = []
    for art in artefacts:
        bits = ""
        if art.get("image"):
            src = _img_src(art["image"], root, inline, missing)
            if src:
                bits += f'<img src="{src}" loading="lazy">'
        if art.get("text"):
            bits += f'<pre class="txt">{html.escape(art["text"])}</pre>'
        chip = ""
        if art.get("category"):
            cat = art["category"]
            colour = CATEGORY_COLOURS.get(cat, FALLBACK_COLOUR)
            chip = f'<span class="chip" style="background:{colour}">{html.escape(cat)}</span> '
        meta = " · ".join(
            html.escape(str(v)) for v in (art.get("id"), art.get("meta")) if v
        )
        caption = (
            f'<br>{html.escape(art["caption"])}' if art.get("caption") else ""
        )
        figures.append(
            f'<figure>{bits}<figcaption>{chip}{meta}{caption}</figcaption></figure>'
        )
    return (
        f'<div class="pane"><h3>2 · What was extracted '
        f'<span class="sub">{len(artefacts)} artefact(s)</span></h3>{"".join(figures)}</div>'
    )


def _links(case: dict[str, Any]) -> str:
    buttons = []
    for pane, cls in (("source", "btn"), ("destination", "btn alt")):
        data = case.get(pane)
        if data and data.get("link"):
            label = data.get("link_label") or f"Open the {pane}"
            buttons.append(
                f'<a class="{cls}" href="{html.escape(data["link"])}" target="_blank">'
                f"{html.escape(label)} ↗</a>"
            )
    return f'<div class="links">{"".join(buttons)}</div>' if buttons else ""


def build(spec: dict[str, Any], root: Path, inline: bool) -> tuple[str, list[str]]:
    missing: list[str] = []
    cases = spec.get("cases", [])
    sections, nav = [], []

    for i, case in enumerate(cases):
        issue = case.get("issue", "open")
        colour = ISSUE_COLOURS.get(issue, FALLBACK_COLOUR)
        title = case.get("title") or case.get("id") or f"case {i + 1}"
        nav.append(
            f'<a href="#c{i}"><span class="d" style="background:{colour}"></span>'
            f"{html.escape(title)}</a>"
        )
        blocks = ""
        if case.get("note"):
            blocks += f'<div class="note"><b>Reviewer:</b> {html.escape(case["note"])}</div>'
        if case.get("finding"):
            blocks += f'<div class="mine"><b>My finding:</b> {html.escape(case["finding"])}</div>'
        sections.append(f"""
<section id="c{i}">
  <header style="border-left:6px solid {colour}">
    <div class="hl"><span class="n">{i + 1}/{len(cases)}</span>
      <span class="badge" style="background:{colour}">{html.escape(issue)}</span>
      <b>{html.escape(title)}</b>
      <span class="file">{html.escape(case.get("subtitle", ""))}</span></div>
    {blocks}
  </header>
  <div class="grid">
    {_pane(case.get("source"), 1, "Source", root, inline, missing, "no source given")}
    {_artefact_pane(case, root, inline, missing)}
    {_pane(case.get("destination"), 3, "Destination", root, inline, missing, "—")}
  </div>
  {_links(case)}
  <div class="ask"><b>What I need you to judge:</b>
    {html.escape(case.get("ask", "Is this artefact faithful to its source?"))}</div>
</section>""")

    resolved = spec.get("resolved") or []
    resolved_html = (
        '<div class="resolved"><b>Fixed since the last pass — these dropped out:</b><ul>'
        + "".join(f"<li>{html.escape(r)}</li>" for r in resolved)
        + "</ul></div>"
        if resolved
        else ""
    )
    page = TEMPLATE.format(
        title=html.escape(spec.get("title", "Ground-truth review")),
        subtitle=html.escape(
            spec.get("subtitle", "Source, artefact, destination. Click any image to enlarge.")
        ),
        nav="".join(nav),
        resolved=resolved_html,
        body="".join(sections),
    )
    return page, missing


TEMPLATE = """<!doctype html><meta charset="utf-8"><title>{title}</title>
<style>
:root{{color-scheme:light dark}}
*{{box-sizing:border-box}}
body{{margin:0;font:14px/1.5 ui-sans-serif,-apple-system,"PingFang SC",sans-serif;
background:#f6f7f9;color:#111}}
@media(prefers-color-scheme:dark){{body{{background:#0e1013;color:#e8eaed}}}}
.top{{position:sticky;top:0;z-index:9;background:#111;color:#fff;padding:14px 20px}}
.top h1{{margin:0 0 4px;font-size:17px}} .top p{{margin:0;opacity:.75;font-size:13px}}
nav{{display:flex;flex-wrap:wrap;gap:6px;padding:10px 20px;background:#1c1f24;
position:sticky;top:64px;z-index:8}}
nav a{{color:#cbd5e1;text-decoration:none;font-size:12px;background:#2a2f37;padding:4px 9px;
border-radius:5px;display:flex;align-items:center;gap:6px}}
nav a:hover{{background:#3a424e;color:#fff}}
.d{{width:8px;height:8px;border-radius:50%;display:inline-block}}
section{{margin:22px 20px;background:#fff;border-radius:10px;overflow:hidden;
box-shadow:0 1px 3px #0002}}
@media(prefers-color-scheme:dark){{section{{background:#171a1f;box-shadow:none;
border:1px solid #262b33}}}}
header{{padding:12px 16px;background:#fafbfc}}
@media(prefers-color-scheme:dark){{header{{background:#1b1f26}}}}
.hl{{display:flex;align-items:center;gap:10px;flex-wrap:wrap;font-size:15px}}
.n{{font:11px ui-monospace,monospace;opacity:.5}}
.badge{{color:#fff;font-size:11px;padding:2px 8px;border-radius:4px;text-transform:uppercase;
letter-spacing:.04em}}
.file{{font-size:12px;opacity:.55}}
.note{{margin-top:8px;font-size:13px;background:#fff8e6;border:1px solid #f0e0b0;
padding:8px 10px;border-radius:6px}}
@media(prefers-color-scheme:dark){{.note{{background:#241f10;border-color:#4a3f1c}}}}
.mine{{margin-top:8px;font-size:13px;background:#eaf7ee;border:1px solid #b7dfc4;
padding:8px 10px;border-radius:6px}}
@media(prefers-color-scheme:dark){{.mine{{background:#0f1f14;border-color:#1f4a2e}}}}
.resolved{{margin:16px 20px;padding:12px 16px;background:#eaf7ee;border:1px solid #b7dfc4;
border-radius:8px;font-size:13px}}
@media(prefers-color-scheme:dark){{.resolved{{background:#0f1f14;border-color:#1f4a2e}}}}
.resolved li{{margin:3px 0}}
.grid{{display:grid;grid-template-columns:1fr 1fr 1fr;border-top:1px solid #e6e8eb}}
@media(max-width:1250px){{.grid{{grid-template-columns:1fr}}}}
.pane{{padding:12px 14px;border-right:1px solid #e6e8eb;min-width:0}}
@media(prefers-color-scheme:dark){{.pane,.grid{{border-color:#262b33}}}}
.pane:last-child{{border-right:0}}
h3{{margin:0 0 10px;font-size:12px;text-transform:uppercase;letter-spacing:.05em;opacity:.6}}
.sub{{text-transform:none;letter-spacing:0;opacity:.7;font-weight:400}}
img.pg,figure img{{width:100%;border:1px solid #d8dbe0;border-radius:6px;background:#fff;
cursor:zoom-in}}
figure{{margin:0 0 14px}}
figcaption{{font:11px ui-monospace,monospace;opacity:.65;margin-top:4px}}
.chip{{display:inline-block;font:10px/1.5 ui-sans-serif;text-transform:uppercase;
letter-spacing:.05em;padding:1px 6px;border-radius:4px;color:#fff;margin-right:5px}}
.none{{padding:26px 14px;text-align:center;border:2px dashed #d0d4da;border-radius:8px;
font-size:13px;opacity:.75}}
pre.txt{{margin:0;white-space:pre-wrap;word-break:break-word;
font:12px/1.55 ui-monospace,monospace;background:#f7f8fa;border:1px solid #e2e5e9;
border-radius:6px;padding:10px;max-height:560px;overflow:auto}}
@media(prefers-color-scheme:dark){{pre.txt{{background:#12151a;border-color:#262b33}}}}
.links{{display:flex;gap:8px;padding:10px 16px;border-top:1px solid #e6e8eb;flex-wrap:wrap}}
@media(prefers-color-scheme:dark){{.links{{border-color:#262b33}}}}
.btn{{font-size:12.5px;text-decoration:none;background:#111;color:#fff;padding:6px 12px;
border-radius:6px}}
.btn.alt{{background:#3b5bdb}} .btn:hover{{opacity:.85}}
.ask{{padding:11px 16px;background:#eef4ff;border-top:1px solid #d8e3f7;font-size:13px}}
@media(prefers-color-scheme:dark){{.ask{{background:#111a2b;border-color:#1e2c47}}}}
dialog{{border:0;padding:0;background:transparent;max-width:96vw;max-height:96vh}}
dialog img{{max-width:96vw;max-height:96vh;border-radius:8px}}
dialog::backdrop{{background:#000d}}
</style>
<div class="top"><h1>{title}</h1><p>{subtitle}</p></div>
<nav>{nav}</nav>
{resolved}
{body}
<dialog id="z" onclick="this.close()"><img id="zi"></dialog>
<script>
document.addEventListener('click',e=>{{
  if(e.target.tagName==='IMG'&&e.target.id!=='zi'){{
    document.getElementById('zi').src=e.target.src;
    document.getElementById('z').showModal();}}
}});
</script>"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("cases", nargs="?", help="Path to cases.json")
    ap.add_argument("-o", "--out", default="review.html", help="Output HTML path")
    ap.add_argument("--root", default=".", help="Root that relative asset paths resolve against")
    ap.add_argument(
        "--link", action="store_true", help="Reference images instead of inlining them"
    )
    ap.add_argument("--schema", action="store_true", help="Print the cases.json contract")
    args = ap.parse_args()

    if args.schema:
        print(SCHEMA)
        return 0
    if not args.cases:
        ap.error("cases.json is required (or pass --schema)")

    spec = json.loads(Path(args.cases).read_text(encoding="utf-8"))
    page, missing = build(spec, Path(args.root).resolve(), inline=not args.link)

    if missing:
        print(f"{len(missing)} asset(s) named by a case are not on disk:", file=sys.stderr)
        for path in missing[:20]:
            print(f"  {path}", file=sys.stderr)
        print("\nNothing written — fix the paths and re-run.", file=sys.stderr)
        return 1

    out = Path(args.out)
    out.write_text(page, encoding="utf-8")
    size_mb = len(page.encode()) / 1_000_000
    print(f"wrote {out} — {len(spec.get('cases', []))} cases, {size_mb:.1f} MB")
    if not args.link and size_mb > 50:
        print("  (large; --link keeps references instead of inlining)")
    print(f"open it: file://{out.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
