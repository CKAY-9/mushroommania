--[[
    Mushroom Mania - MonoTub
    The grow container. Accepts (by touch): substrate, filters, liquid culture.
    Cleaned by pouring a Cleaning Agent on it, misted with the Spray Bottle.
]]

ENT.Type      = "anim"
ENT.Base      = "mm_base"
ENT.PrintName = "MonoTub"
ENT.Category  = "Mushroom Mania"
ENT.Spawnable = true
ENT.ConfigKey = "MonoTub"

local MM = MushroomMania

ENT.MaxFilterSlots = 4 -- Networked filter slots (Config.Filter.MaxPerTub is clamped to this)

function ENT:SetupVars()
    self:NetworkVar("Int", 0, "State")
    self:NetworkVar("Int", 1, "Uses")
    self:NetworkVar("Int", 2, "Filters")

    for i = 1, self.MaxFilterSlots do
        self:NetworkVar("Float", i - 1, "FilterHP" .. i)
    end
    local f = self.MaxFilterSlots
    self:NetworkVar("Float", f + 0, "Humidity")    -- 0..100
    self:NetworkVar("Float", f + 1, "Clean")       -- 0..1
    self:NetworkVar("Float", f + 2, "Progress")    -- 0..1
    self:NetworkVar("Float", f + 3, "Score")       -- 0..100, maps to a quality
    self:NetworkVar("Float", f + 4, "Unfiltered")  -- Seconds grown without a filter
    self:NetworkVar("Float", f + 5, "PerfectMiss") -- Seconds spent outside the species' PerfectHumidity band

    self:NetworkVar("Bool", 0, "Contaminated")
    self:NetworkVar("String", 0, "Species")
end

function ENT:GetFilterHP(i)
    local fn = self["GetFilterHP" .. i]
    return fn and fn(self) or 0
end

function ENT:MaxFilters()
    return math.Clamp(MM.Config.Filter.MaxPerTub or 2, 0, self.MaxFilterSlots)
end

function ENT:GetSpeciesData()
    return MM.GetSpecies(self:GetSpecies())
end

function ENT:GetGrowTime()
    local sp = self:GetSpeciesData()
    return sp and sp.GrowTime or 360
end

-- Grow rule for the species in this tub (falls back to C.Grow / C.Filter)
function ENT:GetRule(key)
    return MM.SpeciesRule(self:GetSpeciesData(), key)
end

-- True once the grow has spent too long outside the species' PerfectHumidity band
function ENT:PerfectLost()
    local sp = self:GetSpeciesData()
    if not sp or not sp.PerfectHumidity then return false end
    return self:GetPerfectMiss() > (sp.PerfectGrace or 0)
end

-- Quality index the tub would give if harvested now
function ENT:GetCurrentQuality()
    if self:GetContaminated() then return MM.QUALITY_CONTAMINATED end
    local q = MM.ScoreToQuality(self:GetScore())
    -- Qualities are best-first, so losing Perfect caps the grow at the second tier
    if q == 1 and #MM.Config.Qualities > 1 and self:PerfectLost() then q = 2 end
    return q
end

function ENT:GetHint()
    local s = self:GetState()
    if s == MM.TUB_EMPTY then return "This MonoTub needs substrate." end
    if s == MM.TUB_SUBSTRATE then
        local skip = {}
        for _, id in ipairs(MM.SpeciesIds()) do
            local sp = MM.GetSpecies(id)
            if not MM.NeedsCleaning(sp) then skip[#skip + 1] = sp.Short or sp.Name end
        end
        local hint = "Tilt a Cleaning Agent over the MonoTub to clean it."
        if #skip > 0 then hint = hint .. " (" .. table.concat(skip, ", ") .. " can go straight in.)" end
        return hint
    end
    if s == MM.TUB_CLEAN then return "Drop a liquid culture into the MonoTub." end
    if s == MM.TUB_GROWING then return "Still growing. Keep it misted and the filters fresh." end
    return "Press E to harvest."
end
