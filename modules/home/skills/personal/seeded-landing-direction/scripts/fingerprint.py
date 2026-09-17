#!/usr/bin/env python3
"""Fingerprint a random alphanumeric seed and decide the landing register.

Usage: python3 fingerprint.py seed.txt > fingerprint.json

Every decision is mechanical so that two runs on the same seed agree.
The scoring lives in `score_registers`; the feature-to-choice rules live in
`decide`. Keep both in step with references/decisions.md.
"""

from __future__ import annotations

import collections
import json
import re
import sys

ELEMENTS = set(
    "H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se "
    "Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy "
    "Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu".split()
)

MOTIF_DEVICE = {
    "V": "diagonal seam and chevron dividers",
    "A": "monumental wide-tracked caps",
    "M": "monumental wide-tracked caps",
    "W": "zigzag stagger of cards",
    "O": "ring masks and ping rings",
    "Q": "ring masks and ping rings",
    "I": "vertical rules and sideways labels",
    "L": "vertical rules and sideways labels",
    "T": "vertical rules and sideways labels",
    "X": "crossing hairlines and a diagonal grid",
    "S": "ribbon marquee",
    "Z": "zigzag stagger of cards",
    "K": "angular bracket frames",
    "N": "diagonal seam and chevron dividers",
    "H": "ladder grid with rung hairlines",
    "E": "ladder grid with rung hairlines",
}


def largest_divisor_up_to(n: int, cap: int) -> int:
    for d in range(cap, 0, -1):
        if n % d == 0:
            return d
    return 1


def fingerprint(seed: str) -> dict:
    n = len(seed)
    digit_pos = [i for i, c in enumerate(seed) if c.isdigit()]
    digits = "".join(seed[i] for i in digit_pos)
    zeros = [i for i in digit_pos if seed[i] == "0"]
    upper = sum(c.isupper() for c in seed)
    lower = sum(c.islower() for c in seed)
    letters = [(i, c) for i, c in enumerate(seed) if c.isalpha()]
    flips = sum(
        1
        for (i, a), (j, b) in zip(letters, letters[1:])
        if j == i + 1 and a.isupper() != b.isupper()
    )
    runs = re.findall(r"[A-Z]+|[a-z]+|[0-9]+", seed)
    upper_counts = collections.Counter(c for c in seed if c.isupper())
    top_upper = upper_counts.most_common(1)[0] if upper_counts else ("", 0)
    top_chars = collections.Counter(c for c in seed if c.isalpha()).most_common(3)
    bigrams = [seed[i : i + 2] for i in range(n - 1)]
    doubled = [b for b in bigrams if b[0] == b[1]]
    repeated = [b for b, c in collections.Counter(bigrams).items() if c > 1]
    elements = [b for b in bigrams if b in ELEMENTS]
    palindromes = [seed[i : i + 3] for i in range(n - 2) if seed[i] == seed[i + 2] != seed[i + 1]]
    dd = [int(c) for c in digits]
    ascending = [digits[i : i + 3] for i in range(len(dd) - 2) if dd[i] + 1 == dd[i + 1] == dd[i + 2] - 1]
    descending = [digits[i : i + 3] for i in range(len(dd) - 2) if dd[i] - 1 == dd[i + 1] == dd[i + 2] + 1]
    hex6 = re.findall(r"(?=([0-9a-fA-F]{6}))", seed)
    digit_palindromes = [digits[i : i + 3] for i in range(len(dd) - 2) if digits[i] == digits[i + 2]]
    columns = largest_divisor_up_to(n, 12)
    cls = lambda c: "digit" if c.isdigit() else ("upper" if c.isupper() else "lower")
    return {
        "seed": seed,
        "length": n,
        "grid": {"columns": columns, "unit_px": n // columns, "rhythm_px": n},
        "digits": digits,
        "digit_count": len(digit_pos),
        "digit_share_pct": round(100 * len(digit_pos) / n, 1),
        "digit_positions": digit_pos,
        "digit_sum": sum(dd),
        "digit_palindromes": digit_palindromes,
        "ascending_runs": ascending,
        "descending_runs": descending,
        "zeros": zeros,
        "zero_fractions": [round(i / n, 2) for i in zeros],
        "upper": upper,
        "lower": lower,
        "case_delta": upper - lower,
        "case_flips": flips,
        "run_count": len(runs),
        "longest_upper_run": max((r for r in runs if r.isupper()), key=len, default=""),
        "longest_lower_run": max((r for r in runs if r.islower()), key=len, default=""),
        "top_chars": top_chars,
        "motif_letter": top_upper[0] if top_upper[1] >= 5 else "",
        "motif_count": top_upper[1],
        "doubled": doubled,
        "repeated_bigrams": repeated,
        "element_symbols": elements,
        "palindromes": palindromes,
        "hex6": hex6,
        "vowels": sum(c.lower() in "aeiou" for c in seed),
        "first_char": cls(seed[0]),
        "last_char": cls(seed[-1]),
    }


def score_registers(f: dict) -> dict:
    s = {"specimen": 0, "poster": 0, "ledger": 0, "folio": 0, "atlas": 0}
    share = f["digit_share_pct"]
    if share >= 20:
        s["ledger"] += 3
    if f["ascending_runs"] or f["descending_runs"]:
        s["ledger"] += 1
    if f["case_flips"] <= 30:
        s["ledger"] += 1
    if f["motif_letter"]:
        s["poster"] += 3
    if f["case_flips"] >= 40:
        s["poster"] += 1
    if abs(f["case_delta"]) <= 2:
        s["poster"] += 1
    if f["palindromes"]:
        s["poster"] += 1
    if len(f["doubled"]) >= 3:
        s["folio"] += 3
    if not f["element_symbols"]:
        s["folio"] += 1
    if len(f["zeros"]) >= 3:
        s["folio"] += 1
    if f["vowels"] >= 17:
        s["folio"] += 1
    if len(f["element_symbols"]) >= 3:
        s["specimen"] += 3
    if f["digit_palindromes"]:
        s["specimen"] += 1
    if 12 <= share < 20:
        s["specimen"] += 1
    if f["zero_fractions"] and f["zero_fractions"][0] <= 0.4:
        s["atlas"] += 2
    if f["motif_letter"] and f["motif_letter"] in "AMWHN":
        s["atlas"] += 2
    d = f["digits"]
    if len(d) >= 4 and (d[0] == d[2] or d[2] == d[3]):
        s["atlas"] += 1
    return s


TIE_ORDER = ["poster", "folio", "ledger", "atlas", "specimen"]


def decide(f: dict) -> dict:
    scores = score_registers(f)
    best = max(scores.values())
    register = next(r for r in TIE_ORDER if scores[r] == best)
    delta = f["case_delta"]
    hero_split = "6/6" if abs(delta) <= 2 else ("7/5 type-led" if delta > 0 else "5/7 image-led")
    flips = f["case_flips"]
    motion = "kinetic" if flips >= 40 else ("standard" if flips >= 30 else "still")
    zf = [z for z in f["zero_fractions"] if z >= 0.5] if register != "atlas" else f["zero_fractions"]
    merged: list[float] = []
    for z in zf:
        if merged and z - merged[-1] < 0.05:
            continue
        merged.append(z)
    dark_bands = merged[:2]
    if register == "atlas" and dark_bands:
        dark_bands = [dark_bands[0]]
    if register == "ledger":
        dark_bands = []
    motif = f["motif_letter"]
    device = MOTIF_DEVICE.get(motif, "hairline ruler of the seed's digits at their positions")
    opening = {"lower": "eyebrow-first, quiet", "upper": "headline-first, loud", "digit": "numeral-first"}[f["first_char"]]
    ending = "footer ends on figures" if f["last_char"] == "digit" else "footer ends on words"
    return {
        "register": register,
        "scores": scores,
        "grid": f["grid"],
        "hero_split": hero_split,
        "motion_budget": motion,
        "dark_bands_at_page_fraction": dark_bands,
        "motif_letter": motif,
        "signature_device": device,
        "mirrored_chapters": bool(f["palindromes"]),
        "numbered_ledgers": bool(f["ascending_runs"] or f["descending_runs"]) or f["digit_share_pct"] >= 20,
        "opening": opening,
        "ending": ending,
        "accent_candidate_hex": (f["hex6"][0] if f["hex6"] else ""),
    }


def findings(f: dict, d: dict) -> list[dict]:
    out = [
        {"fact": f"length {f['length']} = {f['grid']['columns']} × {f['grid']['unit_px']}", "decision": f"{f['grid']['columns']}-column grid, {f['grid']['unit_px']}px unit, {f['grid']['rhythm_px']}px rhythm"},
        {"fact": f"{f['digit_count']} digits ({f['digit_share_pct']}%), sum {f['digit_sum']}: {f['digits']}", "decision": "ledger presentation" if d["numbered_ledgers"] else "chapter ordinals only"},
        {"fact": f"{f['upper']} upper / {f['lower']} lower, {f['case_flips']} case flips", "decision": f"hero split {d['hero_split']}, motion {d['motion_budget']}"},
        {"fact": f"zeros at {f['zeros']} (fractions {f['zero_fractions']})", "decision": f"dark bands at {d['dark_bands_at_page_fraction'] or 'none (light finale)'}"},
    ]
    if f["motif_letter"]:
        out.append({"fact": f"{f['motif_letter']} ×{f['motif_count']} is the top uppercase letter", "decision": d["signature_device"]})
    if f["element_symbols"]:
        out.append({"fact": f"element symbols {f['element_symbols']}", "decision": "specimen motif: code, symbol, Latin, assay"})
    if f["doubled"]:
        out.append({"fact": f"doubled letters {f['doubled']}", "decision": "diptych columns"})
    if f["palindromes"]:
        out.append({"fact": f"palindromes {f['palindromes']}", "decision": "mirrored chapters"})
    if f["hex6"]:
        out.append({"fact": f"hex colour {f['hex6'][0]} inside the seed", "decision": "map to the nearest brand token; use as the one highlight"})
    return out[:6]


def main() -> None:
    path = sys.argv[1] if len(sys.argv) > 1 else "seed.txt"
    seed = open(path, encoding="utf-8").read().strip()
    if not re.fullmatch(r"[A-Za-z0-9]{8,}", seed):
        sys.exit("seed must be alphanumeric, at least 8 characters")
    f = fingerprint(seed)
    d = decide(f)
    print(json.dumps({"fingerprint": f, "decisions": d, "findings": findings(f, d)}, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
