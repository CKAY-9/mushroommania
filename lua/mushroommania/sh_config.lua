--[[
    Mushroom Mania - Configuration
    Edit the values below to tune the addon. Changes need a map change / server restart.

    Grow loop:
      1. Drop Substrate into a MonoTub
      2. Drop up to 2 Filters into the MonoTub
      3. Tilt the Cleaning Agent over the MonoTub to pour it in
      4. Drop a Liquid Culture into the MonoTub
      5. Keep the filters alive and mist the tub with the Spray Bottle
      6. Press E on the tub when it's ready to harvest
      7. (Optional) Dry the mushrooms in a Food Drier, then sell to a Mushroom Enthusiast
]]

MushroomMania = MushroomMania or {}
MushroomMania.Config = {}
local C = MushroomMania.Config

--------------------------------------------------------------------------------
-- DarkRP F4 shop
--   Every entry below is added to the F4 menu when Register = true.
--   Liquid cultures are added automatically from C.Species (see ShopPrice).
--------------------------------------------------------------------------------
C.Shop = {
    Register       = true,               -- false = add the items yourself in darkrpmodification (also in the Q menu settings)
    Category       = "Mushroom Mania",   -- F4 category for every item
    CreateCategory = true,               -- Create the category above (entities + weapons tabs). false if it already exists
    CategoryColor  = Color(170, 120, 70),
    CategorySort   = 100,
    AllowedJobs    = {},                 -- e.g. { "TEAM_GANG" }. Empty = every job. Applies to every item

    --  class     = entity / weapon class
    --  weapon    = true for SWEPs (sold as a single weapon in the Weapons tab)
    --  max       = max owned per player (entities only)
    Items = {
        { class = "mm_monotub",        name = "MonoTub",        price = 1500, max = 4, cmd = "buymonotub" },
        { class = "mm_filter",         name = "Filter",         price = 150,  max = 8, cmd = "buymmfilter" },
        { class = "mm_substrate",      name = "Substrate",      price = 200,  max = 4, cmd = "buymmsubstrate" },
        { class = "mm_cleaning_agent", name = "Cleaning Agent", price = 250,  max = 2, cmd = "buymmcleaner" },
        { class = "mm_food_drier",     name = "Food Drier",     price = 2000, max = 1, cmd = "buymmdrier" },
        { class = "mm_spray_bottle",   name = "Spray Bottle",   price = 100,  weapon = true, cmd = "buymmspraybottle" },
    },
}

--------------------------------------------------------------------------------
-- Content download (custom models / materials)
--   Clients need the custom models or they see ERROR. Either:
--     - set WorkshopID to a Workshop addon containing models/ + materials/
--       (recommended for live servers: fast, cached), or
--     - leave SendFiles on: the server sends the files itself on join
--       (uses FastDL if sv_downloadurl is set, otherwise slow direct download)
--------------------------------------------------------------------------------
C.Content = {
    WorkshopID = "",     -- e.g. "1234567890". When set, SendFiles is skipped
    SendFiles  = true,
    -- Every model / material folder matching these is sent (wildcards allowed)
    Models     = { "models/bmod/mushroommania_*.mdl" },
    Materials  = { "materials/models/bmod/mushroommania_*" },
}

--------------------------------------------------------------------------------
-- In-game settings (Q menu > Utilities > Mushroom Mania > Settings)
--   Lets permitted staff change the F4 toggle, sell prices and quality values
--   live. Saved to data/mushroommania/settings.json, which overrides this file
--   (use "Reset to config defaults" in the menu to go back to these values).
--------------------------------------------------------------------------------
C.Settings = {
    Privilege = "Mushroom Mania Settings", -- CAMI permission name (shows up in ULX / SAM etc.)
    MinAccess = "admin",                   -- Default group when no admin mod grants it: "user", "admin" or "superadmin"
}

--------------------------------------------------------------------------------
-- Mushroom species
--   Each key becomes a liquid culture entity named "mm_culture_<key>".
--   Copy the block to add a new species.
--
--   Optional grow rules (leave out to use the defaults in C.Grow / C.Filter):
--     NeedsFilters    = false   No filters needed: never contaminates without one, fitted filters don't wear
--     NeedsCleaning   = false   Culture can go straight onto substrate (no cleaning agent)
--     UnfilteredContaminateTime Seconds without a filter before contamination (0 = instantly)
--     StartHumidity, HumidityDecay, IdealMin, IdealMax, QualityLoss   Override C.Grow
--     PerfectHumidity = { min, max }  Humidity must stay in this band for "Perfect" quality.
--                               More than PerfectGrace seconds outside it (in total) caps the grow at the next tier
--     PerfectGrace    = 5
--     Glow            = { Color = Color(...), Alpha = 0-255, Size = 1 }   Subtle glow around everything of this strain
--------------------------------------------------------------------------------
C.Species = {
    lionsmane = {
        Name       = "Lion's Mane",
        Short      = "Lion's Mane",         -- Used where space is tight
        Color      = Color(240, 232, 210),  -- Label accent
        Order      = 1,                     -- Sort order in the F4 / settings menus
        GrowTime   = 300,                   -- Seconds from culture to harvest
        Yield      = { 8, 12 },             -- Random amount (units) per harvest, min/max
        RawPrice   = 30,                    -- Value per unit at "Good" quality (100%)
        DriedPrice = 55,                    -- Value per unit once dried
        ShopPrice  = 250,                   -- F4 price of the liquid culture. nil = not sold
        ShopMax    = 4,
        ShopCmd    = "buylionsmaneculture",
        CultureModel = nil,                 -- nil = C.Culture.Model
        CultureColor = Color(255, 255, 255), -- Tint of the culture vial. nil = Color, then C.Culture.Color
        -- Beginner strain: no filters, no cleaning, forgiving humidity
        NeedsFilters  = false,
        NeedsCleaning = false,
        IdealMin      = 20,
        IdealMax      = 100,
        QualityLoss   = 0.1,
    },

    goldenteachers = {
        Name       = "Golden Teachers",
        Short      = "Golden Teachers",
        Color      = Color(225, 185, 90),
        Order      = 2,
        GrowTime   = 360,
        Yield      = { 8, 12 },
        RawPrice   = 60,
        DriedPrice = 110,
        ShopPrice  = 500,
        ShopMax    = 4,
        ShopCmd    = "buygoldenteachersculture",
        CultureColor = Color(255, 200, 60),
    },

    penisenvy = {
        Name       = "Penis Envy",
        Short      = "Penis Envy",
        Color      = Color(215, 160, 140),
        Order      = 3,
        GrowTime   = 420,
        Yield      = { 8, 12 },
        RawPrice   = 85,
        DriedPrice = 155,
        ShopPrice  = 800,
        ShopMax    = 4,
        ShopCmd    = "buypenisenvyculture",
        CultureColor = Color(255, 140, 120),
    },

    tidalwave = {
        Name       = "Tidal Wave",
        Short      = "Tidal Wave",
        Color      = Color(110, 175, 230),
        Order      = 4,
        GrowTime   = 480,
        Yield      = { 8, 12 },
        RawPrice   = 110,
        DriedPrice = 200,
        ShopPrice  = 1100,
        ShopMax    = 4,
        ShopCmd    = "buytidalwaveculture",
        CultureColor = Color(90, 170, 255),
    },

    enigma = {
        Name       = "Enigmas",
        Short      = "Enigmas",
        Color      = Color(175, 130, 215),
        Order      = 5,
        GrowTime   = 600,
        Yield      = { 8, 12 },
        RawPrice   = 150,
        DriedPrice = 275,
        ShopPrice  = 1500,
        ShopMax    = 4,
        ShopCmd    = "buyenigmaculture",
        CultureColor = Color(185, 110, 255),
        Glow         = { Color = Color(170, 90, 255), Alpha = 50, Size = 1 }, -- Soft pulsing glow on its culture, tub, bags and drier
        -- Expert strain: 80-90% humidity for Perfect, contaminated the moment it has no filter
        StartHumidity   = 85,
        PerfectHumidity = { 80, 90 },
        PerfectGrace    = 5,
        UnfilteredContaminateTime = 0,
    },
}

--------------------------------------------------------------------------------
-- Qualities (checked top to bottom, first MinScore reached wins)
--   A grow starts at 100 score and loses points while humidity is outside the
--   ideal range (see C.Grow).
--------------------------------------------------------------------------------
C.Qualities = {
    { Name = "Perfect", Multiplier = 1.10, MinScore = 90, Color = Color(120, 220, 255) },
    { Name = "Good",    Multiplier = 1.00, MinScore = 70, Color = Color(120, 220, 120) },
    { Name = "Okay",    Multiplier = 0.80, MinScore = 45, Color = Color(230, 210, 100) },
    { Name = "Poor",    Multiplier = 0.50, MinScore = 0,  Color = Color(230, 140, 80)  },
}

C.Contaminated = {
    Name       = "Contaminated",
    Multiplier = 0.10,
    Color      = Color(140, 200, 60),
    RejectTime = 600,     -- Seconds every Mushroom Enthusiast refuses a player after selling contaminated mushrooms
}

--------------------------------------------------------------------------------
-- Growing
--------------------------------------------------------------------------------
C.Grow = {
    StartHumidity = 60,   -- Humidity (0-100) when the culture goes in
    HumidityDecay = 0.4,  -- Humidity lost per second while growing
    IdealMin      = 40,   -- Humidity below this hurts quality
    IdealMax      = 90,   -- Humidity above this hurts quality (over-misting)
    QualityLoss   = 0.25, -- Score lost per second outside the ideal range
}

--------------------------------------------------------------------------------
-- Entities
--   Model / Color / Material are placeholders - swap them for custom models.
--   Health = 0 makes the entity indestructible.
--------------------------------------------------------------------------------
C.MonoTub = {
    Model         = "models/bmod/mushroommania_monotubandall.mdl",
    Color         = nil,
    ContaminatedColor = Color(170, 210, 120),
    Material      = "",
    Health        = 0,
    Uses          = 5,       -- Harvests before the tub breaks (contaminated grows count too)
    OwnerOnlyHarvest = false,
    LabelDistance = 350,

    -- Bodygroup names in the model (each toggles 0 = hidden / 1 = shown).
    -- Set a name to "" to never touch that part. Missing names are ignored.
    Bodygroups = {
        Substrate = "substrate", -- Shown from substrate added until harvest
        Filter1   = "filter1",   -- Shown while 1+ filters are fitted
        Filter2   = "filter2",   -- Shown while 2+ filters are fitted
        Pins      = "pins",      -- Shown from culture added until harvest
        Lid       = "lid",       -- Shown while growing
    },
    LidWhenReady  = false,       -- Keep the lid on once ready to harvest (false = lid comes off as a "ready" cue)
}

C.Filter = {
    Model         = "models/bmod/mushroommania_filter.mdl",
    Color         = nil,
    Health        = 150,     -- Seconds of degradation a filter can take
    MaxPerTub     = 2,
    DegradeRate   = 1.0,     -- Health lost per second while growing
    WearAll       = false,   -- false = only the oldest filter wears; the next takes over when it dies
                             -- true  = every fitted filter wears at the same time
    WearPerHarvest = 0,      -- Health removed from every fitted filter on harvest
    UnfilteredContaminateTime = 30, -- Seconds a growing tub can go without a filter before it's contaminated
    LabelDistance = 250,
}

C.Substrate = {
    Model         = "models/props_junk/garbage_bag001a.mdl",
    Color         = Color(150, 110, 70),
    LabelDistance = 250,
}

C.CleaningAgent = {
    -- The model must stand upright at Angle(0, 0, 0): tilt is measured from its local up axis
    Model         = "models/props_junk/garbage_plasticbottle001a.mdl",
    Color         = Color(200, 230, 255),
    Liquid        = 12,      -- Seconds of pouring in a full bottle
    CleanTime     = 3,       -- Seconds of pouring a tub needs
    PourAngle     = 80,      -- Degrees from upright before it starts pouring
    PourRange     = 160,     -- How far the stream falls looking for a tub
    SpoutOffset   = Vector(0, 0, 0), -- Local offset added to the top of the model
    RemoveWhenEmpty = true,
    StreamColor   = Color(210, 235, 255, 150),
    StreamRate    = 90,      -- Particles per second
    LabelDistance = 250,
}

C.Culture = {
    Model         = "models/healthvial.mdl",
    Color         = Color(230, 210, 170),
    LabelDistance = 250,
}

C.Mushrooms = {
    Model         = "models/props_junk/garbage_takeoutcarton001a.mdl",
    Color         = Color(230, 215, 190),  -- Raw
    DriedColor    = Color(160, 120, 80),
    Unit          = "g",
    DespawnTime   = 0,       -- Seconds before an untouched batch is removed. 0 = never
    LabelDistance = 250,
}

C.FoodDrier = {
    Model         = "models/bmod/mushroommania_fooddrier.mdl",
    Color         = nil,
    Health        = 0,
    -- Drop raw mushrooms on it to load it, press E to start, wait, press E to collect.
    Capacity      = 50,      -- Grams of raw mushrooms it holds
    DryTime       = 120,     -- Seconds per drying cycle (every batch inside dries together)
    LoopSound     = "ambient/machines/laundry_machine1_amb.wav", -- Played while running. "" = silent
    SoundLevel    = 75,      -- dB. Higher = heard further away (75 = normal, 90 = loud, 100+ = very loud)
    Volume        = 1,
    Pitch         = 120,
    LabelDistance = 300,

    -- Bodygroup values per state: [bodygroup name] = { Idle = value, Running = value }
    -- (check the option order in the model: shelfout's option 0 is the shelf, shelfin's option 1 is)
    Bodygroups = {
        shelfout = { Idle = 0, Running = 1 }, -- Shelf pulled out while not running
        shelfin  = { Idle = 0, Running = 1 }, -- Shelf pushed in while running
    },

    -- Faint smoke + heat shimmer from the vent while running (client-side only)
    VentEffect = {
        Enabled    = true,
        Offset     = Vector(-15.8, 0, 6.9), -- Vent face centre, in model-local coordinates
        Direction  = Vector(-1, 0, 0),      -- Model-local direction the vent blows
        Size       = Vector(0, 8, 4),       -- Spread across the vent face (local Y = width, Z = height)
        SmokeRate  = 6,                     -- Smoke puffs per second. 0 = none
        SmokeAlpha = 22,                    -- 0-255, keep low for subtle
        SmokeColor = Color(215, 215, 215),
        HeatRate   = 8,                     -- Heat shimmer sprites per second. 0 = none
        Distance   = 1200,                  -- Don't emit beyond this distance from the viewer
    },
}

C.Enthusiast = {
    Model         = "models/Humans/Group03/male_04.mdl",
    Sequence      = "LineIdle01",
    SellRadius    = 160,     -- Mushrooms within this distance are sold when pressing E
    OwnerOnly     = false,   -- Only sell batches the player owns (false = anyone's)
    AllowPolice   = false,
    BlockedJobs   = {},      -- e.g. { "TEAM_MAYOR" }
    LabelDistance = 600,
}

--------------------------------------------------------------------------------
-- Spray Bottle (SWEP)
--------------------------------------------------------------------------------
C.SprayBottle = {
    Water            = 40,   -- Sprays per bottle. 0 = infinite
    HumidityPerSpray = 8,
    Range            = 100,
    Delay            = 0.5,  -- Seconds between sprays
}

--------------------------------------------------------------------------------
-- Sounds ("" to disable)
--------------------------------------------------------------------------------
C.Sounds = {
    Insert       = "physics/cardboard/cardboard_box_impact_soft1.wav",
    InsertCulture = "items/medshot4.wav",
    Cleaned      = "garrysmod/content_downloaded.wav",
    Pour         = "ambient/water/water_flow_loop1.wav",
    Spray        = "weapons/bugbait/bugbait_squeeze1.wav",
    SprayEmpty   = "buttons/button10.wav",
    FilterBroken = "physics/plastic/plastic_box_impact_soft1.wav",
    Contaminated = "ambient/levels/canals/toxic_slime_gurgle4.wav",
    Ready        = "garrysmod/save_load2.wav",
    Harvest      = "items/ammo_pickup.wav",
    TubBroken    = "physics/plastic/plastic_barrel_break1.wav",
    DrierStart   = "buttons/lever7.wav",
    Dried        = "garrysmod/content_downloaded.wav",
    Sell         = "garrysmod/save_load2.wav",
    Deny         = "buttons/button10.wav",
}

--------------------------------------------------------------------------------
-- Theme (3D labels)
--------------------------------------------------------------------------------
C.Theme = {
    Font       = "Roboto",
    LabelScale = 0.08,
    Background = Color(18, 15, 12, 225),
    Border     = Color(70, 55, 40),
    Accent     = Color(205, 170, 120),
    Text       = Color(240, 235, 225),
    TextDim    = Color(170, 160, 145),
    BarBack    = Color(40, 34, 28),
    Good       = Color(120, 220, 120),
    Warn       = Color(235, 190, 80),
    Bad        = Color(235, 90, 80),
    Water      = Color(100, 170, 255),
}
