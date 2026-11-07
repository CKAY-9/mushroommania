include("shared.lua")

local MM = MushroomMania

function ENT:GetGlow()
    -- Contents only change on load / collect, so cache by the networked string
    local contents = self:GetContents()
    if contents ~= self.MM_GlowFor then
        self.MM_GlowFor = contents
        self.MM_Glow = nil
        for _, b in ipairs(self:GetContentsList()) do
            local glow = MM.SpeciesGlow(b.species)
            if glow then self.MM_Glow = glow break end
        end
    end
    return self.MM_Glow
end

function ENT:GetLabel()
    local T = MM.Config.Theme
    local unit = MM.Config.Mushrooms.Unit
    local state = self:GetState()
    local stored, cap = self:GetStored(), self:Capacity()
    local lines = {}
    local function add(line) lines[#lines + 1] = line end

    -- Status
    if state == self.DRYING then
        add{ text = "Status: Drying", color = T.Warn }
    elseif state == self.DONE then
        add{ text = "Status: Done - Press E to collect", color = T.Good }
    elseif stored > 0 then
        add{ text = "Status: Loaded - Press E to start", color = T.Text }
    else
        add{ text = "Status: Empty" }
    end

    -- Storage
    add{ bar = stored / cap, color = T.Accent, text = string.format("Storage %d / %d%s", stored, cap, unit) }

    -- Time left
    if state == self.DRYING then
        add{ bar = self:GetDryFraction(), color = T.Warn, text = "Time left " .. MM.FormatTime(self:GetTimeLeft()) }
    elseif state == self.IDLE and stored > 0 then
        add{ text = "Dries in " .. MM.FormatTime(self:GetConfig().DryTime or 120) }
    end

    -- Contents
    for _, b in ipairs(self:GetContentsList()) do
        local sp = MM.GetSpecies(b.species)
        local q = MM.GetQuality(b.quality)
        add{ text = string.format("%s %d%s (%s)%s", sp and sp.Short or b.species, b.grams, unit, q.Name,
            state == self.DONE and " - Dried" or ""), color = q.Color }
    end

    if state == self.IDLE and stored < cap then
        add{ text = "Drop raw mushrooms on top" }
    end

    return "Food Drier", lines
end

--------------------------------------------------------------------------------
-- Vent smoke / heat shimmer while drying
--------------------------------------------------------------------------------
local smokeMat = "particle/particle_smokegrenade"
local heatMat  = "sprites/heatwave"

function ENT:EmitVentParticle(fx, isHeat)
    local origin = self:LocalToWorld(fx.Offset)
    local dir = self:LocalToWorld(fx.Direction) - self:GetPos()
    dir:Normalize()

    local size = fx.Size or vector_origin
    local spread = self:LocalToWorld(Vector(
        math.Rand(-0.5, 0.5) * size.x,
        math.Rand(-0.5, 0.5) * size.y,
        math.Rand(-0.5, 0.5) * size.z)) - self:GetPos()

    local p = self.VentEmitter:Add(isHeat and heatMat or smokeMat, origin + spread)
    if not p then return end

    p:SetRoll(math.Rand(0, 360))
    p:SetRollDelta(math.Rand(-0.5, 0.5))
    p:SetAirResistance(40)

    if isHeat then
        p:SetVelocity(dir * math.Rand(10, 16) + Vector(0, 0, math.Rand(4, 8)))
        p:SetGravity(Vector(0, 0, 18))
        p:SetDieTime(math.Rand(0.6, 1))
        p:SetStartAlpha(255)
        p:SetEndAlpha(0)
        p:SetStartSize(math.Rand(2, 3))
        p:SetEndSize(math.Rand(6, 9))
    else
        local col = fx.SmokeColor or color_white
        p:SetVelocity(dir * math.Rand(12, 22) + VectorRand() * 2)
        p:SetGravity(Vector(0, 0, math.Rand(10, 16))) -- Warm air rises
        p:SetDieTime(math.Rand(1.6, 2.6))
        p:SetStartAlpha(fx.SmokeAlpha or 22)
        p:SetEndAlpha(0)
        p:SetStartSize(math.Rand(1.5, 3))
        p:SetEndSize(math.Rand(10, 15))
        p:SetColor(col.r, col.g, col.b)
    end
end

function ENT:Think()
    local fx = self:GetConfig().VentEffect
    if not fx or not fx.Enabled or self:GetState() ~= self.DRYING or self:IsDormant()
        or EyePos():DistToSqr(self:GetPos()) > (fx.Distance or 1200) ^ 2 then
        self.SmokeAccum, self.HeatAccum = 0, 0
        return
    end

    local pos = self:LocalToWorld(fx.Offset)
    self.VentEmitter = self.VentEmitter or ParticleEmitter(pos)
    self.VentEmitter:SetPos(pos)

    local ft = FrameTime()
    self.SmokeAccum = (self.SmokeAccum or 0) + ft * (fx.SmokeRate or 0)
    self.HeatAccum  = (self.HeatAccum or 0) + ft * (fx.HeatRate or 0)

    while self.SmokeAccum >= 1 do
        self.SmokeAccum = self.SmokeAccum - 1
        self:EmitVentParticle(fx, false)
    end
    while self.HeatAccum >= 1 do
        self.HeatAccum = self.HeatAccum - 1
        self:EmitVentParticle(fx, true)
    end
end

function ENT:OnRemove()
    if self.VentEmitter then self.VentEmitter:Finish() self.VentEmitter = nil end
end
