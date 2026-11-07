--[[
    Mushroom Mania - Shared core
]]

local MM = MushroomMania

-- MonoTub states
MM.TUB_EMPTY     = 0 -- Needs substrate
MM.TUB_SUBSTRATE = 1 -- Needs cleaning
MM.TUB_CLEAN     = 2 -- Needs liquid culture
MM.TUB_GROWING   = 3
MM.TUB_READY     = 4

-- Quality index 0 is contaminated, 1..n index C.Qualities
MM.QUALITY_CONTAMINATED = 0

-- Spray Bottle water is stored in its clip (see weapons/mm_spray_bottle.lua).
-- Ammo types must be added before the gamemode initialises, so it happens here.
game.AddAmmoType({ name = "mm_water", maxcarry = 0 })

--------------------------------------------------------------------------------
-- Species
--------------------------------------------------------------------------------
function MM.GetSpecies(id)
    return MM.Config.Species[id]
end

-- Species ids sorted by their Order field (then id), for menus
function MM.SpeciesIds()
    local species = MM.Config.Species
    local ids = table.GetKeys(species)
    table.sort(ids, function(a, b)
        local oa, ob = species[a].Order or math.huge, species[b].Order or math.huge
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return ids
end

-- A grow rule for a species: its own field if set, otherwise the C.Grow / C.Filter default
function MM.SpeciesRule(sp, key)
    if sp and sp[key] ~= nil then return sp[key] end
    local G = MM.Config.Grow
    if G[key] ~= nil then return G[key] end
    return MM.Config.Filter[key]
end

function MM.NeedsFilters(sp)  return not sp or sp.NeedsFilters ~= false end
function MM.NeedsCleaning(sp) return not sp or sp.NeedsCleaning ~= false end

function MM.CultureClass(id)
    return "mm_culture_" .. id
end

-- Every species gets its own liquid culture entity so it can be sold / spawned separately
local function registerCultures()
    for id, sp in pairs(MM.Config.Species) do
        local ENT = {
            Type      = "anim",
            Base      = "mm_culture",
            PrintName = sp.Name .. " Culture",
            Category  = "Mushroom Mania",
            Spawnable = true,
            Species   = id,
        }
        scripted_ents.Register(ENT, MM.CultureClass(id))
    end
end
registerCultures()

--------------------------------------------------------------------------------
-- Quality & value
--------------------------------------------------------------------------------
function MM.GetQuality(idx)
    if idx == MM.QUALITY_CONTAMINATED then return MM.Config.Contaminated end
    return MM.Config.Qualities[idx] or MM.Config.Qualities[#MM.Config.Qualities]
end

function MM.ScoreToQuality(score)
    local list = MM.Config.Qualities
    for i, q in ipairs(list) do
        if score >= q.MinScore then return i end
    end
    return #list
end

function MM.UnitPrice(speciesId, dried)
    local sp = MM.GetSpecies(speciesId)
    if not sp then return 0 end
    return dried and sp.DriedPrice or sp.RawPrice
end

function MM.BatchValue(speciesId, quality, amount, dried)
    return math.floor(MM.UnitPrice(speciesId, dried) * amount * MM.GetQuality(quality).Multiplier)
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
function MM.FormatMoney(n)
    if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(n) end
    return "$" .. string.Comma(n)
end

function MM.FormatTime(s)
    s = math.max(0, math.ceil(s))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

function MM.GetOwner(ent)
    if not IsValid(ent) then return end
    if ent.Getowning_ent then
        local o = ent:Getowning_ent()
        if IsValid(o) then return o end
    end
    if ent.CPPIGetOwner then
        local o = ent:CPPIGetOwner()
        if IsValid(o) then return o end
    end
end

local function resolveTeam(job)
    if isnumber(job) then return job end
    return _G[job]
end
MM.ResolveTeam = resolveTeam

-- Seconds left until the Mushroom Enthusiasts deal with this player again
function MM.GetRejectTime(ply)
    return math.max(0, ply:GetNWFloat("MM_RejectUntil", 0) - CurTime())
end

-- Returns false + reason if the player's job may not sell
function MM.CanSell(ply)
    local cfg = MM.Config.Enthusiast
    if not cfg.AllowPolice and ply.isCP and ply:isCP() then
        return false, "I don't deal with cops."
    end
    for _, job in ipairs(cfg.BlockedJobs or {}) do
        local t = resolveTeam(job)
        if t and ply:Team() == t then
            return false, "I don't deal with people like you."
        end
    end
    local left = MM.GetRejectTime(ply)
    if left > 0 then
        return false, "You sold me contaminated junk. Come back in " .. MM.FormatTime(left) .. "."
    end
    return true
end

--------------------------------------------------------------------------------
-- DarkRP F4 registration
--------------------------------------------------------------------------------
local function resolveAllowed()
    local jobs = MM.Config.Shop.AllowedJobs
    if not jobs or #jobs == 0 then return nil end
    local out = {}
    for _, job in ipairs(jobs) do
        local t = resolveTeam(job)
        if t then
            out[#out + 1] = t
        else
            ErrorNoHalt("[Mushroom Mania] Unknown job in Shop.AllowedJobs: " .. tostring(job) .. "\n")
        end
    end
    return out
end

-- Model shown in the F4 menu for a class
local function shopModel(class)
    local map = {
        mm_monotub        = "MonoTub",
        mm_filter         = "Filter",
        mm_substrate      = "Substrate",
        mm_cleaning_agent = "CleaningAgent",
        mm_food_drier     = "FoodDrier",
    }
    local key = map[class]
    if key then return MM.Config[key].Model end
    if class == "mm_spray_bottle" then return "models/weapons/w_bugbait.mdl" end
    return MM.Config.Culture.Model
end

function MM.ShopItems()
    local items = {}
    for _, item in ipairs(MM.Config.Shop.Items) do
        items[#items + 1] = item
    end
    -- Liquid cultures from the species table (sorted for a stable F4 order)
    for _, id in ipairs(MM.SpeciesIds()) do
        local sp = MM.Config.Species[id]
        if sp.ShopPrice then
            items[#items + 1] = {
                class = MM.CultureClass(id),
                name  = sp.Name .. " Liquid Culture",
                price = sp.ShopPrice,
                max   = sp.ShopMax or 4,
                cmd   = sp.ShopCmd or ("buy" .. id .. "culture"),
                model = sp.CultureModel,
            }
        end
    end
    return items
end

-- Registered entries are tagged with `mushroomMania = true` so we only ever
-- find (and remove) our own entries, never ones added in darkrpmodification.
local function isOurs(v) return istable(v) and v.mushroomMania end

local function findIndex(list)
    if not istable(list) then return end
    for i, v in pairs(list) do
        if isOurs(v) then return i end
    end
end

local function isRegistered()
    return findIndex(DarkRPEntities) ~= nil or findIndex(CustomShipments) ~= nil
end

local function ensureCategories()
    local S = MM.Config.Shop
    if not S.CreateCategory or not DarkRP.createCategory then return end

    local cats = DarkRP.getCategories and DarkRP.getCategories() or {}
    for _, kind in ipairs({ "entities", "weapons" }) do
        local exists = false
        for _, cat in pairs(cats[kind] or {}) do
            if cat.name == S.Category then exists = true break end
        end
        if not exists then
            DarkRP.createCategory{
                name          = S.Category,
                categorises   = kind,
                startExpanded = true,
                color         = S.CategoryColor,
                sortOrder     = S.CategorySort,
            }
        end
    end
end

local function addItems()
    local S = MM.Config.Shop
    ensureCategories()

    local allowed = resolveAllowed()
    for _, item in ipairs(MM.ShopItems()) do
        local model = item.model or shopModel(item.class)
        if item.weapon then
            DarkRP.createShipment(item.name, {
                model    = model,
                entity   = item.class,
                price    = 0,
                amount   = 1,
                separate = true,
                pricesep = item.price,
                noship   = true,
                category = S.Category,
                allowed  = allowed,
                mushroomMania = true,
            })
        else
            DarkRP.createEntity(item.name, {
                ent      = item.class,
                model    = model,
                price    = item.price,
                max      = item.max or 2,
                cmd      = item.cmd,
                category = S.Category,
                allowed  = allowed,
                mushroomMania = true,
            })
        end
    end
end

local function removeItems()
    -- Re-scan after every removal: DarkRP may shift indices
    for _ = 1, 256 do
        local i = findIndex(DarkRPEntities)
        if i then
            DarkRP.removeEntity(i)
        else
            local j = findIndex(CustomShipments)
            if not j then return end
            DarkRP.removeShipment(j)
        end
    end
end

-- Adds or removes the F4 items so they match Config.Shop.Register.
-- Safe to call at any time; does nothing until DarkRP has loaded its items.
-- Returns false if the change could not be applied live (needs a map change).
function MM.SyncDarkRP()
    if not MM._darkrpReady or not DarkRP then return true end

    local want = MM.Config.Shop.Register and true or false
    if want == isRegistered() then return true end

    local ok, err
    if want then
        if not DarkRP.createEntity or not DarkRP.createShipment then return false end
        ok, err = pcall(addItems)
    else
        if not DarkRP.removeEntity or not DarkRP.removeShipment then return false end
        ok, err = pcall(removeItems)
    end

    if not ok then
        ErrorNoHalt("[Mushroom Mania] Could not " .. (want and "add" or "remove") .. " the F4 items live: " .. tostring(err) .. "\n")
        return false
    end
    return isRegistered() == want
end

hook.Add("loadCustomDarkRPItems", "MushroomMania.Register", function()
    MM._darkrpReady = true
    MM.SyncDarkRP()
end)

-- Covers stale chat commands / menus if the items were removed live
local function blockIfDisabled(ply, item)
    if isOurs(item) and not MM.Config.Shop.Register then
        return false, false, "Mushroom Mania items aren't for sale right now."
    end
end
hook.Add("canBuyCustomEntity", "MushroomMania.Register", blockIfDisabled)
hook.Add("canBuyPistol", "MushroomMania.Register", blockIfDisabled)
hook.Add("canBuyShipment", "MushroomMania.Register", blockIfDisabled)
