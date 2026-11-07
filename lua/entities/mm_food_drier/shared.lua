--[[
    Mushroom Mania - Food Drier
    1. Drop raw mushroom batches on it (up to Config.FoodDrier.Capacity grams)
    2. Press E to start a drying cycle (loud - nearby players can hear it)
    3. After Config.FoodDrier.DryTime seconds, press E to collect dried batches
]]

ENT.Type      = "anim"
ENT.Base      = "mm_base"
ENT.PrintName = "Food Drier"
ENT.Category  = "Mushroom Mania"
ENT.Spawnable = true
ENT.ConfigKey = "FoodDrier"

local MM = MushroomMania

-- States
ENT.IDLE   = 0 -- Loading (may be empty)
ENT.DRYING = 1
ENT.DONE   = 2 -- Waiting to be collected

function ENT:SetupVars()
    self:NetworkVar("Int", 0, "State")
    self:NetworkVar("Int", 1, "Stored")      -- Grams inside
    self:NetworkVar("Float", 0, "DryStart")
    self:NetworkVar("Float", 1, "DryEnd")
    self:NetworkVar("String", 0, "Contents") -- "species|quality|grams;..." for the label
end

function ENT:Capacity()
    return math.max(1, self:GetConfig().Capacity or 50)
end

-- Contents as { { species, quality, grams }, ... }
function ENT:GetContentsList()
    local out = {}
    for species, quality, grams in string.gmatch(self:GetContents(), "([^|;]+)|(%-?%d+)|(%d+)") do
        out[#out + 1] = { species = species, quality = tonumber(quality), grams = tonumber(grams) }
    end
    return out
end

function ENT:GetTimeLeft()
    return math.max(0, self:GetDryEnd() - CurTime())
end

function ENT:GetDryFraction()
    local total = self:GetDryEnd() - self:GetDryStart()
    if total <= 0 then return 0 end
    return math.Clamp((CurTime() - self:GetDryStart()) / total, 0, 1)
end

function ENT:GetHint()
    local state = self:GetState()
    if state == self.DRYING then
        return "Drying... " .. MM.FormatTime(self:GetTimeLeft()) .. " left."
    elseif state == self.DONE then
        return "Press E to collect the dried mushrooms."
    elseif self:GetStored() > 0 then
        return "Press E to start drying."
    end
    return "Drop raw mushrooms onto the Food Drier to load it."
end
