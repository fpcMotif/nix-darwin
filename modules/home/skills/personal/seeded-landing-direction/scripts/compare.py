#!/usr/bin/env python3
"""Emit compare.html from a variants.json and the captures beside it.

Usage: python3 compare.py captures/variants.json > compare.html

variants.json is a list of objects:
  key, name, register, seed, findings [{fact, decision}], type, structure, device, fit, risk,
  desktop (image path relative to the json), mobile (image path)
Images are embedded as data URIs; keep each under ~400 KB (downscale to 720px / 300px wide).
"""

from __future__ import annotations

import base64
import html
import json
import mimetypes
import pathlib
import sys


def data_uri(base: pathlib.Path, rel: str) -> str:
    if not rel:
        return ""
    p = base / rel
    if not p.exists():
        return ""
    mime = mimetypes.guess_type(p.name)[0] or "image/png"
    return f"data:{mime};base64," + base64.b64encode(p.read_bytes()).decode()


def fingerprint(seed: str) -> str:
    cells = []
    for ch in seed:
        cls = "z" if ch == "0" else "d" if ch.isdigit() else "u" if ch.isupper() else "l"
        cells.append(f'<i class="{cls}"></i>')
    return "".join(cells)


def dossier(base: pathlib.Path, v: dict) -> str:
    findings = "".join(
        f"<li><b>{html.escape(x['fact'])}</b><span>{html.escape(x['decision'])}</span></li>"
        for x in v.get("findings", [])
    )
    rows = "".join(
        f"<div><dt>{k}</dt><dd>{html.escape(str(v.get(k.lower(), '')))}</dd></div>"
        for k in ("Register", "Type", "Structure", "Device", "Fit", "Risk")
    )
    desk = data_uri(base, v.get("desktop", ""))
    mob = data_uri(base, v.get("mobile", ""))
    img = lambda src, alt: f'<img src="{src}" alt="{alt}" loading="lazy">' if src else '<p class="pending">capture pending</p>'
    return f"""
<section class="dossier" id="v-{v['key']}">
  <header class="dh"><div><p class="eyebrow">Variant {html.escape(v['key'].upper())} · <span class="it">{html.escape(v.get('register', ''))}</span></p><h2>{html.escape(v['name'])}</h2></div>
  {f'<a class="open" href="{html.escape(v["url"])}">Open ↗</a>' if v.get("url") else ""}</header>
  <div class="dgrid">
    <div>
      <p class="lab">Seed · {len(v['seed'])} characters</p>
      <p class="seed">{html.escape(v['seed'])}</p>
      <div class="fp" aria-hidden="true">{fingerprint(v['seed'])}</div>
      <p class="lab">What the string dictated</p>
      <ul class="findings">{findings}</ul>
      <dl class="rules">{rows}</dl>
    </div>
    <div class="dright">
      <figure class="frame"><figcaption>desktop · scroll inside</figcaption><div class="scroll">{img(desk, "desktop capture")}</div></figure>
      <figure class="frame"><figcaption>mobile</figcaption><div class="scroll">{img(mob, "mobile capture")}</div></figure>
    </div>
  </div>
</section>"""


def main() -> None:
    src = pathlib.Path(sys.argv[1])
    variants = json.loads(src.read_text())
    base = src.parent
    chips = "".join(f'<a class="chip" href="#v-{v["key"]}">{v["key"].upper()} <span>{html.escape(v["name"])}</span></a>' for v in variants)
    matrix = "".join(
        f'<tr><th scope="row"><a href="#v-{v["key"]}">{v["key"].upper()} · {html.escape(v["name"])}</a><small>{html.escape(v.get("register", ""))}</small></th>'
        f'<td><div class="fp small">{fingerprint(v["seed"])}</div></td><td>{html.escape(v.get("type", ""))}</td>'
        f'<td>{html.escape(v.get("device", ""))}</td><td>{html.escape(v.get("fit", ""))}</td></tr>'
        for v in variants
    )
    options = "".join(f'<option value="{v["key"]}">{v["key"].upper()} · {html.escape(v["name"])}</option>' for v in variants)
    imgs = ",".join(f'"{v["key"]}": "{data_uri(base, v.get("desktop", ""))}"' for v in variants)
    names = ",".join(f'"{v["key"]}": "{v["key"].upper()} · {html.escape(v["name"])}"' for v in variants)
    first, second = variants[0]["key"], (variants[1]["key"] if len(variants) > 1 else variants[0]["key"])
    print(f"""<title>Landing Directions</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;1,6..72,400&family=Plus+Jakarta+Sans:wght@400;600&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
:root{{--paper:#fff;--ink:#171a16;--mute:#6a7066;--line:#d9ddd5;--tint:#f4f6f1;--accent:#64a733;--accent-ink:#2f5a12;--u:#8c948a;--l:#c9cfc4;--d:#64a733;--z:#14260d}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{--paper:#0f150c;--ink:#e9ede4;--mute:#9aa394;--line:#263120;--tint:#151d11;--accent:#8cc65a;--accent-ink:#b9e08e;--u:#6f7a68;--l:#3a4634;--d:#8cc65a;--z:#dbe8cf}}}}
:root[data-theme="dark"]{{--paper:#0f150c;--ink:#e9ede4;--mute:#9aa394;--line:#263120;--tint:#151d11;--accent:#8cc65a;--accent-ink:#b9e08e;--u:#6f7a68;--l:#3a4634;--d:#8cc65a;--z:#dbe8cf}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--paper);color:var(--ink);font:15px/1.55 "Plus Jakarta Sans",system-ui,sans-serif}}
.wrap{{max-width:1320px;margin:0 auto;padding:0 24px}}.mast{{padding:40px 0 28px;border-bottom:1px solid var(--line);display:grid;gap:16px}}
.eyebrow{{margin:0;font:11px "JetBrains Mono",monospace;letter-spacing:.28em;text-transform:uppercase;color:var(--accent-ink)}}.eyebrow .it{{font:italic 14px Newsreader,serif;text-transform:none;letter-spacing:0}}
h1{{margin:0;font:400 clamp(2.4rem,5vw,4.4rem)/1.02 Newsreader,serif;letter-spacing:-.02em;max-width:18ch}}h2{{margin:0;font:400 clamp(1.8rem,3vw,2.6rem)/1.05 Newsreader,serif}}
.chips{{display:flex;flex-wrap:wrap;gap:8px}}.chip{{display:inline-flex;gap:8px;align-items:baseline;padding:8px 14px;border:1px solid var(--line);border-radius:999px;text-decoration:none;color:inherit;font:11px "JetBrains Mono",monospace;letter-spacing:.18em;text-transform:uppercase}}.chip span{{font:italic 15px Newsreader,serif;text-transform:none;letter-spacing:0}}
.matrix{{padding:40px 0;border-bottom:1px solid var(--line)}}.tablewrap{{overflow-x:auto;margin-top:24px}}table{{width:100%;border-collapse:collapse;min-width:900px}}th,td{{text-align:left;vertical-align:top;padding:14px 12px;border-top:1px solid var(--line);font-size:13.5px}}thead th{{font:500 11px "JetBrains Mono",monospace;letter-spacing:.2em;text-transform:uppercase;color:var(--mute);border-top:0}}tbody th a{{text-decoration:none;color:inherit;font-weight:600}}tbody th small{{display:block;font:italic 14px Newsreader,serif;color:var(--mute)}}
.fp{{display:flex;align-items:flex-end;gap:1px;height:24px}}.fp i{{flex:1 1 0;display:block}}.fp .u{{height:60%;background:var(--u)}}.fp .l{{height:32%;background:var(--l)}}.fp .d{{height:100%;background:var(--d)}}.fp .z{{height:100%;background:var(--z)}}.fp.small{{height:18px;min-width:180px}}
.dossier{{padding:56px 0;border-bottom:1px solid var(--line)}}.dh{{display:flex;justify-content:space-between;align-items:flex-end;gap:24px;flex-wrap:wrap;margin-bottom:28px}}.open{{font:11px "JetBrains Mono",monospace;letter-spacing:.2em;text-transform:uppercase;text-decoration:none;color:inherit;padding:12px 16px;border:1px solid var(--line);border-radius:6px}}
.dgrid{{display:grid;grid-template-columns:minmax(0,5fr) minmax(0,7fr);gap:40px;align-items:start}}@media (max-width:960px){{.dgrid{{grid-template-columns:1fr}}}}
.lab{{margin:0 0 8px;font:11px "JetBrains Mono",monospace;letter-spacing:.2em;text-transform:uppercase;color:var(--mute)}}.seed{{margin:0 0 6px;font:12.5px/1.7 "JetBrains Mono",monospace;word-break:break-all}}
.findings{{list-style:none;margin:24px 0 28px;padding:0;display:grid;gap:12px}}.findings li{{display:grid;gap:2px;padding-left:14px;border-left:2px solid var(--accent)}}.findings b{{font-size:14px}}.findings span{{color:var(--mute);font-size:13.5px}}
.rules{{margin:0;border-top:1px solid var(--line)}}.rules div{{display:grid;grid-template-columns:110px 1fr;gap:12px;padding:10px 0;border-bottom:1px solid var(--line);font-size:13.5px}}.rules dt{{font:11px "JetBrains Mono",monospace;letter-spacing:.16em;text-transform:uppercase;color:var(--mute);padding-top:3px}}.rules dd{{margin:0}}
.dright{{display:grid;grid-template-columns:minmax(0,1fr) 190px;gap:16px;align-items:start}}@media (max-width:720px){{.dright{{grid-template-columns:1fr}}}}
.frame{{margin:0;border:1px solid var(--line);border-radius:6px;overflow:hidden;background:var(--tint)}}.frame figcaption{{font:11px "JetBrains Mono",monospace;letter-spacing:.16em;text-transform:uppercase;color:var(--mute);padding:8px 12px;border-bottom:1px solid var(--line)}}.frame .scroll{{height:640px;overflow-y:auto}}.frame img{{display:block;width:100%;height:auto}}.pending{{margin:0;padding:24px;color:var(--mute)}}
.sbs{{padding:56px 0}}.picker{{display:flex;gap:16px;flex-wrap:wrap;margin:20px 0}}.picker label{{display:grid;gap:6px;font:11px "JetBrains Mono",monospace;letter-spacing:.2em;text-transform:uppercase;color:var(--mute)}}select{{font:14px "Plus Jakarta Sans",system-ui;padding:10px 12px;border:1px solid var(--line);border-radius:6px;background:var(--paper);color:var(--ink);min-width:220px}}
.pair{{display:grid;grid-template-columns:1fr 1fr;gap:16px}}@media (max-width:720px){{.pair{{grid-template-columns:1fr}}}}.pair .scroll{{height:760px}}
a:focus-visible,select:focus-visible{{outline:2px solid var(--accent);outline-offset:3px}}
</style>
<div class="wrap">
<header class="mast"><p class="eyebrow">Landing prototype · <span class="it">{len(variants)} seeds, {len(variants)} directions</span></p><h1>{len(variants)} random strings, {len(variants)} landing pages.</h1><nav class="chips" aria-label="Variants">{chips}</nav></header>
<section class="matrix"><h2>At a glance</h2><div class="tablewrap"><table><thead><tr><th>Variant</th><th>Seed fingerprint</th><th>Type</th><th>Signature device</th><th>Best fit</th></tr></thead><tbody>{matrix}</tbody></table></div></section>
{''.join(dossier(base, v) for v in variants)}
<section class="sbs"><h2>Side by side</h2><div class="picker"><label>Left <select id="selA">{options}</select></label><label>Right <select id="selB">{options}</select></label></div>
<div class="pair"><figure class="frame"><figcaption id="capA">—</figcaption><div class="scroll"><img id="imgA" alt="left"></div></figure><figure class="frame"><figcaption id="capB">—</figcaption><div class="scroll"><img id="imgB" alt="right"></div></figure></div></section>
</div>
<script>
(function(){{var imgs={{{imgs}}};var names={{{names}}};var a=document.getElementById("selA"),b=document.getElementById("selB");
function paint(s,i,c){{i.src=imgs[s.value]||"";c.textContent=names[s.value]}}
function sync(){{paint(a,document.getElementById("imgA"),document.getElementById("capA"));paint(b,document.getElementById("imgB"),document.getElementById("capB"))}}
a.value="{first}";b.value="{second}";a.addEventListener("change",sync);b.addEventListener("change",sync);sync()}})();
</script>""")


if __name__ == "__main__":
    main()
