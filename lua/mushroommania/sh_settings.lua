--[[
    Mushroom Mania - In-game settings (shared)
    The subset of the config that admins can edit live from the Q menu
    (Utilities > Mushroom Mania > Settings). Overrides are saved to
    data/mushroommania/settings.json and layered on top of sh_config.lua.

    Who can edit is controlled by the CAMI privilege in Config.Settings
    (ULX / SAM / serverguard etc. pick it up automatically). Without an admin
    mod it falls back to the privilege's MinAccess usergroup.
]]

local MM = MushroomMania
local C = MM.Config

MM.NET_SETTINGS = "MushroomMania.Settings"

-- Register the permission so admin mods list it (and grant it to MinAccess).
-- Admin mods like ULib load their CAMI copy *after* this addon's autorun file,
-- so this retries at gamemode Initialize, once every autorun file has run.
-- ULib denies unregistered privileges outright, so registering is required.
function MM.RegisterPrivilege()
    if MM._privilegeRegistered or not CAMI or not CAMI.RegisterPrivilege then return end
    MM._privilegeRegistered = true
    CAMI.RegisterPrivilege({
        Name        = C.Settings.Privilege,
        MinAccess   = C.Settings.MinAccess,
        Description = "Edit Mushroom Mania settings from the Q menu",
    })
end
MM.RegisterPrivilege()
hook.Add("Initialize", "MushroomMania.Privilege", MM.RegisterPrivilege)

-- Snapshot of every editable value (strain grow times, sell prices, quality values, F4 toggle)
function MM.GetSettings()
    local s = {
        DarkRPRegister = C.Shop.Register and true or false,
        Species        = {},
        Qualities      = {},
        Contaminated   = C.Contaminated.Multiplier,
    }
    for id, sp in pairs(C.Species) do
        s.Species[id] = { GrowTime = sp.GrowTime or 360, RawPrice = sp.RawPrice, DriedPrice = sp.DriedPrice }
    end
    for i, q in ipairs(C.Qualities) do
        s.Qualities[i] = q.Multiplier
    end
    return s
end

local function num(v, fallback, min, max, int)
    v = tonumber(v)
    if not v or v ~= v then return fallback end -- nil / NaN
    if int then v = math.floor(v) end
    return math.Clamp(v, min, max)
end

MM.MAX_MULTIPLIER = 5 -- 500%
MM.MIN_GROW_TIME   = 10
MM.MAX_GROW_TIME   = 24 * 60 * 60

-- Validates `s` and writes it into MM.Config. Missing keys keep their current value.
function MM.ApplySettings(s)
    if not istable(s) then return end

    if s.DarkRPRegister ~= nil then C.Shop.Register = tobool(s.DarkRPRegister) end

    if istable(s.Species) then
        for id, sp in pairs(C.Species) do
            local v = s.Species[id]
            if istable(v) then
                sp.GrowTime   = num(v.GrowTime, sp.GrowTime, MM.MIN_GROW_TIME, MM.MAX_GROW_TIME, true)
                sp.RawPrice   = num(v.RawPrice, sp.RawPrice, 0, 1e9, true)
                sp.DriedPrice = num(v.DriedPrice, sp.DriedPrice, 0, 1e9, true)
            end
        end
    end

    if istable(s.Qualities) then
        for i, q in ipairs(C.Qualities) do
            q.Multiplier = num(s.Qualities[i], q.Multiplier, 0, MM.MAX_MULTIPLIER)
        end
    end

    C.Contaminated.Multiplier = num(s.Contaminated, C.Contaminated.Multiplier, 0, MM.MAX_MULTIPLIER)
end

-- Values from sh_config.lua, before any saved overrides are applied
MM.SettingsDefaults = MM.GetSettings()
