include("shared.lua")

local MM = MushroomMania

function ENT:Draw()
    self:DrawModel()
end

-- Bottom-centre of the label: just above the entity's world bounds
function ENT:GetLabelPos()
    local mins, maxs = self:WorldSpaceAABB()
    local c = (mins + maxs) * 0.5
    return Vector(c.x, c.y, maxs.z + (self.LabelOffset or 6))
end

function ENT:DrawTranslucent()
    -- ENT:GetGlow() returns a species Glow table (or nil) to draw a soft halo
    local glow = self.GetGlow and self:GetGlow()
    if glow then MM.DrawGlow(self, glow) end

    if self.DrawEffects then self:DrawEffects() end
    if not self.GetLabel then return end

    local maxDist = self:GetConfig().LabelDistance or 300
    local pos = self:GetLabelPos()
    if EyePos():DistToSqr(pos) > maxDist * maxDist then return end

    local title, lines, accent = self:GetLabel()
    if title then MM.DrawLabel(pos, title, lines, maxDist, accent) end
end
