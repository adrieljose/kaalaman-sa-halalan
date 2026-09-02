"""Parses the Chapter 2 markdown drop into the shape questions.json wants.

The markdown hand-masks each answer inside the sentence ("**C___ H__L**"),
but the game builds that mask itself at runtime from the chosen difficulty
(_format_prompt / _revealed_indices in word_battle_controller.gd). Keeping the
author's mask would mask an already-masked word, so the mask is thrown away
and replaced with the engine's BLANK_TOKEN, "___".
"""
import json
import re
import sys
from pathlib import Path

SRC = Path(sys.argv[1] if len(sys.argv) > 1
           else r"C:\Users\Asus\Downloads\chapter_2_city_hall_questions_150.md")

TIER_RE = re.compile(r"^#\s+(EASY|MEDIUM|HARD)\b", re.I)
Q_RE = re.compile(r"^###\s+\d+\.\s+(.*)$")
A_RE = re.compile(r"^\*\*Answer:\*\*\s*\*\*(.+?)\*\*\s*$")
BOLD_RE = re.compile(r"\*\*(.+?)\*\*")


def main() -> None:
    tier = None
    out = []
    pending = None
    for line in SRC.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        m = TIER_RE.match(line)
        if m:
            tier = m.group(1).lower()
            continue
        m = Q_RE.match(line)
        if m:
            pending = m.group(1)
            continue
        m = A_RE.match(line)
        if m and pending is not None:
            display = " ".join(m.group(1).split()).upper()
            # The bold run in the sentence is the mask; swap it for the token.
            prompt = BOLD_RE.sub("___", pending, count=1)
            out.append({
                "tier": tier,
                "prompt": prompt,
                "display": display,
                "answer": re.sub(r"[^A-Z]", "", display),
            })
            pending = None
    Path("tools/questions/ch2_parsed.json").write_text(
        json.dumps(out, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"parsed {len(out)}")
    for t in ("easy", "medium", "hard"):
        print(f"  {t}: {sum(1 for e in out if e['tier'] == t)}")

    print("\n-- prompts still carrying a mask or missing the token --")
    for e in out:
        if "___" not in e["prompt"] or "**" in e["prompt"] or "_" in e["prompt"].replace("___", ""):
            print("  ", e["prompt"])

    print("\n-- answers over the 24-letter spellable cap --")
    for e in sorted(out, key=lambda e: -len(e["answer"])):
        if len(e["answer"]) > 24:
            print(f"   {len(e['answer']):>2}  {e['display']}")

    print("\n-- answers with characters that cannot be spelled --")
    for e in out:
        if re.sub(r"[A-Z ]", "", e["display"]):
            print("  ", e["display"])

    print("\n-- duplicate answers inside chapter 2 --")
    seen = {}
    for e in out:
        seen.setdefault(e["answer"], []).append(e["display"])
    for k, v in seen.items():
        if len(v) > 1:
            print("  ", k, v)

    print(f"\nlongest kept: {max(len(e['answer']) for e in out)}")


main()
