local Config = {}

Config.ESP_RADIUS = 200

Config.DOOR_COLOR = Color3.fromRGB(80, 255, 80)
Config.LEVER_COLOR = Color3.fromRGB(80, 255, 80)
Config.KEY_COLOR = Color3.fromRGB(0, 200, 255)
Config.PROMPT_COLOR = Color3.fromRGB(255, 200, 0)
Config.TOOL_COLOR = Color3.fromRGB(0, 220, 255)

Config.PROMPT_BLACKLIST = {
	Painting = true,
	Drawer = true,
	Toilet = true,
	Regal = true,
	HidePrompt = true,
	Hide = true,
}

Config.PROMPT_BLUELIST = {
	Key = true,
}

Config.MONSTER_BLACKLIST = {
	SeekArms = true,
	FigureAttach = true,
	FigureRig = true,
	FigureArm = true,
	FigureLeg = true,
	FigureHead = true,
	FigureTorso = true,
	FigureBody = true,
	Attachment = true,
	Attachments = true,
	Hitbox = true,
	HitBox = true,
	Rig = true,
	RootPart = true,
	Root = true,
	HidePrompt = true,
	HidePrompts = true,
	Prompt = true,
	Prompts = true,
	Trigger = true,
	Triggers = true,
	Detector = true,
	Sensor = true,
	Collision = true,
	Collider = true,
	Region = true,
	Zone = true,
	Area = true,
	Marker = true,
	Point = true,
	Spawn = true,
	Spawner = true,
	Anchor = true,
	Base = true,
	Stand = true,
	Stand1 = true,
	Stand2 = true,
	Stand3 = true,
	Stand4 = true,
	Stand5 = true,
	Stand6 = true,
	Stand7 = true,
	Stand8 = true,
}

Config.MONSTER_PREFIXES = {
	"Rush",
	"Ambush",
	"Eyes",
	"Figure",
	"Seek",
	"Hide",
	"Glitch",
	"Jack",
}

Config.ENTITY_LIST = {
	RushMoving = "Rush",
	AmbushMoving = "Ambush",
	Eyes = "Eyes",
	Lookman = "Eyes",
	BackdoorRush = "Blitz",
	BackdoorLookman = "Lookman",
	A60 = "A-60",
	A120 = "A-120",
	GloombatSwarm = "Gloombat Swarm",
	GlitchRush = "RNIUSHCG==",
	GlitchAmbush = "AR0xMBUSH",
	MonumentEntity = "Monument",
	JeffTheKiller = "Jeff the Killer",
	FrozenAmbush = "Frozen Ambush",
	SallyMoving = "Sally",
	Groundskeeper = "Groundskeeper",
}

Config.ITEM_NAMES = {
	Lockpick = "Lockpicks",
	SkeletonKey = "Skeleton Key",
	Shears = "Shears",
	Multitool = "Multitool",
}

Config.FAKE_SPEED = 15
Config.REAL_SPEED_DEFAULT = 16
Config.MIN_SPEED = 16
Config.MAX_SPEED = 150

Config.FOV_DEFAULT = 70
Config.FOV_MIN = 1
Config.FOV_MAX = 120

Config.TOOL_WAIT = 0.1
Config.CHEST_WAIT = 30
Config.MOVE_TIME = 2
Config.HEIGHT_OFFSET = 3

Config.PLACE_IDS = {
	Doors = 2440500124,
	BuildABoat = 537413528,
}

return Config
