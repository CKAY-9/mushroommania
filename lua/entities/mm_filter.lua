--[[
    Mushroom Mania - Filter
    Drop into a MonoTub (max 2). Health transfers to the tub's filter slot.
]]
AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "mm_base"
ENT.PrintName = "Filter"
ENT.Category  = "Mushroom Mania"
ENT.Spawnable = true
ENT.ConfigKey = "Filter"
ENT.MMKind    = "filter"

function ENT:SetupVars()
    self:NetworkVar("Float", 0, "FilterHealth")
end

if SERVER then
    function ENT:OnInitialize(cfg)
        self:SetFilterHealth(cfg.Health)
    end
    return
end

function ENT:GetLabel()
    local T, cfg = MushroomMania.Config.Theme, self:GetConfig()
    local hp = self:GetFilterHealth()
    return "Filter", {
        { bar = hp / cfg.Health, text = string.format("Health %ds", math.ceil(hp)), color = T.Good },
        { text = "Drop into a MonoTub" },
    }
end
