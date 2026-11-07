--[[
    Mushroom Mania - Cleaning Agent
    Tilt it (physgun rotate, or knock it over) above a MonoTub: liquid streams
    straight down from the spout and cleans the tub it lands on.
]]

ENT.Type      = "anim"
ENT.Base      = "mm_base"
ENT.PrintName = "Cleaning Agent"
ENT.Category  = "Mushroom Mania"
ENT.Spawnable = true
ENT.ConfigKey = "CleaningAgent"
ENT.Pickupable = true

local UP = Vector(0, 0, 1)

function ENT:SetupVars()
    self:NetworkVar("Float", 0, "Liquid")  -- Seconds of pouring left
    self:NetworkVar("Bool", 0, "Pouring")
end

-- Degrees away from upright
function ENT:GetTilt()
    return math.deg(math.acos(math.Clamp(self:GetUp():Dot(UP), -1, 1)))
end

function ENT:GetSpoutPos()
    local cfg = self:GetConfig()
    return self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z) + (cfg.SpoutOffset or vector_origin))
end

-- Where the stream lands
function ENT:TraceStream()
    local spout = self:GetSpoutPos()
    return util.TraceLine({
        start  = spout,
        endpos = spout - Vector(0, 0, self:GetConfig().PourRange or 160),
        filter = self,
    })
end
