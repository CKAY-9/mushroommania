AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MM = MushroomMania

function ENT:Initialize()
    local cfg = self:GetConfig()

    self:SetModel(self:GetModelPath())
    if cfg.Color then self:SetColor(cfg.Color) end
    if cfg.Material and cfg.Material ~= "" then self:SetMaterial(cfg.Material) end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if not IsValid(phys) then
        -- Model has no collision mesh: fall back to its bounding box
        self:PhysicsInitBox(self:OBBMins(), self:OBBMaxs())
        phys = self:GetPhysicsObject()
    end
    if IsValid(phys) then phys:Wake() end

    if (cfg.Health or 0) > 0 then
        self:SetMaxHealth(cfg.Health)
        self:SetHealth(cfg.Health)
    end

    local restored = self:GetMMInitialized()
    self:SetMMInitialized(true)
    if self.OnInitialize then self:OnInitialize(cfg, restored) end
end

-- Small items: E picks them up like a prop
function ENT:Use(ply)
    if (self.MMKind or self.Pickupable) and IsValid(ply) and ply:IsPlayer() and not self:IsPlayerHolding() then
        ply:PickupObject(self)
        self.MM_LastHolder = ply
    end
end

function ENT:OnTakeDamage(dmg)
    self:TakePhysicsDamage(dmg)

    if (self:GetConfig().Health or 0) <= 0 or self.MM_Destroyed then return end
    self:SetHealth(self:Health() - dmg:GetDamage())
    if self:Health() <= 0 then
        self.MM_Destroyed = true
        local fx = EffectData()
        fx:SetOrigin(self:WorldSpaceCenter())
        fx:SetMagnitude(2)
        util.Effect("Sparks", fx)
        self:Remove()
    end
end

-- Combining: offer this item to whatever receiver it bumps into
function ENT:PhysicsCollide(data)
    if not self.MMKind or self.MM_Used then return end

    local other = data.HitEntity
    if not IsValid(other) or not other.MM_Receive then return end

    local now = CurTime()
    if (self.MM_NextCombine or 0) > now then return end
    self.MM_NextCombine = now + 0.5

    -- Entities can't be removed safely inside a physics callback
    timer.Simple(0, function()
        if not IsValid(self) or not IsValid(other) or self.MM_Used then return end
        local ok, reason = other:MM_Receive(self, MM.GetHandler(self))
        if ok then
            self.MM_Used = true
            self:Remove()
        elseif reason and MM.IsBeingHandled(self) then
            -- Only explain rejections to someone actively handling the item
            MM.Notify(MM.GetHandler(self), reason, 1)
        end
    end)
end
