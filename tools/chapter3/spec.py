# -*- coding: utf-8 -*-
"""Chapter 3's nine rooms, as prompts.

Chapter 2's room prompts were never written down -- its spec.py kept only the
placeholder fill colours -- so nothing recorded why those rooms look the way
they do or how to ask for a tenth that matched. This file is that record.

THE POINT OF THIS FILE is that the nine rooms have to read as ONE PLACE. A
provincial capitol is not nine unrelated locations; it is a single 1920s
neoclassical government house standing in its own grounds, with the same
architecture whether you are looking at a corridor or a courtyard. So every
prompt below carries one of two SHARED openings -- inside or outside the same
building -- and only the fittings change. Ask for nine rooms independently and
you get nine different buildings.

Philippine provincial capitols are a real and consistent architecture: built
under the American period by the Bureau of Public Works, symmetrical, a columned
portico over a wide flight of steps, a central pediment and often a dome, set in
landscaped grounds with a flagpole, a park and the provincial seal. Inside:
terrazzo floors, tall arched windows, high ceilings, dark hardwood and brass.

FOUR OUTDOOR, FIVE INDOOR, and they are ordered so the chapter walks INWARD.
The gate, the project yard, the arcade and the relief yard are all on capitol
grounds; from encounter 7 the chapter is inside for good and stays there
through the session hall to the governor's office. Getting further in as the
fights get harder is the progression the battle scene already stages as walking
right, so the rooms may as well mean it.

THE FLOOR LINE is the one hard constraint. The battle scene stands the fighters
at 91.25% of the image height, across the FULL width. Chapter 2 lost three rooms
to this -- the session hall, the bidding room and the service lobby all seated
furniture exactly where the fighters stand, and every one had to be repainted
afterwards (open_session_floor.py, widen_aisle.py). Rooms 7 and 8 below are the
same shape of room, so both prompts push the furniture into the back half and
ask for an open well in front. The outdoor rooms have the same trap in a
different costume: a parked truck or a hedge across the foreground is furniture
too.

    render size 384x256, floor line at 91.25% of height
"""

SIZE = (384, 256)
GROUND_FRACTION = 0.9125

# One building, seen from inside.
SHARED_IN = (
    "pixel art interior of a 1920s Philippine provincial capitol, American-period "
    "neoclassical government building, cream and ochre plaster walls, tall arched "
    "windows with capiz shell panes, polished terrazzo floor, high ceiling, dark "
    "hardwood trim and brass fittings, warm daylight, muted earthy palette, "
    "side-on view like a fighting game stage, "
)

# The same building, seen from outside. Deliberately shares the wording that
# describes the ARCHITECTURE so the exteriors are recognisably this capitol and
# not a generic government building.
SHARED_OUT = (
    "pixel art exterior on the grounds of a 1920s Philippine provincial capitol, "
    "American-period neoclassical government building of cream and ochre plaster "
    "with tall columns and arched windows visible behind, tropical daylight, "
    "acacia trees and clipped hedges, muted earthy palette, "
    "side-on view like a fighting game stage, "
)

# Every room must leave this clear or the fighters stand in the furniture.
FLOOR_IN = (
    " empty open floor across the entire bottom of the image, full width, no "
    "furniture or people in the foreground, all fittings set back against the "
    "walls"
)
FLOOR_OUT = (
    " flat empty open ground across the entire bottom of the image, full width, "
    "no vehicles, planters, hedges or people in the foreground, everything set "
    "back behind it"
)

ROOMS = [
    dict(
        key="capitol_gate",
        label="Capitol Gate & Guardhouse",
        rival="Guard Garapal",
        outdoor=True,
        # The gate is literally his post, which makes it a better room for him
        # than the portico: the fight is about who gets through, and the thing
        # being fought over is in the frame.
        prompt=SHARED_OUT + (
            "the main capitol gate, ornamental iron gates between two stone piers "
            "carrying the provincial seal, a small tiled guardhouse to one side "
            "with a swing barrier and a logbook on a ledge, a flagpole flying the "
            "Philippine flag, the columned capitol facade rising in the "
            "background at the end of a driveway"
        ) + FLOOR_OUT,
    ),
    dict(
        key="capitol_assessor",
        label="Provincial Assessor's Office",
        rival="Assessor Anino",
        outdoor=False,
        prompt=SHARED_IN + (
            "provincial assessor's office, walls covered in large cadastral tax "
            "maps and land parcel plats, wooden map cabinets with wide flat "
            "drawers, rolled survey plans in racks, a long counter along the back "
            "wall, dusty ledgers"
        ) + FLOOR_IN,
    ),
    dict(
        key="capitol_project_yard",
        label="Capitol Motor Pool & Project Yard",
        rival="Engineer Epal",
        outdoor=True,
        # Back outdoors, and now justified: the equipment yard IS on capitol
        # grounds in most provinces, and it is where his tarpaulins actually
        # hang. A giant vinyl banner of his own face over a half-finished
        # project is the single most legible image of epal culture there is.
        prompt=SHARED_OUT + (
            "the capitol motor pool and project yard behind the building, "
            "provincial dump trucks and a road grader parked in a row along the "
            "back fence, stacked culvert pipes and sacks of cement, a huge vinyl "
            "project tarpaulin banner strung across the back showing a smiling "
            "official's face, corrugated roofing over an open equipment shed"
        ) + FLOOR_OUT,
    ),
    dict(
        key="capitol_treasury",
        label="Provincial Treasury",
        rival="Treasurer Tuso",
        outdoor=False,
        prompt=SHARED_IN + (
            "provincial treasury office, brass teller grilles along the back "
            "wall, a heavy steel vault door set into the side wall, coin trays "
            "and cash boxes, bundled receipts, an old adding machine, a barred "
            "window"
        ) + FLOOR_IN,
    ),
    dict(
        key="capitol_arcade",
        label="Capitol Arcade & Bulletin Wall",
        rival="Auditor Alibi",
        outdoor=True,
        # A covered arcade open to the grounds -- outdoor light, capitol
        # architecture. And it is the right room for him for a real reason:
        # audit findings and notices of disallowance ARE posted publicly. The
        # point of the fight is that they are posted where everyone can see
        # them and nobody reads them.
        prompt=SHARED_OUT + (
            "a covered arcade walkway along the side of the capitol, a row of "
            "plastered arches open to the grounds on one side, a long public "
            "bulletin board on the wall opposite thick with pinned audit "
            "notices, memoranda and curling posted papers, a bench, dappled "
            "light through the arches onto the tiled walkway"
        ) + FLOOR_OUT,
    ),
    dict(
        key="capitol_relief_yard",
        label="Capitol Relief Staging Yard",
        rival="Kalamidad Kiko",
        outdoor=True,
        # Outdoors beats the radio room: the money is visible as goods on
        # pallets with his name on the sacks, which is the thing the encounter
        # is actually about.
        prompt=SHARED_OUT + (
            "the capitol relief staging yard, a loading bay with a roll-up "
            "shutter, sacks and boxes of relief goods stacked on wooden pallets "
            "along the back, a provincial rescue truck backed up to the bay, a "
            "printed tarpaulin banner over the shutter, blue plastic tarpaulin "
            "sheeting bundled to one side, an overcast sky before a storm"
        ) + FLOOR_OUT,
    ),
    dict(
        key="capitol_committee",
        label="Committee Room",
        rival="Konsehala Kubli",
        outdoor=False,
        # Furniture-at-the-sides risk. The table is explicitly pushed BACK
        # rather than centred, and the closed shutters are both the mood and a
        # reason for the room to be lit from one side.
        prompt=SHARED_IN + (
            "small legislative committee room, one long polished hardwood "
            "conference table set far back against the rear wall with high-backed "
            "chairs behind it, closed wooden window shutters, framed portraits of "
            "past governors along the walls, a carafe and glasses, dim lamplight"
        ) + FLOOR_IN,
    ),
    dict(
        key="capitol_session_hall",
        label="Sangguniang Panlalawigan Session Hall",
        rival="Board Member Bulok",
        outdoor=False,
        # The room Chapter 2 got wrong twice. Both times the desks ran the full
        # width with a narrow central aisle, so the fighters stood on the chair
        # backs. Here the tiered desks are asked for in the BACK HALF only, with
        # the well of the chamber open in front -- which is also what a real
        # session hall looks like.
        prompt=SHARED_IN + (
            "provincial legislature session hall, curved tiered wooden desks in "
            "the back half of the room only, an elevated presiding officer's "
            "rostrum at the rear centre beneath a large carved provincial seal, "
            "microphones on the desks, a public gallery railing high at the back, "
            "ceiling fans, a wide open well of polished floor in front of the "
            "desks"
        ) + FLOOR_IN,
    ),
    dict(
        key="capitol_governor_office",
        label="Governor's Office",
        rival="Gobernador Ganid",
        outdoor=False,
        # Phase 2 is a GRADE of this image, not a second generation -- see
        # grade_phase2.py in the Chapter 2 tools for why. So this one has to
        # hold up dimmed and pushed red as well as lit, which is another reason
        # the boss room is interior: an outdoor sky does not take that grade.
        prompt=SHARED_IN + (
            "provincial governor's executive office, a wide carved hardwood desk "
            "set back against the rear wall, a tall leather chair, the provincial "
            "seal mounted on the wall behind it, a row of framed portraits of "
            "previous governors, heavy drapes at tall windows, a Philippine flag "
            "on a stand, glass-fronted cabinets of trophies and plaques"
        ) + FLOOR_IN,
    ),
]

# Graded from capitol_governor_office rather than generated. Chapter 2 paid a
# generation for a phase-2 arena and it came back BRIGHTER than phase 1, which
# is backwards for the lights going out, so it was graded anyway.
PHASE2 = dict(
    key="capitol_governor_office_phase2",
    source="capitol_governor_office",
    method="grade",
)


def prompt_for(key):
    for room in ROOMS:
        if room["key"] == key:
            return room["prompt"]
    raise KeyError(key)
