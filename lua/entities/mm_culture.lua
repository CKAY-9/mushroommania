--[[
    Mushroom Mania - Liquid Culture (base)
    Not spawned directly: one "mm_culture_<species>" class is registered per
    entry in MushroomMania.Config.Species (see sh_core.lua). ENT.Species is set there.
]]
AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "mm_base"
ENT.PrintName = "Liquid Culture"
ENT.Category  = "Mushroom Mania"
ENT.Spawnable = false
ENT.ConfigKey = "Culture"
ENT.MMKind    = "culture"
ENT.Species   = nil

function ENT:GetSpecies()
    return MushroomMania.GetSpecies(self.Species or "")
end

function ENT:GetModelPath()
    local sp = self:GetSpecies()
    return (sp and sp.CultureModel) or self:GetConfig().Model
end

-- Per-species vial tint so cultures are easy to tell apart
function ENT:GetCultureColor()
    local sp = self:GetSpecies()
    return (sp and (sp.CultureColor or sp.Color)) or self:GetConfig().Color
end

if SERVER then
    function ENT:OnInitialize()
        local col = self:GetCultureColor()
        if col then self:SetColor(col) end
    end
    return
end

function ENT:GetGlow()
    return MushroomMania.SpeciesGlow(self.Species)
end

function ENT:GetLabel()
    local sp = self:GetSpecies()
    if not sp then return "Unknown Culture" end
    local MM, T = MushroomMania, MushroomMania.Config.Theme
    local lines = {
        { text = "Liquid Culture", color = sp.Color },
        { text = "Grows in " .. MM.FormatTime(sp.GrowTime) },
    }
    if MM.NeedsCleaning(sp) then
        lines[#lines + 1] = { text = "Drop into a cleaned MonoTub" }
    else
        lines[#lines + 1] = { text = "Drop into a MonoTub with substrate", color = T.Good }
    end
    if not MM.NeedsFilters(sp) then
        lines[#lines + 1] = { text = "No filters needed", color = T.Good }
    elseif MM.SpeciesRule(sp, "UnfilteredContaminateTime") <= 0 then
        lines[#lines + 1] = { text = "Contaminates instantly without a filter", color = T.Bad }
    end
    if sp.PerfectHumidity then
        lines[#lines + 1] = { text = string.format("%s needs %d-%d%% humidity", MM.Config.Qualities[1].Name,
            sp.PerfectHumidity[1], sp.PerfectHumidity[2]), color = T.Warn }
    end
    return sp.Name, lines, sp.Color
end
