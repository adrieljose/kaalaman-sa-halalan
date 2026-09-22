# -*- coding: utf-8 -*-
"""Imports an authored chapter question bank into data/questions/questions.json.

    python tools/questions/import_chapter_bank.py <markdown> --chapter N [--write]

Without --write it validates and reports only, which is the default because
this REPLACES the chapter's existing entries rather than adding to them.

This is the generalised successor to import_chapter3_bank.py. Four conversions
matter, and each is a place the bank can silently break:

  THE BLANK.  The markdown writes the puzzle as it appears on screen --
  "**P _ _ _ I _ _ E**". The bank does not store that: QuestionBank keeps a
  plain prompt with "___" and the battle screen builds the letter mask from the
  answer at run time (_revealed_indices). Storing the mask would double-mask it.

  THE SPELLING.  Answers are spelled from board tiles, so they must be one run
  of A-Z, 3 to 24 letters (QuestionBank._is_spellable). Anything else is
  dropped SILENTLY at load with only a push_warning, so it is caught here
  instead. Multi-word answers are concatenated -- VICEPRESIDENT -- and carry a
  `display` string for how a human reads them, exactly as chapter 1 does with
  PUNONGBARANGAY / "PUNONG BARANGAY".

  THE NUMERALS.  A year is not spellable. Chapter 1 already set the house rule
  with EIGHTEEN / display "18": the answer is spelled the way the number is
  SAID, and the numeral is what the player is shown afterwards. YEARS applies
  that to the six dated questions in chapter 4.

  THE CATEGORY.  The reviewer filters by voting / fraud / candidate / why. The
  markdown carries no categories, so they are inferred here from the answer and
  the prompt. That inference is a judgement call, not data from the author, so
  every assignment can be printed with --show-categories.

FACTS are not invented. The source documents carry none, and writing legal or
civic claims to fill the field would put unreviewed statements in front of
students. Where the chapter's CURRENT bank already has a reviewed `fact` for
the very same answer, that fact is carried across rather than thrown away.
"""
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BANK = os.path.join(ROOT, "data", "questions", "questions.json")
MIN_LEN, MAX_LEN = 3, 24

# The battle screen's own mask maths, copied from word_battle_controller.gd so
# collisions are found here rather than by a player seeing two questions render
# as the same row of letters.
HINT_REVEAL = {"easy": 0.5, "medium": 0.34, "hard": 0.25}
MIN_HIDDEN = 2

# A numeral cannot be spelled from the board. Spell it the way it is SAID and
# show the numeral back -- the EIGHTEEN / "18" rule from chapter 1.
YEARS = {
    "1802": "EIGHTEENOHTWO",
    "1825": "EIGHTEENTWENTYFIVE",
    "1847": "EIGHTEENFORTYSEVEN",
    "1863": "EIGHTEENSIXTYTHREE",
    "1939": "NINETEENTHIRTYNINE",
    "1998": "NINETEENNINETYEIGHT",
}

# How a concatenated answer should READ. Everything not listed displays as
# itself, so single words need no entry.
DISPLAY = {
    # --- chapter 4, Malacanang ---
    "SANMIGUEL": "SAN MIGUEL",
    "VICEPRESIDENT": "VICE PRESIDENT",
    "SIXYEARS": "SIX YEARS",
    "NATURALBORN": "NATURAL-BORN",
    "TENYEARS": "TEN YEARS",
    "JPLAUREL": "J.P. LAUREL",
    "GOVERNORGENERAL": "GOVERNOR-GENERAL",
    "EXECUTIVEBUILDING": "EXECUTIVE BUILDING",
    "NATIONALLANDMARK": "NATIONAL LANDMARK",
    "OFFICEOFPRESIDENT": "OFFICE OF THE PRESIDENT",
    "EXECUTIVEPOWER": "EXECUTIVE POWER",
    "COMMANDERINCHIEF": "COMMANDER-IN-CHIEF",
    "ARMEDFORCES": "ARMED FORCES",
    "DIRECTVOTE": "DIRECT VOTE",
    "PRESIDENTELECT": "PRESIDENT-ELECT",
    "ACTINGPRESIDENT": "ACTING PRESIDENT",
    "EXECUTIVEORDER": "EXECUTIVE ORDER",
    "ARTICLEVII": "ARTICLE VII",
    "ENBANC": "EN BANC",
    "ELECTIONRETURNS": "ELECTION RETURNS",
    "JOINTSESSION": "JOINT SESSION",
    "VICEPRESIDENTELECT": "VICE-PRESIDENT-ELECT",
    "SENATEPRESIDENT": "SENATE PRESIDENT",
    "SPECIALELECTION": "SPECIAL ELECTION",
    "SEVENDAYS": "SEVEN DAYS",
    "FORTYFIVEDAYS": "FORTY-FIVE DAYS",
    "SIXTYDAYS": "SIXTY DAYS",
    "EIGHTEENMONTHS": "EIGHTEEN MONTHS",
    "CABINETMAJORITY": "CABINET MAJORITY",
    "FIVEDAYS": "FIVE DAYS",
    "FORTYEIGHTHOURS": "FORTY-EIGHT HOURS",
    "TWOTHIRDS": "TWO-THIRDS",
    "SERIOUSILLNESS": "SERIOUS ILLNESS",
    "CONFLICTOFINTEREST": "CONFLICT OF INTEREST",
    "FOURTHDEGREE": "FOURTH DEGREE",
    "NINETYDAYS": "NINETY DAYS",
    "APPOINTMENTBAN": "APPOINTMENT BAN",
    "COMMISSIONONAPPOINTMENTS": "COMMISSION ON APPOINTMENTS",
    "RECESSAPPOINTMENTS": "RECESS APPOINTMENTS",
    "FAITHFULEXECUTION": "FAITHFUL EXECUTION",
    "LAWLESSVIOLENCE": "LAWLESS VIOLENCE",
    "MARTIALLAW": "MARTIAL LAW",
    "HABEASCORPUS": "HABEAS CORPUS",
    "TWENTYFOURHOURS": "TWENTY-FOUR HOURS",
    "THREEDAYS": "THREE DAYS",
    "FINALJUDGMENT": "FINAL JUDGMENT",
    "MONETARYBOARD": "MONETARY BOARD",
    "FOREIGNLOANS": "FOREIGN LOANS",
    "INTERNATIONALAGREEMENT": "INTERNATIONAL AGREEMENT",
    "BUDGETSUBMISSION": "BUDGET SUBMISSION",
    "REGULARSESSION": "REGULAR SESSION",
    "STATEOFNATION": "STATE OF THE NATION",
    "OFFICIALRESIDENCE": "OFFICIAL RESIDENCE",
    "PRESIDENTIALCONTEST": "PRESIDENTIAL CONTEST",
    "UNEXPIREDTERM": "UNEXPIRED TERM",
    "NATIONALSECURITY": "NATIONAL SECURITY",
    "FOREIGNRELATIONS": "FOREIGN RELATIONS",
    # --- chapter 5, Congress ---
    "TWENTYFOUR": "TWENTY-FOUR",
    "THIRTYFIVE": "THIRTY-FIVE",
    "TWENTYFIVE": "TWENTY-FIVE",
    "THREEYEARS": "THREE YEARS",
    "ATLARGE": "AT LARGE",
    "PARTYLIST": "PARTY-LIST",
    "FIRSTREADING": "FIRST READING",
    "SECONDREADING": "SECOND READING",
    "THIRDREADING": "THIRD READING",
    "MAJORITYLEADER": "MAJORITY LEADER",
    "MINORITYLEADER": "MINORITY LEADER",
    "LEGISLATIONINQUIRY": "LEGISLATION (IN AID OF)",
    "SENATEAMENDMENTS": "SENATE AMENDMENTS",
    "TWENTYPERCENT": "TWENTY PERCENT",
    "TWOCONSECUTIVE": "TWO CONSECUTIVE",
    "THREECONSECUTIVE": "THREE CONSECUTIVE",
    "TWOYEARS": "TWO YEARS",
    "ONEYEAR": "ONE YEAR",
    "TWOHUNDREDFIFTYTHOUSAND": "250,000",
    "CHIEFJUSTICE": "CHIEF JUSTICE",
    "TWOTHIRDSCONVICTION": "TWO-THIRDS (CONVICTION)",
    "YEASNAYS": "YEAS AND NAYS",
    "TWOTHIRDSMEMBERS": "TWO-THIRDS OF MEMBERS",
    "JOURNALRECORD": "JOURNAL RECORD",
    "NINEMEMBERS": "NINE MEMBERS",
    "THREEJUSTICES": "THREE JUSTICES",
    "SIXLEGISLATORS": "SIX LEGISLATORS",
    "TWELVESENATORS": "TWELVE SENATORS",
    "TWELVEREPRESENTATIVES": "TWELVE REPRESENTATIVES",
    "THIRTYSESSIONDAYS": "THIRTY SESSION DAYS",
    "ALLMEMBERS": "ALL MEMBERS",
    "SIXYEARSIMPRISONMENT": "SIX YEARS OF IMPRISONMENT",
    "TRIBUNALBODY": "TRIBUNAL",
    "LEGISLATIONCONFLICT": "LEGISLATION (CONFLICT)",
    "SEATFORFEITURE": "SEAT FORFEITURE",
    "TERMRESTRICTION": "TERM RESTRICTION",
    "THREEDAYSBEFORE": "THREE DAYS BEFORE",
    "SEPARATEDAYS": "SEPARATE DAYS",
    "AMENDMENTFINAL": "AMENDMENT (NO FURTHER)",
    "CONGRESSIONALJOURNAL": "CONGRESSIONAL JOURNAL",
    "THIRTYDAYS": "THIRTY DAYS",
    "TARIFFBILL": "TARIFF BILL",
    "REENACTMENT": "RE-ENACTMENT",
    "APPROPRIATIONITEM": "APPROPRIATION ITEM",
    "ALLCONGRESSMEMBERS": "ALL MEMBERS OF CONGRESS",
    "TWOTHIRDSWAR": "TWO-THIRDS (WAR)",
    "RESOLUTIONREVOCATION": "RESOLUTION (REVOCATION)",
}

# A fact is carried across when the SAME answer recurs, but an answer can be
# the same word about a different thing, and then the old fact is simply wrong
# in its new place. These two were checked by eye and rejected:
#   ch4 VOTERS  -- the old fact is about the RA 7166 spending cap, not voters.
#   ch5 SIX     -- the old fact is about six-year Senate terms; the new
#                  question asks which ARTICLE of the Constitution covers
#                  Congress. Same word, different six.
# Every carried fact is printed on import, so this list is meant to grow when
# a future chapter turns one up.
FACT_BLOCK = {(4, "VOTERS"), (5, "SIX")}

# --- category inference -------------------------------------------------
# Checked in this order: the answer lists first, then prompt keywords, then
# "why" as the fallback. Answers match whole; keywords match as substrings of
# the lowercased prompt.
CANDIDATE_ANSWERS = {
    "FORTY", "SIXYEARS", "NATURALBORN", "REGISTERED", "TENYEARS", "TERM",
    "READ", "WRITE", "CITIZEN", "QUALIFICATIONS", "REELECTION", "OATH",
    "AFFIRMATION", "JUNE", "NOON", "THIRTIETH", "PRESIDENTELECT",
    "VICEPRESIDENTELECT", "UNEXPIREDTERM", "THIRTYFIVE", "TWENTYFIVE",
    "THREEYEARS", "TWOCONSECUTIVE", "THREECONSECUTIVE", "TWOYEARS", "ONEYEAR",
    "SEATFORFEITURE", "TERMRESTRICTION", "EXPIRED",
}
VOTING_ANSWERS = {
    "ELECTION", "VOTERS", "MAY", "DIRECTVOTE", "MAJORITY", "CANVASS",
    "CERTIFICATES", "JOINTSESSION", "TIE", "SPECIALELECTION", "SEVENDAYS",
    "FORTYFIVEDAYS", "SIXTYDAYS", "EIGHTEENMONTHS", "SUCCESSION", "VACANCY",
    "TWOTHIRDS", "ELECTIONRETURNS", "PRESIDENTIALCONTEST", "ENBANC",
    "SENATEPRESIDENT", "SPEAKER", "ACTINGPRESIDENT", "VETO", "OVERRIDE",
    "QUORUM", "VOTE", "AYE", "NAY", "ATLARGE", "DISTRICTS", "PARTYLIST",
    "TWENTYPERCENT", "CENSUS", "REAPPORTIONMENT", "TRIBUNAL", "HRET",
    "YEASNAYS", "TWOTHIRDSMEMBERS", "TWOTHIRDSCONVICTION", "ABSENT",
    "NINEMEMBERS", "THREEJUSTICES", "SIXLEGISLATORS", "TWELVESENATORS",
    "TWELVEREPRESENTATIVES", "ALLMEMBERS", "TWOTHIRDSWAR", "ORIGIN",
    "CONSTITUENCY", "TWOHUNDREDFIFTYTHOUSAND", "SEAT", "REPRESENTATION",
    "IMPEACHMENT", "TRY",
}
FRAUD_ANSWERS = {
    "EMOLUMENT", "CONFLICTOFINTEREST", "FOURTHDEGREE", "APPOINTMENTBAN",
    "RECESSAPPOINTMENTS", "NINETYDAYS", "FAITHFULEXECUTION", "RECORDS",
    "SECURITY", "DOCUMENTS", "BUDGET", "FOREIGNLOANS", "MONETARYBOARD",
    "BUDGETSUBMISSION", "CONTRACT", "BENEFIT", "INTERESTS",
    "LEGISLATIONCONFLICT", "SAVINGS", "REENACTMENT", "VOUCHERS", "PUBLIC",
    "OPERATIONS", "APPROPRIATIONITEM", "PURPOSE", "PROPOSAL",
    "ALLCONGRESSMEMBERS", "SUSPENSION", "EXPULSION", "BEHAVIOR", "NOBILITY",
    "PUBLICATION", "APPROPRIATIONS", "APPROPRIATION", "REVENUE", "TARIFF",
    "TARIFFBILL", "THIRTYDAYS", "SIXYEARSIMPRISONMENT", "TRIBUNALBODY",
}
# Substrings, so they have to be chosen so they cannot appear inside an
# unrelated word: "residen" was matching PRESIDENT in a third of the chapter
# and filed the whole executive branch under "candidate".
CANDIDATE_WORDS = ("must be at least", "qualification", "residency",
                   "must have lived", "is eligible", "consecutive regular terms",
                   "takes an oath")
VOTING_WORDS = ("elect", "vote", "ballot", "canvass", "quorum", "majority",
                "two-thirds", "succe", "vacanc", "veto", "reading")
FRAUD_WORDS = ("audit", "conflict", "disclose", "disclosure", "financial",
               "appropriat", "spending", "funds", "budget", "emolument",
               "forfeit", "prohibit", "may not", "cannot be appointed")


# Answers the keyword rules file wrongly because an unrelated trigger word sits
# in the prompt. REGULARSESSION is about the parliamentary calendar, but its
# prompt mentions the budget.
WHY_ANSWERS = {"REGULARSESSION", "COMMISSIONONAPPOINTMENTS"}


def category_for(answer, prompt):
    if answer in WHY_ANSWERS:
        return "why"
    if answer in CANDIDATE_ANSWERS:
        return "candidate"
    if answer in VOTING_ANSWERS:
        return "voting"
    if answer in FRAUD_ANSWERS:
        return "fraud"
    low = prompt.lower()
    if any(w in low for w in CANDIDATE_WORDS):
        return "candidate"
    if any(w in low for w in FRAUD_WORDS):
        return "fraud"
    if any(w in low for w in VOTING_WORDS):
        return "voting"
    return "why"


def strip_mask(prompt):
    """Replaces the on-screen letter mask with the bank's plain blank.

    The mask is a bolded run of single letters/digits and underscores. Matching
    that shape rather than "anything bold" leaves ordinary bold emphasis alone.
    """
    out = re.sub(r"\*\*[A-Z0-9][A-Z0-9 _]*\*\*", "___", prompt)
    return re.sub(r"\s+", " ", out).strip()


def revealed_indices(length, difficulty):
    """word_battle_controller._revealed_indices, in Python."""
    share = HINT_REVEAL.get(difficulty, 0.34)
    count = int(math.ceil(length * share))
    count = max(1, min(count, length - MIN_HIDDEN))
    out = [False] * length
    if count <= 1:
        out[0] = True
        return out
    for i in range(count):
        out[int(round(float(i) * (length - 1) / float(count - 1)))] = True
    return out


def rendered_mask(answer, difficulty):
    show = revealed_indices(len(answer), difficulty)
    return " ".join(answer[i] if show[i] else "_" for i in range(len(answer)))


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
            ans = re.match(r"^\s*-\s*\*\*Answer:\*\*\s*([A-Za-z0-9]+)\s*$", line)
            if ans and pending:
                rows.append({
                    "difficulty": difficulty,
                    "prompt_raw": pending,
                    "raw_answer": ans.group(1).strip().upper(),
                })
                pending = None
    return rows


def main():
    if len(sys.argv) < 2 or "--chapter" not in sys.argv:
        print(__doc__)
        raise SystemExit(2)
    src = sys.argv[1]
    chapter = int(sys.argv[sys.argv.index("--chapter") + 1])
    write = "--write" in sys.argv

    bank = json.load(open(BANK, encoding="utf-8"))
    # Reviewed facts already in this chapter, kept where the same answer recurs.
    inherited = {}
    for q in bank:
        if int(q.get("chapter", 1)) == chapter and q.get("fact"):
            inherited.setdefault(q["answer"], q["fact"])

    rows = parse(src)
    print("parsed %d questions from %s" % (len(rows), os.path.basename(src)))

    faults = []
    counts = {"easy": 0, "medium": 0, "hard": 0}
    built = []
    spelled_numerals = []
    kept_facts = []
    for i, r in enumerate(rows, 1):
        counts[r["difficulty"]] = counts.get(r["difficulty"], 0) + 1
        raw = r["raw_answer"]
        a = raw
        if not raw.isalpha():
            if raw in YEARS:
                a = YEARS[raw]
                spelled_numerals.append((i, raw, a))
            else:
                faults.append("#%d answer %r cannot be spelled from board tiles "
                              "and has no spelled form in YEARS" % (i, raw))
                continue

        if not (MIN_LEN <= len(a) <= MAX_LEN) or not a.isalpha():
            faults.append("#%d %s is not spellable (%d letters)" % (i, a, len(a)))
        prompt = strip_mask(r["prompt_raw"])
        if "___" not in prompt:
            faults.append("#%d has no blank after mask stripping: %s" % (i, prompt[:60]))
        if "**" in prompt:
            faults.append("#%d still carries markup: %s" % (i, prompt[:60]))

        entry = {
            "chapter": chapter,
            "difficulty": r["difficulty"],
            "category": category_for(a, prompt),
            "prompt": prompt,
            "answer": a,
        }
        display = DISPLAY.get(a)
        if raw != a:
            display = raw               # a year displays as its numerals
        if display and display != a:
            entry["display"] = display
        if a in inherited and (chapter, a) not in FACT_BLOCK:
            entry["fact"] = inherited[a]
            kept_facts.append(a)
        built.append(entry)

    print("  easy %d  medium %d  hard %d" % (counts["easy"], counts["medium"], counts["hard"]))

    if spelled_numerals:
        print("\nnumerals spelled for the board (shown back as the numeral):")
        for i, raw, a in spelled_numerals:
            print("   #%-3d %-6s -> %s" % (i, raw, a))

    if kept_facts:
        print("\ncarried %d reviewed facts across from the current chapter-%d bank:"
              % (len(kept_facts), chapter))
        print("   %s" % ", ".join(sorted(set(kept_facts))))

    # Answers that RENDER as the same row of letters at the same difficulty are
    # the same puzzle on screen, whatever the prompt says.
    seen = {}
    for e in built:
        key = (e["difficulty"], rendered_mask(e["answer"], e["difficulty"]))
        seen.setdefault(key, []).append(e["answer"])
    clash = {k: v for k, v in seen.items() if len(set(v)) > 1}
    print("\nrendered-mask collisions: %d" % len(clash))
    for (d, mask), answers in sorted(clash.items()):
        print("   [%s] %s  <-  %s" % (d, mask, ", ".join(sorted(set(answers)))))

    repeats = {}
    for e in built:
        repeats.setdefault(e["answer"], 0)
        repeats[e["answer"]] += 1
    dupes = {k: v for k, v in repeats.items() if v > 1}
    if dupes:
        print("\nrepeated answers (allowed, different prompts): %s" % dupes)

    by_cat = {}
    for e in built:
        by_cat[e["category"]] = by_cat.get(e["category"], 0) + 1
    print("\ninferred categories: %s" % by_cat)
    if "--show-categories" in sys.argv:
        for e in built:
            print("   %-9s %-10s %s" % (e["difficulty"], e["category"], e["answer"]))

    longest = sorted(built, key=lambda e: -len(e["answer"]))[:5]
    print("\nlongest answers (the board holds 36 tiles): %s"
          % ", ".join("%s(%d)" % (e["answer"], len(e["answer"])) for e in longest))

    if faults:
        print("\nFAULTS:")
        for f in faults:
            print("   %s" % f)
        raise SystemExit(1)

    if not write:
        print("\nvalidation only. Re-run with --write to replace chapter %d." % chapter)
        return

    kept = [q for q in bank if int(q.get("chapter", 1)) != chapter]
    dropped = len(bank) - len(kept)
    out = kept + built
    with open(BANK, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("\nreplaced %d chapter-%d questions with %d; bank is now %d"
          % (dropped, chapter, len(built), len(out)))


if __name__ == "__main__":
    main()
