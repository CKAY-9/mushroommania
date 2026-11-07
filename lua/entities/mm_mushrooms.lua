--[[
    Mushroom Mania - Mushroom batch
    Spawned by harvesting a MonoTub (raw) or collecting from a Food Drier (dried).
    Sold to a Mushroom Enthusiast.
]]
AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "mm_base"
ENT.PrintName = "Mushrooms"
ENT.Category  = "Mushroom Mania"
ENT.Spawnable = false
ENT.ConfigKey = "Mushrooms"
ENT.MMKind    = "mushrooms"

local MM = MushroomMania

function ENT:SetupVars()
    self:NetworkVar("String", 0, "Species")
    self:NetworkVar("Int", 0, "Quality")
    self:NetworkVar("Int", 1, "Amount")
    self:NetworkVar("Bool", 0, "Dried")
end

function ENT:GetValue()
    return MM.BatchValue(self:GetSpecies(), self:GetQuality(), self:GetAmount(), self:GetDried())
end

if SERVER then
    function ENT:UpdateColor()
        local cfg = self:GetConfig()
        self:SetColor((self:GetDried() and cfg.DriedColor or cfg.Color) or color_white)
    end

    -- Call after Spawn()
    function ENT:SetBatch(species, quality, amount, dried)
        self:SetSpecies(species)
        self:SetQuality(quality)
        self:SetAmount(amount)
        self:SetDried(dried and true or false)
        self:UpdateColor()
    end

    function ENT:OnInitialize(cfg)
        -- Re-created batches (pocket) keep their Dried var but lose their colour
        self:UpdateColor()
        if (cfg.DespawnTime or 0) > 0 then
            self.MM_DespawnAt = CurTime() + cfg.DespawnTime
        end
    end

    -- E eats a dose (see Config.Trip); Alt+E picks it up like before
    function ENT:Use(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if not MM.Config.Trip.Enabled or ply:KeyDown(IN_WALK) then
            return baseclass.Get("mm_base").Use(self, ply)
        end
        MM.Eat(ply, self)
    end

    function ENT:Think()
        if self.MM_DespawnAt then
            if self:IsPlayerHolding() then
                self.MM_DespawnAt = CurTime() + self:GetConfig().DespawnTime
            elseif CurTime() >= self.MM_DespawnAt then
                self:Remove()
                return
            end
        end
        self:NextThink(CurTime() + 1)
        return true
    end
    return
end

function ENT:GetGlow()
    return MM.SpeciesGlow(self:GetSpecies())
end

function ENT:GetLabel()
    local T = MM.Config.Theme
    local sp = MM.GetSpecies(self:GetSpecies())
    local q = MM.GetQuality(self:GetQuality())
    local name = sp and sp.Name or "Mushrooms"

    return name, {
        { text = self:GetDried() and "Dried" or "Raw", color = self:GetDried() and T.Accent or T.TextDim },
        { text = "Quality: " .. q.Name, color = q.Color },
        { text = string.format("%d%s  -  %s", self:GetAmount(), MM.Config.Mushrooms.Unit, MM.FormatMoney(self:GetValue())), color = T.Text },
        MM.Config.Trip.Enabled and { text = "E to eat  -  Alt+E to carry", color = T.Accent } or nil,
        MM.Config.Trip.Enabled and { text = "or bring to a Mushroom Enthusiast", color = T.TextDim } or nil,
    }, sp and sp.Color
end
