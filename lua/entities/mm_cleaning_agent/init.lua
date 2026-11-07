AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MM = MushroomMania

local TICK = 0.1

-- Liquid only ever goes down. Pocketing / re-creating the bottle must not refill it:
--   - restored network vars keep the old amount (restored = true)
--   - MM_Liquid mirrors it in the entity table, which the DarkRP pocket merges back
--     after Spawn; Think clamps to it in case the network var was reset
function ENT:OnInitialize(cfg, restored)
    if not restored then self:SetLiquid(cfg.Liquid) end
    self.MM_Liquid = self:GetLiquid()
end

function ENT:SetLiquidLeft(v)
    self.MM_Liquid = v
    self:SetLiquid(v)
end

function ENT:Think()
    local cfg = self:GetConfig()

    if self.MM_Liquid and self:GetLiquid() > self.MM_Liquid then
        self:SetLiquid(self.MM_Liquid)
    end
    -- Empty bottles disappear after 2s (also catches one that was pocketed while empty)
    if self:GetLiquid() <= 0 and cfg.RemoveWhenEmpty then
        self.MM_RemoveAt = self.MM_RemoveAt or CurTime() + 2
        if CurTime() >= self.MM_RemoveAt then
            self:Remove()
            return
        end
    end

    local pouring = self:GetLiquid() > 0 and self:GetTilt() >= cfg.PourAngle and self:WaterLevel() < 2
    if pouring ~= self:GetPouring() then self:SetPouring(pouring) end

    if pouring then
        self:SetLiquidLeft(math.max(0, self:GetLiquid() - TICK))

        local tr = self:TraceStream()
        local tub = tr.Entity
        if IsValid(tub) and tub:GetClass() == "mm_monotub" then
            tub:AddCleaning(TICK, MM.GetHandler(self))
        end

        if self:GetLiquid() <= 0 then self:SetPouring(false) end
    end

    self:NextThink(CurTime() + TICK)
    return true
end
