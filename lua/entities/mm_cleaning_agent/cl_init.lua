include("shared.lua")

local MM = MushroomMania

local GRAVITY  = 600
local beamMat  = Material("effects/laser1")
local dropMat  = "effects/splash2"

function ENT:GetLabel()
    local cfg, T = self:GetConfig(), MM.Config.Theme
    local frac = self:GetLiquid() / cfg.Liquid
    return "Cleaning Agent", {
        { bar = frac, text = string.format("Liquid %d%%", math.ceil(frac * 100)), color = T.Water },
        { text = self:GetPouring() and "Pouring..." or "Tilt over a MonoTub to pour",
          color = self:GetPouring() and T.Water or T.TextDim },
    }, T.Water
end

function ENT:UpdatePourSound(pouring)
    local snd = MM.Config.Sounds.Pour
    if not snd or snd == "" then return end

    if pouring then
        if not self.PourSound then self.PourSound = CreateSound(self, snd) end
        if not self.PourSound:IsPlaying() then self.PourSound:PlayEx(0.45, 120) end
    elseif self.PourSound and self.PourSound:IsPlaying() then
        self.PourSound:Stop()
    end
end

function ENT:Think()
    local pouring = self:GetPouring()
    self:UpdatePourSound(pouring)
    if not pouring then return end
    if EyePos():DistToSqr(self:GetPos()) > 1500 * 1500 then return end

    local cfg = self:GetConfig()
    local col = cfg.StreamColor
    local spout = self:GetSpoutPos()
    local tr = self:TraceStream()
    local fall = math.max(spout.z - tr.HitPos.z, 1)
    local life = math.sqrt(2 * fall / GRAVITY)

    -- Slight push in the direction the bottle is leaning
    local lean = self:GetUp()
    lean.z = 0

    self.Emitter = self.Emitter or ParticleEmitter(spout)
    self.Emitter:SetPos(spout)
    self.EmitAccum = (self.EmitAccum or 0) + FrameTime() * cfg.StreamRate

    while self.EmitAccum >= 1 do
        self.EmitAccum = self.EmitAccum - 1
        local p = self.Emitter:Add(dropMat, spout + VectorRand() * 0.4)
        if p then
            p:SetVelocity(lean * 4 + VectorRand() * 1.5)
            p:SetGravity(Vector(0, 0, -GRAVITY))
            p:SetDieTime(life)
            p:SetStartAlpha(col.a)
            p:SetEndAlpha(col.a * 0.7)
            p:SetStartSize(math.Rand(1, 1.6))
            p:SetEndSize(0.8)
            p:SetRoll(math.Rand(0, 360))
            p:SetColor(col.r, col.g, col.b)
        end
    end

    -- Splash where the stream lands
    if tr.Hit and CurTime() >= (self.NextSplash or 0) then
        self.NextSplash = CurTime() + 0.05
        for _ = 1, 2 do
            local p = self.Emitter:Add(dropMat, tr.HitPos + tr.HitNormal)
            if p then
                p:SetVelocity(tr.HitNormal * math.Rand(20, 50) + VectorRand() * 25)
                p:SetGravity(Vector(0, 0, -GRAVITY))
                p:SetDieTime(math.Rand(0.15, 0.3))
                p:SetStartAlpha(col.a)
                p:SetEndAlpha(0)
                p:SetStartSize(1)
                p:SetEndSize(0.4)
                p:SetColor(col.r, col.g, col.b)
            end
        end
    end
end

-- Faint continuous beam so the stream reads as liquid, not just droplets
function ENT:DrawEffects()
    if not self:GetPouring() then return end
    local cfg = self:GetConfig()
    local col = cfg.StreamColor
    local spout = self:GetSpoutPos()
    local tr = self:TraceStream()

    render.SetMaterial(beamMat)
    render.DrawBeam(spout, tr.HitPos, 1.2, 0, 1, Color(col.r, col.g, col.b, col.a * 0.6))
end

function ENT:OnRemove()
    if self.PourSound then self.PourSound:Stop() end
    if self.Emitter then self.Emitter:Finish() self.Emitter = nil end
end
