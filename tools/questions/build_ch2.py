# -*- coding: utf-8 -*-
"""Folds the Chapter 2 markdown drop into data/questions/questions.json.

Chapter 2 held 60 entries that were really 30 answers phrased twice each. This
replaces the whole block with the 150 supplied questions, bringing chapter 2 to
the same shape chapter 1 already has: 50 easy / 50 medium / 50 hard, every
prompt and every answer distinct.

Two things the markdown could not know about are applied here:

REWRITES  Six answers ran past the 24-letter cap in QuestionBank._is_spellable,
          and one carried digits no tile can hold. Raising the cap was the
          wrong fix -- a 33-letter answer on a 36-tile board leaves three
          letters that are not part of it, which is not a puzzle. Instead the
          term's distinctive tail becomes the answer and the rest moves into
          the sentence, so the full term is still taught and still read.

FACTS     The bank shows a one-line fact after a correct answer; it is the
          teaching payload, and the markdown supplied none.
"""
import json
import re
from pathlib import Path

BANK = Path("data/questions/questions.json")
PARSED = Path("tools/questions/ch2_parsed.json")
CHAPTER = 2
MAX_LETTERS = 24  # must match QuestionBank._is_spellable

# original display -> (new display, new prompt)
REWRITES = {
    "REPUBLIC ACT 7160": (
        "REPUBLIC ACT",
        "The Local Government Code of 1991 is formally known as ___ 7160."),
    "EMERGENCY OPERATIONS CENTER": (
        "OPERATIONS CENTER",
        "The facility used to coordinate government response during major "
        "emergencies is the emergency ___."),
    "LOCAL PEACE AND ORDER COUNCIL": (
        "PEACE AND ORDER COUNCIL",
        "The body that brings police, barangays, and city officials together "
        "on community safety is the local ___."),
    "EXECUTIVE LEGISLATIVE AGENDA": (
        "LEGISLATIVE AGENDA",
        "The joint priority framework that aligns the mayor's plans with the "
        "council's lawmaking is the executive ___."),
    "LOCAL DEVELOPMENT INVESTMENT PROGRAM": (
        "INVESTMENT PROGRAM",
        "The multi-year document that translates local development priorities "
        "into funded programs and projects is the local development ___."),
    "CERTIFICATE OF AVAILABILITY OF FUNDS": (
        "AVAILABILITY OF FUNDS",
        "Before an expense is obligated, confirmation that sufficient funds "
        "exist is shown through a certificate of ___."),
    "ENVIRONMENTAL IMPACT ASSESSMENT": (
        "IMPACT ASSESSMENT",
        "A systematic study of the likely environmental effects of a proposed "
        "project is an environmental ___."),
}

# final display -> (category, fact). Categories follow the bank's four tags:
#   candidate = officials, offices and the people who hold them
#   voting    = the documents, payments and processes a resident goes through
#   fraud     = integrity, controls, and where money goes wrong
#   why       = the civic concepts and the reason any of it matters
FACTS = {
    # ---- EASY ----
    "CITY HALL": ("why", "City Hall houses the mayor's office, the city council, and the frontline service windows residents use."),
    "MAYOR": ("candidate", "A city mayor serves a three-year term and may hold no more than three consecutive terms."),
    "VICE MAYOR": ("candidate", "The vice mayor presides over the city council but votes only to break a tie."),
    "CITY COUNCIL": ("candidate", "A city's council is the Sangguniang Panlungsod, made up of elected councilors."),
    "ORDINANCE": ("voting", "An ordinance is a local law that carries penalties and stays in force until repealed."),
    "RESOLUTION": ("voting", "A resolution expresses the council's position on a matter; it is not a permanent local law."),
    "PERMIT": ("voting", "Permits let the city check that an activity meets safety, zoning, and health rules before it starts."),
    "LICENSE": ("voting", "Licenses are issued for a fixed period and must be renewed to stay valid."),
    "TREASURER": ("candidate", "The city treasurer collects local taxes and keeps custody of city funds."),
    "ASSESSOR": ("candidate", "The assessor appraises land and buildings so property tax rests on a recorded value."),
    "ACCOUNTANT": ("candidate", "The city accountant keeps the books and certifies that expenses are properly recorded."),
    "ENGINEER": ("candidate", "The city engineer reviews building plans and supervises public works projects."),
    "HEALTH OFFICE": ("candidate", "The city health office runs immunisation, sanitation, and other frontline health services."),
    "SOCIAL WELFARE": ("candidate", "Social welfare offices assist children, senior citizens, persons with disabilities, and families in crisis."),
    "CIVIL REGISTRY": ("voting", "Civil registry records are the legal proof of a person's birth, marriage, and death."),
    "BUSINESS PERMIT": ("voting", "Business permits are renewed every January, together with the local business tax."),
    "BUILDING PERMIT": ("voting", "A building permit is issued only after the plans are checked against the National Building Code."),
    "OCCUPANCY PERMIT": ("voting", "The occupancy permit certifies that the finished building is safe to be used."),
    "TAX DECLARATION": ("voting", "A tax declaration records a property's assessed value; it is not by itself proof of ownership."),
    "REAL PROPERTY TAX": ("voting", "Real property tax may be paid in full by January or in four quarterly instalments."),
    "COMMUNITY TAX": ("voting", "The community tax certificate, or cedula, is often required when signing official documents."),
    "RECEIPT": ("voting", "Always ask for a receipt: it is the only proof that a payment reached the city's funds."),
    "QUEUE NUMBER": ("voting", "Queue numbers keep service first-come, first-served, so no one can be quietly moved ahead."),
    "INFORMATION DESK": ("voting", "The information desk exists so no resident has to pay a fixer to find the right window."),
    "PUBLIC SERVICE": ("why", "Public office is a public trust: government workers are paid from the taxes residents pay."),
    "CITY SEAL": ("why", "The seal makes a city document official, and forging it is a criminal offence."),
    "SESSION HALL": ("why", "Council sessions held in the session hall are open to the public."),
    "MAYOR'S OFFICE": ("candidate", "The mayor's office signs permits, issues executive orders, and heads the city's executive branch."),
    "TREASURY OFFICE": ("voting", "Wherever you pay inside City Hall, the transaction should end with a treasury-issued official receipt."),
    "ASSESSOR'S OFFICE": ("voting", "The assessor's office keeps the tax map and the record of every taxable property in the city."),
    "ACCOUNTING OFFICE": ("voting", "The accounting office checks that every disbursement carries complete supporting documents."),
    "ENGINEERING OFFICE": ("voting", "The engineering office inspects city roads, drainage, and public buildings."),
    "LEGAL OFFICE": ("candidate", "The city legal office drafts contracts and defends the city in court."),
    "PLANNING OFFICE": ("candidate", "The planning office prepares the land use plan that guides where the city may grow."),
    "BUDGET OFFICE": ("voting", "The budget office makes sure no expense is proposed without a source of funds."),
    "PROCUREMENT OFFICE": ("voting", "Procurement handles bidding so city purchases stay competitive and documented."),
    "RECORDS OFFICE": ("voting", "Records are kept for set retention periods so past decisions can still be checked."),
    "CASHIER": ("voting", "Only an authorized cashier may accept payment, and only against an official receipt."),
    "APPLICATION FORM": ("voting", "Filling in the form completely the first time is the fastest way through any City Hall transaction."),
    "VALID ID": ("voting", "A valid ID protects you: it stops someone else from transacting under your name."),
    "SIGNATURE": ("voting", "Signing a document means accepting responsibility for what it says."),
    "OFFICIAL RECEIPT": ("fraud", "No official receipt, no proof of payment: the simplest defence against collection fraud."),
    "TAXPAYER": ("why", "Local taxes pay for the city's roads, health centres, and scholarships."),
    "CITIZEN": ("why", "Any resident may ask how city funds are spent, because the information is public."),
    "BARANGAY CLEARANCE": ("voting", "Barangay clearance shows the barangay has no objection to the transaction."),
    "ZONING CLEARANCE": ("voting", "Zoning clearance confirms the intended use is allowed in that part of the city."),
    "FIRE SAFETY": ("voting", "The Bureau of Fire Protection inspects a building before a fire safety certificate is issued."),
    "SANITARY PERMIT": ("voting", "Food businesses need a sanitary permit and health cards for their workers."),
    "CITY GOVERNMENT": ("why", "A city government has its own council, budget, and taxing powers under the Local Government Code."),
    "LOCAL GOVERNMENT": ("why", "Provinces, cities, municipalities, and barangays are the four local government units in the Philippines."),
    # ---- MEDIUM ----
    "SANGGUNIANG PANLUNGSOD": ("candidate", "The Sangguniang Panlungsod passes the city's ordinances and approves its annual budget."),
    "LOCAL CHIEF EXECUTIVE": ("candidate", "As local chief executive the mayor enforces laws, signs contracts, and supervises every city office."),
    "CITY ADMINISTRATOR": ("candidate", "The city administrator coordinates the day-to-day work of the different city departments."),
    "CITY SECRETARY": ("candidate", "The secretary to the Sanggunian keeps the minutes and the official copy of every ordinance."),
    "CITY LEGAL OFFICER": ("candidate", "The city legal officer reviews contracts before the mayor signs them."),
    "CITY BUDGET OFFICER": ("candidate", "The budget officer prepares the annual budget the mayor submits to the council."),
    "CITY PLANNING OFFICER": ("candidate", "The planning and development coordinator prepares the city's development plans."),
    "CITY HEALTH OFFICER": ("candidate", "The city health officer leads the city's health programs and its health personnel."),
    "CITY SOCIAL WELFARE OFFICER": ("candidate", "This officer runs the city's social welfare and development programs."),
    "CITY BUILDING OFFICIAL": ("candidate", "The building official acts on building permits and can order unsafe work stopped."),
    "APPROPRIATION ORDINANCE": ("voting", "The annual budget becomes spendable only once the council passes it as an appropriation ordinance."),
    "ANNUAL INVESTMENT PROGRAM": ("voting", "The AIP lists the year's priority projects and the funds set aside for each."),
    "EXECUTIVE ORDER": ("voting", "Executive orders direct city offices; they cannot override an ordinance passed by the council."),
    "COMMITTEE HEARING": ("why", "Committee hearings are where a proposed ordinance is studied before the full council votes."),
    "PUBLIC CONSULTATION": ("why", "Consultations let residents raise objections before a policy is final, not after."),
    "PUBLIC BIDDING": ("fraud", "Public bidding is the default rule, because competition is what keeps government prices honest."),
    "BIDS AND AWARDS COMMITTEE": ("fraud", "The BAC opens and evaluates bids, and observers may watch to keep the process transparent."),
    "PURCHASE REQUEST": ("voting", "A purchase request starts the buying process and states what the office actually needs."),
    "PURCHASE ORDER": ("voting", "The purchase order is the document that binds the supplier to the agreed price."),
    "NOTICE OF AWARD": ("voting", "The notice of award tells the winning bidder it has been chosen, and is posted publicly."),
    "NOTICE TO PROCEED": ("voting", "The notice to proceed starts the contract clock for a supplier or contractor."),
    "ABSTRACT OF BIDS": ("fraud", "The abstract of bids shows every offer received, so the winning price can be compared."),
    "ANNUAL PROCUREMENT PLAN": ("voting", "The procurement plan is posted publicly, so residents can see what the city intends to buy."),
    "SUPPLEMENTAL BUDGET": ("voting", "A supplemental budget needs a new revenue source or certified savings before it may be passed."),
    "GENERAL FUND": ("voting", "The general fund pays for salaries, services, and most ordinary city operations."),
    "SPECIAL EDUCATION FUND": ("voting", "The SEF comes from an added tax on real property and may only be spent on public schools."),
    "TRUST FUND": ("voting", "Money in a trust fund may only be used for the purpose it was received for."),
    "LOCAL DEVELOPMENT COUNCIL": ("why", "At least a quarter of the local development council must come from NGOs and people's organizations."),
    "COMPREHENSIVE LAND USE PLAN": ("why", "The CLUP is enacted through a zoning ordinance and guides city growth for about ten years."),
    "ZONING ORDINANCE": ("voting", "The zoning ordinance is what makes the land use plan legally enforceable."),
    "LOCATIONAL CLEARANCE": ("voting", "Locational clearance is checked before a building permit may be issued."),
    "BUSINESS ONE STOP SHOP": ("voting", "The one stop shop puts assessment, payment, and release in one place during the January rush."),
    "MAYOR'S PERMIT": ("voting", "The mayor's permit must be displayed at the business premises."),
    "ASSESSMENT ROLL": ("voting", "The assessment roll lists every taxable property and is the basis of the city's tax billing."),
    "MARKET VALUE": ("voting", "Market value is set in the schedule of fair market values approved by the council."),
    "ASSESSED VALUE": ("voting", "Assessed value is market value multiplied by the assessment level for that class of property."),
    "TAX MAPPING": ("fraud", "Tax mapping finds properties missing from the roll, so the tax burden is shared fairly."),
    "DELINQUENT TAX": ("fraud", "Delinquent real property tax earns two percent interest a month, up to thirty-six months."),
    "TAX CLEARANCE": ("voting", "Tax clearance is often required before a property can be sold or transferred."),
    "CIVIL REGISTRAR": ("candidate", "The local civil registrar's records are forwarded to the Philippine Statistics Authority."),
    "BIRTH CERTIFICATE": ("voting", "A birth certificate is needed to enrol in school, get a passport, and register to vote."),
    "MARRIAGE LICENSE": ("voting", "A marriage license is posted for ten days and is valid for 120 days anywhere in the country."),
    "DEATH CERTIFICATE": ("voting", "A registered death certificate is required before a burial permit can be issued."),
    "SOCIAL CASE STUDY": ("voting", "A social case study report supports requests for medical, burial, or educational assistance."),
    "ENVIRONMENTAL CLEARANCE": ("voting", "Projects likely to affect the environment need clearance before they may begin."),
    "DISASTER RISK REDUCTION": ("why", "Cities set aside at least five percent of regular income for disaster risk reduction and management."),
    "OPERATIONS CENTER": ("why", "The emergency operations centre is where the city's response is coordinated during a disaster."),
    "PUBLIC INFORMATION OFFICE": ("why", "Official announcements come from the public information office, so check there before believing a rumour."),
    "CITIZEN'S CHARTER": ("why", "The Citizen's Charter is required by law and must be posted where the public can read it."),
    "PROCESSING TIME": ("why", "Simple transactions must finish in three days and complex ones in seven, under the Ease of Doing Business Act."),
    # ---- HARD ----
    "LOCAL GOVERNMENT CODE": ("why", "The Local Government Code gives cities their powers to tax, to plan, and to legislate."),
    "REPUBLIC ACT": ("why", "Republic Act 7160, the Local Government Code, took effect on 1 January 1992."),
    "DEVOLUTION": ("why", "Devolution moved health, agriculture, and social welfare services to local governments in 1992."),
    "FISCAL AUTONOMY": ("why", "Fiscal autonomy lets a city set its own spending priorities within the limits of law."),
    "NATIONAL TAX ALLOTMENT": ("voting", "The National Tax Allotment replaced the Internal Revenue Allotment after the Mandanas ruling."),
    "LOCAL REVENUE CODE": ("voting", "The local revenue code sets the rates a city may charge, within national ceilings."),
    "REVENUE ORDINANCE": ("voting", "Revenue ordinances require public hearings before the council may pass them."),
    "APPROPRIATION": ("voting", "No public money may be spent without an appropriation; this is a constitutional rule."),
    "ALLOTMENT": ("voting", "An allotment is the go-signal to commit funds that have already been appropriated."),
    "OBLIGATION REQUEST": ("voting", "The obligation request reserves the funds, so the same money cannot be committed twice."),
    "DISBURSEMENT VOUCHER": ("voting", "A disbursement voucher must carry complete supporting documents before payment is released."),
    "AVAILABILITY OF FUNDS": ("fraud", "The budget officer and accountant certify that funds exist; spending without it is unlawful."),
    "LOCAL FINANCE COMMITTEE": ("candidate", "The local finance committee is the budget officer, the treasurer, and the planning officer."),
    "LOCAL SCHOOL BOARD": ("candidate", "The local school board decides how the Special Education Fund is spent."),
    "LOCAL HEALTH BOARD": ("candidate", "The local health board advises the council on health appropriations."),
    "PEACE AND ORDER COUNCIL": ("candidate", "The peace and order council brings police, barangays, and city officials to one table."),
    "LOCAL SPECIAL BODIES": ("why", "Local special bodies are how citizens sit inside local decisions instead of only outside them."),
    "LEGISLATIVE AGENDA": ("why", "The executive-legislative agenda keeps the mayor and the council working on the same priorities."),
    "INVESTMENT PROGRAM": ("voting", "The local development investment program turns the development plan into funded, scheduled projects."),
    "BUDGET AUTHORIZATION": ("voting", "Budget authorization is the council's power of the purse over the city's spending plan."),
    "BUDGET EXECUTION": ("voting", "Budget execution is where a plan becomes actual roads, medicines, and salaries."),
    "BUDGET ACCOUNTABILITY": ("why", "Budget accountability closes the loop: the city must report what the money actually bought."),
    "PROCUREMENT PLANNING": ("voting", "Good planning avoids the rushed emergency purchases where overpricing usually hides."),
    "BID EVALUATION": ("fraud", "Bids are judged against criteria published in advance, so rules cannot be bent to fit a favourite."),
    "POST QUALIFICATION": ("fraud", "Post-qualification verifies the winning bidder can actually deliver before the award is made."),
    "CONTRACT IMPLEMENTATION": ("fraud", "Most losses happen after the award, so delivery and quality are checked against the contract."),
    "PROJECT MONITORING": ("why", "Monitoring reports let residents see whether a project is on schedule or quietly stalled."),
    "INTERNAL CONTROL": ("fraud", "Internal controls are meant to catch errors and deter misuse before an audit ever finds them."),
    "SEGREGATION OF DUTIES": ("fraud", "No one person should request, approve, pay, and record the same transaction."),
    "CONFLICT OF INTEREST": ("fraud", "Officials must disclose personal interests and step back from decisions that involve them."),
    "PUBLIC DISCLOSURE": ("why", "The full disclosure policy requires cities to post their budgets and contracts publicly."),
    "PUBLIC GRIEVANCE MECHANISM": ("why", "A working complaints desk turns a resident's frustration into a record the city must answer."),
    "RECORDS RETENTION": ("fraud", "Retention rules stop inconvenient documents from being destroyed early."),
    "DATA PRIVACY": ("why", "The Data Privacy Act limits how government may collect, store, and share personal information."),
    "FREEDOM OF INFORMATION": ("why", "Freedom of information makes disclosure the default and secrecy the exception that must be justified."),
    "LAND USE CLASSIFICATION": ("voting", "Classifying land decides where homes, factories, and farms may legally be."),
    "ZONING VARIANCE": ("voting", "A variance is granted only where strict zoning would cause real hardship for that property."),
    "ZONING EXCEPTION": ("voting", "An exception allows a use the zoning ordinance already lists as conditionally permitted."),
    "DEVELOPMENT CONTROL": ("voting", "Development controls set building height, density, and how far a structure sits from the road."),
    "OCCUPANCY CLASSIFICATION": ("voting", "Occupancy classification decides which fire and safety requirements a building must meet."),
    "FIRE CODE COMPLIANCE": ("voting", "Fire Code compliance is checked before occupancy and again at every business renewal."),
    "ACCESSIBILITY COMPLIANCE": ("why", "Batas Pambansa 344 requires ramps, railings, and accessible toilets in public buildings."),
    "IMPACT ASSESSMENT": ("why", "An environmental impact assessment weighs a project's effects before it is approved, not after."),
    "SOLID WASTE MANAGEMENT": ("why", "RA 9003 requires cities to segregate waste and to close their open dumpsites."),
    "TRAFFIC MANAGEMENT": ("voting", "Traffic schemes need an ordinance before fines can lawfully be collected."),
    "LOCAL ECONOMIC DEVELOPMENT": ("why", "Local economic development is judged by the jobs and incomes it creates for residents."),
    "INVESTMENT PROMOTION": ("voting", "Investment incentives are granted through an investment incentive code passed by the council."),
    "SOCIALIZED HOUSING": ("why", "The Urban Development and Housing Act requires cities to set aside land for socialized housing."),
    "CLIMATE ADAPTATION": ("why", "Local climate change action plans must be funded from the city's own budget."),
    "BUSINESS CONTINUITY PLAN": ("why", "A continuity plan keeps certificates, payments, and permits moving even after a disaster."),
}


def spell(display):
    return re.sub(r"[^A-Z]", "", display.upper())


def main():
    parsed = json.loads(PARSED.read_text(encoding="utf-8"))
    built, problems = [], []

    for e in parsed:
        display, prompt = e["display"], e["prompt"]
        if display in REWRITES:
            display, prompt = REWRITES[display]
        answer = spell(display)

        if display not in FACTS:
            problems.append("no fact/category for %r" % display)
            continue
        category, fact = FACTS[display]

        if not 3 <= len(answer) <= MAX_LETTERS:
            problems.append("%s is %d letters" % (display, len(answer)))
        if prompt.count("___") != 1:
            problems.append("%s: prompt has %d blanks" % (display, prompt.count("___")))

        entry = {
            "chapter": CHAPTER,
            "difficulty": e["tier"],
            "category": category,
            "prompt": prompt,
            "answer": answer,
        }
        # Only carried when the two genuinely differ, matching the rest of the
        # bank -- a single-word answer needs no display field at all.
        if display != answer:
            entry["display"] = display
        entry["fact"] = fact
        built.append(entry)

    for key in ("prompt", "answer"):
        seen = {}
        for e in built:
            seen[e[key]] = seen.get(e[key], 0) + 1
        for k, n in seen.items():
            if n > 1:
                problems.append("duplicate %s: %r x%d" % (key, k, n))

    unused = set(FACTS) - {e.get("display", e["answer"]) for e in built}
    problems += ["fact written for an answer not in the set: %r" % u for u in sorted(unused)]

    if problems:
        print("REFUSING TO WRITE -- %d problem(s):" % len(problems))
        for p in problems:
            print("  -", p)
        raise SystemExit(1)

    bank = json.loads(BANK.read_text(encoding="utf-8"))
    kept = [e for e in bank if int(e.get("chapter", 1)) != CHAPTER]
    # Slot the new block back where chapter 2 sat, so the file stays ordered by
    # chapter -- the reviewer walks it in file order.
    at = next(i for i, e in enumerate(kept) if int(e.get("chapter", 1)) > CHAPTER)
    merged = kept[:at] + built + kept[at:]

    BANK.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n",
                    encoding="utf-8")

    print("chapter 2: %d -> %d entries" % (len(bank) - len(kept), len(built)))
    print("bank total: %d -> %d" % (len(bank), len(merged)))
    for t in ("easy", "medium", "hard"):
        pool = [e for e in built if e["difficulty"] == t]
        longest = max(pool, key=lambda e: len(e["answer"]))
        print("  %-6s %3d   longest %2d  %s" % (
            t, len(pool), len(longest["answer"]),
            longest.get("display", longest["answer"])))


main()
