--[[
    Mushroom Mania - Spray Bottle mist puff
    data:GetOrigin() = nozzle, data:GetNormal() = spray direction
]]

local MAT = "particle/particle_smokegrenade"

function EFFECT:Init(data)
    local pos, dir = data:GetOrigin(), data:GetNormal()
    local emitter = ParticleEmitter(pos)
    if not emitter then return end

    for _ = 1, 16 do
        local p = emitter:Add(MAT, pos)
        if p then
            p:SetVelocity(dir * math.Rand(90, 170) + VectorRand() * 18)
            p:SetAirResistance(160)
            p:SetGravity(Vector(0, 0, -30))
            p:SetDieTime(math.Rand(0.5, 0.9))
            p:SetStartAlpha(70)
            p:SetEndAlpha(0)
            p:SetStartSize(1)
            p:SetEndSize(math.Rand(6, 11))
            p:SetRoll(math.Rand(0, 360))
            p:SetRollDelta(math.Rand(-1, 1))
            p:SetColor(225, 238, 255)
        end
    end
    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end
