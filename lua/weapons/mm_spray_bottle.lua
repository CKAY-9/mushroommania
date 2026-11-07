--[[
    Mushroom Mania - Spray Bottle
    Primary fire: mist the MonoTub you're aiming at (+humidity).
    Placeholder models: bugbait (it squeezes, close enough for now).
]]
AddCSLuaFile()

SWEP.PrintName    = "Spray Bottle"
SWEP.Author       = "Mushroom Mania"
SWEP.Category     = "Mushroom Mania"
SWEP.Instructions = "Primary: mist a MonoTub"
SWEP.Spawnable    = true

SWEP.ViewModel    = "models/weapons/c_bugbait.mdl"
SWEP.WorldModel   = "models/weapons/w_bugbait.mdl"
SWEP.ViewModelFOV = 54
SWEP.UseHands     = true
SWEP.HoldType     = "pistol"

SWEP.Slot         = 1
SWEP.SlotPos      = 5
SWEP.DrawAmmo     = false
SWEP.DrawCrosshair = true

local MM = MushroomMania
local WATER = MM.Config.SprayBottle.Water

-- Water lives in the primary clip so DarkRP's /drop keeps it (it saves Clip1 on the
-- dropped weapon and restores it on pickup). Water = 0 means infinite: no clip.
-- The "mm_water" ammo type is registered in sh_core.lua.

SWEP.Primary.ClipSize    = WATER > 0 and WATER or -1
SWEP.Primary.DefaultClip = WATER > 0 and WATER or -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = WATER > 0 and "mm_water" or "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "IdleAt")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

-- No reloading: an empty bottle stays empty
function SWEP:Reload() end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_DRAW)
    self:SetIdleAt(CurTime() + 0.5)
    return true
end

function SWEP:HasWater()
    return WATER <= 0 or self:Clip1() > 0
end

function SWEP:GetTarget()
    local owner = self:GetOwner()
    local tr = util.TraceLine({
        start  = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * MM.Config.SprayBottle.Range,
        filter = owner,
    })
    local ent = tr.Entity
    if IsValid(ent) and ent:GetClass() == "mm_monotub" then return ent, tr end
    return nil, tr
end

function SWEP:PrimaryAttack()
    local cfg = MM.Config.SprayBottle
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:SetNextPrimaryFire(CurTime() + cfg.Delay)

    if not self:HasWater() then
        local snd = MM.Config.Sounds.SprayEmpty
        if snd ~= "" then self:EmitSound(snd, 60) end
        return
    end

    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK) -- bugbait "squeeze"
    self:SetIdleAt(CurTime() + 0.6)
    owner:SetAnimation(PLAYER_ATTACK1)

    local snd = MM.Config.Sounds.Spray
    if snd ~= "" then self:EmitSound(snd, 60, math.random(115, 130)) end

    if IsFirstTimePredicted() then
        local ang = owner:EyeAngles()
        local fx = EffectData()
        fx:SetOrigin(owner:GetShootPos() + ang:Forward() * 18 + ang:Right() * 5 - ang:Up() * 4)
        fx:SetNormal(owner:GetAimVector())
        util.Effect("mm_mist", fx)
    end

    if WATER > 0 then self:TakePrimaryAmmo(1) end -- predicted on both realms

    if SERVER then
        local tub = self:GetTarget()
        if tub then
            local ok, reason = tub:Spray(cfg.HumidityPerSpray)
            if not ok and reason then MM.Notify(owner, reason, 3) end
        end
    end
end

function SWEP:SecondaryAttack() end

function SWEP:Think()
    local idleAt = self:GetIdleAt()
    if idleAt > 0 and CurTime() >= idleAt then
        self:SetIdleAt(0)
        self:SendWeaponAnim(ACT_VM_IDLE)
    end
end

if SERVER then return end

function SWEP:DrawHUD()
    local cfg, T = MM.Config.SprayBottle, MM.Config.Theme
    local w, h = 260, 22
    local x, y = ScrW() / 2 - w / 2, ScrH() - 140

    if WATER > 0 then
        local water = math.max(0, self:Clip1())
        MM.DrawBar(x, y, w, h, water / WATER, T.Water, string.format("Water %d / %d", water, WATER), "MM.HUD")
    end

    local tub = self:GetTarget()
    if tub and tub:GetState() == MM.TUB_GROWING then
        local hum = tub:GetHumidity()
        local ok = hum >= tub:GetRule("IdealMin") and hum <= tub:GetRule("IdealMax")
        local band = MM.SpeciesRule(tub:GetSpeciesData(), "PerfectHumidity")
        if ok and band and not tub:PerfectLost() then ok = hum >= band[1] and hum <= band[2] end
        MM.DrawBar(x, y - h - 8, w, h, hum / 100, ok and T.Water or T.Warn,
            string.format("Tub humidity %d%%", math.floor(hum)), "MM.HUD")
    end
end
