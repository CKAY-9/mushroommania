include("shared.lua")

local MM = MushroomMania

function ENT:GetLabelPos()
    local bone = self:LookupBone("ValveBiped.Bip01_Head1")
    local pos = bone and self:GetBonePosition(bone)
    if not pos or pos == self:GetPos() then pos = self:GetPos() + Vector(0, 0, 64) end
    return pos + Vector(0, 0, 14)
end

function ENT:GetLabel()
    local T = MM.Config.Theme
    local lines = {}
    local left = MM.GetRejectTime(LocalPlayer())
    if left > 0 then
        lines[1] = { text = "Won't deal with you: " .. MM.FormatTime(left), color = T.Bad }
    else
        lines[1] = { text = "Press E to sell nearby mushrooms", color = T.Text }
        lines[2] = { text = "Dried mushrooms sell for more" }
    end
    return "Mushroom Enthusiast", lines
end
