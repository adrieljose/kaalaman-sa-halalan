extends "res://scripts/environments/palace_environment.gd"
## Congress-specific scenery data; shared proven cosmetic director underneath.
const CONGRESS_ROOT := "res://assets/images/backgrounds/chapter5/"
const CONGRESS_STAGES := [
 {"id":"01_annex_entrance","type":"outdoor","title":"LEGISLATIVE ANNEX ENTRANCE","wind":true,"flag":Vector2(.09,.39),"roles":[0,2],"foliage":Vector4(.01,.16,.22,.31),"sky":Vector4(.02,.0,.96,.21),"vehicle":true,"sound":"courtyard"},
 {"id":"02_senate_floor","type":"indoor","title":"SENATE SESSION FLOOR","wind":false,"roles":[0,1],"monitor":Vector4(.74,.22,.13,.12),"papers":Vector4(.15,.42,.70,.07),"lamp":Vector4(.1,.12,.12,.16),"sound":"hall"},
 {"id":"03_hearing_room","type":"indoor","title":"COMMITTEE HEARING ROOM","wind":false,"roles":[3,4],"monitor":Vector4(.76,.24,.12,.12),"papers":Vector4(.2,.43,.58,.06),"door":Vector4(.06,.22,.10,.29),"sound":"press"},
 {"id":"04_assembly_walkway","type":"outdoor / semi-outdoor","title":"OUTER ASSEMBLY WALKWAY","wind":true,"flag":Vector2(.09,.39),"roles":[0,2],"foliage":Vector4(.02,.19,.24,.28),"sky":Vector4(.01,.01,.3,.24),"monitor":Vector4(.76,.25,.13,.10),"papers":Vector4(.30,.43,.25,.05),"sound":"courtyard"},
 {"id":"05_caucus_terrace","type":"semi-outdoor","title":"CAUCUS STRATEGY TERRACE","wind":true,"roles":[0,1],"foliage":Vector4(.1,.2,.8,.24),"sky":Vector4(.2,.1,.6,.2),"curtain":Vector4(.03,.12,.10,.31),"monitor":Vector4(.76,.24,.13,.12),"papers":Vector4(.22,.43,.54,.07),"sound":"garden"},
 {"id":"06_revision_office","type":"indoor","title":"LEGISLATIVE REVISION OFFICE","wind":false,"roles":[0,1],"papers":Vector4(.24,.41,.56,.09),"monitor":Vector4(.75,.27,.14,.10),"lamp":Vector4(.16,.28,.07,.14),"door":Vector4(.06,.22,.10,.28),"sound":"office"},
 {"id":"07_bicam_room","type":"indoor","title":"BICAMERAL CONFERENCE ROOM","wind":false,"roles":[0,1],"monitor":Vector4(.75,.23,.12,.12),"papers":Vector4(.22,.42,.56,.08),"lamp":Vector4(.45,.04,.10,.17),"door":Vector4(.06,.21,.1,.28),"sound":"office"},
 {"id":"08_budget_plaza","type":"outdoor / semi-outdoor","title":"APPROPRIATIONS ANNEX PLAZA","wind":true,"flag":Vector2(.09,.36),"roles":[1,5],"foliage":Vector4(.01,.15,.23,.30),"sky":Vector4(.02,.0,.94,.2),"water":Vector4(.17,.43,.12,.07),"vehicle":true,"cart":true,"monitor":Vector4(.75,.25,.14,.11),"sound":"operations"},
 {"id":"09_grand_house_hall","type":"hybrid","title":"GRAND HOUSE CHAMBER","wind":true,"flag":Vector2(.10,.35),"roles":[0,2],"sky":Vector4(.03,.12,.23,.23),"foliage":Vector4(.04,.27,.22,.20),"curtain":Vector4(.02,.12,.09,.34),"monitor":Vector4(.74,.20,.15,.12),"lamp":Vector4(.43,.03,.14,.17),"papers":Vector4(.35,.42,.30,.06),"sound":"hall"},
]
var state: int = 0

func configure(index: int) -> void:
	var stage: Dictionary = CONGRESS_STAGES[clampi(index,0,8)].duplicate(true)
	# Regions measured from the actual generated artwork (normalized UVs).
	var regions := [
		{"flag":Vector2(.646,.041),"sky":Vector4(.15,.0,.40,.25),"foliage":Vector4(.0,.02,.20,.46),"vehicle_lane":Vector3(.15,.29,.505)},
		{"monitor":Vector4(.726,.064,.174,.135),"papers":Vector4(.13,.33,.75,.06),"lamp":Vector4(.638,.12,.024,.113)},
		{"monitor":Vector4(.870,.058,.108,.117),"door":Vector4(.026,.12,.084,.29),"papers":Vector4(.18,.30,.70,.025),"sky":Vector4(.22,.0,.28,.25)},
		{"monitor":Vector4(.861,.077,.12,.20),"curtain":Vector4(.164,.133,.04,.058),"sky":Vector4(.10,.0,.25,.32),"foliage":Vector4(.0,.0,.125,.34)},
		{"monitor":Vector4(.752,.061,.146,.098),"curtain":Vector4(.303,.056,.056,.23),"papers":Vector4(.35,.36,.3,.025),"foliage":Vector4(.08,.10,.19,.25)},
		{"monitor":Vector4(.727,.223,.045,.018),"papers":Vector4(.81,.065,.19,.175),"door":Vector4(.023,.048,.112,.34),"lamp":Vector4(.174,.039,.026,.078),"clock_position":Vector2(.718,.095)},
		{"monitor":Vector4(.702,.064,.17,.163),"papers":Vector4(.16,.32,.67,.034),"door":Vector4(.0,.12,.048,.233),"curtain":Vector4(.382,.06,.03,.21)},
		{"monitor":Vector4(.87,.254,.082,.105),"water":Vector4(.066,.278,.062,.091),"vehicle_lane":Vector3(.34,.53,.43),"sound":"garden"},
		{"monitor":Vector4(.680,.085,.173,.15),"flag":Vector2(.36,.195),"curtain":Vector4(.0,.0,.045,.43),"sky":Vector4(.07,.025,.155,.26),"foliage":Vector4(.07,.31,.16,.10),"papers":Vector4(.43,.39,.22,.055)},
	]
	stage.merge(regions[index],true)
	# Stage 4 already has a flag painted on its pole; animate that cloth region.
	if index == 3: stage.erase("flag")
	stage.work_gestures = true
	stage.lane = Vector3(.16,.34,.52)
	super.setup(index, stage, CONGRESS_ROOT)

func set_stage(value: int) -> void:
	if stage_index != 8: return
	state = clampi(value,0,2)
	phase_target = float(state)
	if state > 0:
		for actor in actors:
			actor.state = "leaving"
			actor.duration = 2.5

func escalate() -> void:
	set_stage(1)

func stop() -> void:
	state = 0
	phase_mix = 0.0
	phase_target = 0.0
	if is_instance_valid(material_fx):
		material_fx.set_shader_parameter("escalation",0.0)
		material_fx.set_shader_parameter("impact",0.0)
	super.stop()
