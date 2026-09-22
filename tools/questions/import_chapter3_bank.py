# -*- coding: utf-8 -*-
"""Imports the authored Chapter 3 question bank into data/questions/questions.json.

SUPERSEDED for new chapters by import_chapter_bank.py, which takes --chapter
and additionally handles numeral answers, carries reviewed facts across, and
finds mask collisions using the battle screen's real reveal maths. This file
is kept because its DISPLAY and category tables ARE the chapter 3 decisions.

    python tools/questions/import_chapter3_bank.py <markdown> [--write]

Without --write it validates and reports only, which is the default because
this REPLACES chapter 3's existing entries rather than adding to them.

Three conversions matter, and each is a place the bank can silently break:

  THE BLANK.  The markdown writes the puzzle as it appears on screen --
  "**P _ _ _ I _ _ E**". The bank does not store that: QuestionBank keeps a
  plain prompt with "___" and the battle screen builds the letter mask from the
  answer at run time. Storing the mask would double-mask it.

  THE SPELLING.  Answers are spelled from board tiles, so they must be one run
  of A-Z, 3 to 24 letters (QuestionBank._is_spellable). Multi-word answers are
  concatenated -- VICEGOVERNOR -- and carry a `display` string for how a human
  reads them, exactly as chapter 1 does with PUNONGBARANGAY / "PUNONG
  BARANGAY" and EIGHTEEN / "18".

  THE CATEGORY.  The reviewer filters by voting / fraud / candidate / why. The
  markdown carries no categories, so they are inferred here from the answer and
  prompt. That inference is a judgement call, not data from the author: it is
  printed per question so it can be checked.

No `fact` is written. Chapters 1 and 2 carry one per question, but the source
document has none, and inventing legal or civic facts to fill the field would
put unreviewed claims in front of students. The field is optional and defaults
to empty.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BANK = os.path.join(ROOT, "data", "questions", "questions.json")
CHAPTER = 3
MIN_LEN, MAX_LEN = 3, 24

# How a concatenated or numeric answer should READ. Everything not listed here
# displays as itself.
DISPLAY = {
    "VICEGOVERNOR": "VICE GOVERNOR",
    "TWENTYTHREE": "23",
    "THREEYEARS": "THREE YEARS",
    "ONEYEAR": "ONE YEAR",
    "ELECTIONDAY": "ELECTION DAY",
    "GENERALWELFARE": "GENERAL WELFARE",
    "QUASIJUDICIAL": "QUASI-JUDICIAL",
    "EXOFFICIO": "EX OFFICIO",
    "DEVELOPMENTPLAN": "DEVELOPMENT PLAN",
    "PROVINCIALCAPITAL": "PROVINCIAL CAPITAL",
    "COMPONENTCITY": "COMPONENT CITY",
    "HIGHLYURBANIZED": "HIGHLY URBANIZED",
    "CIVILSERVICE": "CIVIL SERVICE",
    "TWOTHIRDS": "TWO-THIRDS",
    "SEVENDAYS": "SEVEN DAYS",
    "FIFTEENDAYS": "FIFTEEN DAYS",
    "GENERALFUND": "GENERAL FUND",
}

# Category inference. First match wins, so the more specific sets come first.
CANDIDATE = {
    "CANDIDACY", "TWENTYTHREE", "THREEYEARS", "CONSECUTIVE", "RESIDENCY",
    "FILIPINO", "LITERACY", "REGISTERED", "ONEYEAR", "ELECTIONDAY", "TERM",
    "RENUNCIATION", "ELECTIVE", "APPOINTIVE", "APPOINTMENT", "CIVILSERVICE",
}
VOTING = {
    "VOTER", "ELECTION", "BALLOT", "COMELEC", "MAJORITY", "QUORUM",
    "SUCCESSION", "VACANCY", "RANKING", "PERMANENT", "TEMPORARY", "VETO",
    "OVERRIDE", "TWOTHIRDS", "CONFIRMATION", "AMEND", "REVIEW",
}
# Money, audit and the machinery that is supposed to keep it honest.
FRAUD = {
    "AUDIT", "PROCUREMENT", "BIDDING", "CONTRACT", "ACCOUNTABILITY",
    "TRANSPARENCY", "DISBURSEMENT", "EXPENDITURES", "COMPENSATION",
    "ALLOWANCES", "WARRANTS", "OBLIGATION", "RESPONSIBILITY", "COLLECTION",
    "INDEBTEDNESS", "BORROWING", "BUDGETARY", "EXEMPTION", "INCENTIVES",
}


def category_for(answer):
    if answer in CANDIDATE:
        return "candidate"
    if answer in VOTING:
        return "voting"
    if answer in FRAUD:
        return "fraud"
    return "why"


def strip_mask(prompt):
    """Replaces the on-screen letter mask with the bank's plain blank.

    The mask is a bolded run of single letters and underscores. Matching that
    shape rather than "anything bold" leaves ordinary bold emphasis alone.
    """
    out = re.sub(r"\*\*[A-Z][A-Z _]*\*\*", "___", prompt)
    return re.sub(r"\s+", " ", out).strip()


def parse(path):
    rows = []
    difficulty = None
    pending = None
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            head = re.match(r"^##\s+(Easy|Medium|Hard)\b", line, re.I)
            if head:
                difficulty = head.group(1).lower()
                continue
            item = re.match(r"^\s*\d+\.\s+(.*\S)\s*$", line)
            if item and difficulty:
                pending = item.group(1)
                continue
            ans = re.match(r"^\s*-\s*\*\*Answer:\*\*\s*([A-Za-z]+)\s*$", line)
            if ans and pending:
                rows.append({
                    "difficulty": difficulty,
                    "prompt_raw": pending,
                    "answer": ans.group(1).strip().upper(),
                })
                pending = None
    return rows


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(2)
    src = sys.argv[1]
    write = "--write" in sys.argv

    rows = parse(src)
    print("parsed %d questions from %s" % (len(rows), os.path.basename(src)))

    faults = []
    counts = {"easy": 0, "medium": 0, "hard": 0}
    seen = {}
    built = []
    for i, r in enumerate(rows, 1):
        a = r["answer"]
        counts[r["difficulty"]] = counts.get(r["difficulty"], 0) + 1

        if not (MIN_LEN <= len(a) <= MAX_LEN) or not a.isalpha():
            faults.append("#%d %s is not spellable on a 6x6 board (%d letters)"
                          % (i, a, len(a)))
        prompt = strip_mask(r["prompt_raw"])
        if "___" not in prompt:
            faults.append("#%d has no blank after mask stripping: %s" % (i, prompt[:60]))
        if "**" in prompt:
            faults.append("#%d still carries markup: %s" % (i, prompt[:60]))

        seen.setdefault(a, []).append((r["difficulty"], i))

        entry = {
            "chapter": CHAPTER,
            "difficulty": r["difficulty"],
            "category": category_for(a),
            "prompt": prompt,
            "answer": a,
        }
        if a in DISPLAY:
            entry["display"] = DISPLAY[a]
        built.append(entry)

    print("  easy %d  medium %d  hard %d" % (counts["easy"], counts["medium"], counts["hard"]))

    repeats = {a: v for a, v in seen.items() if len(v) > 1}
    if repeats:
        print("\nrepeated answers (allowed -- different prompts -- but worth a look):")
        for a, v in sorted(repeats.items()):
            print("   %-16s %s" % (a, ", ".join("%s#%d" % x for x in v)))

    # Answers that mask to the same pattern read as the same puzzle on screen.
    masks = {}
    for e in built:
        m = e["answer"][0] + "".join("_" for _ in e["answer"][1:])
        masks.setdefault((len(e["answer"]), e["answer"][0]), []).append(e["answer"])
    clash = {k: sorted(set(v)) for k, v in masks.items() if len(set(v)) > 1}
    if clash:
        print("\nsame length and first letter (the board looks alike, answers differ):")
        for k, v in sorted(clash.items()):
            print("   %2d letters, %s...  %s" % (k[0], k[1], ", ".join(v)))

    by_cat = {}
    for e in built:
        by_cat[e["category"]] = by_cat.get(e["category"], 0) + 1
    print("\ninferred categories: %s" % by_cat)

    if faults:
        print("\nFAULTS:")
        for f in faults:
            print("   %s" % f)
        raise SystemExit(1)

    if not write:
        print("\nvalidation only. Re-run with --write to replace chapter %d." % CHAPTER)
        return

    bank = json.load(open(BANK, encoding="utf-8"))
    kept = [q for q in bank if int(q.get("chapter", 1)) != CHAPTER]
    dropped = len(bank) - len(kept)
    out = kept + built
    with open(BANK, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("\nreplaced %d chapter-%d questions with %d; bank is now %d"
          % (dropped, CHAPTER, len(built), len(out)))


if __name__ == "__main__":
    main()
