--[[
    Mushroom Mania - In-game settings (client)
    Q menu > Utilities > Mushroom Mania > Settings
]]

local MM = MushroomMania
local C = MM.Config

local REQ_SYNC   = 0
local REQ_UPDATE = 1
local REQ_RESET  = 2

local settingsPanel -- the ControlPanel, once the tab has been opened
local builtAsEditor
MM.CanEdit = false  -- set by the server

local function request(action, data)
    net.Start(MM.NET_SETTINGS)
    net.WriteUInt(action, 2)
    if data then net.WriteTable(data) end
    net.SendToServer()
end

hook.Add("InitPostEntity", "MushroomMania.Settings", function()
    request(REQ_SYNC)
end)

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------
local function section(parent, title)
    local form = vgui.Create("DForm", parent)
    form:SetName(title)
    parent:AddItem(form)
    return form
end

local function moneyField(form, label, value, onChange)
    local wang = form:NumberWang(label, nil, 0, 1e9, 0)
    wang:SetValue(value)
    wang.OnValueChanged = function(_, v) onChange(math.floor(tonumber(v) or 0)) end
    return wang
end

local function percentSlider(form, label, max, value, onChange)
    local slider = form:NumSlider(label, nil, 0, max, 0)
    slider:SetValue(math.Round(value * 100))
    slider.OnValueChanged = function(_, v) onChange(math.Round(v) / 100) end
    return slider
end

local function build(panel)
    panel:Clear()

    builtAsEditor = MM.CanEdit
    if not builtAsEditor then
        panel:Help("You don't have permission to change Mushroom Mania settings.")
        panel:ControlHelp("Requires the \"" .. C.Settings.Privilege .. "\" permission (" .. C.Settings.MinAccess .. " by default).")
        return
    end

    panel:Help("Changes apply to everyone once you press Save, and persist across restarts.")

    -- Working copy, sent to the server on Save
    local draft = MM.GetSettings()

    -- DarkRP -----------------------------------------------------------------
    local darkrp = section(panel, "DarkRP")
    local register = darkrp:CheckBox("Sell Mushroom Mania items in the F4 menu")
    register:SetChecked(draft.DarkRPRegister)
    register.OnChange = function(_, v) draft.DarkRPRegister = v end
    darkrp:ControlHelp("Turn off if you add the items yourself in darkrpmodification.")

    -- Strains ------------------------------------------------------------------
    local unit = C.Mushrooms.Unit
    local strains = section(panel, "Strains")
    for _, id in ipairs(MM.SpeciesIds()) do
        local sp, entry = C.Species[id], draft.Species[id]
        if entry then
            strains:Help(sp.Name)

            local grow = strains:NumberWang("Grow time (seconds)", nil, MM.MIN_GROW_TIME, MM.MAX_GROW_TIME, 0)
            grow:SetValue(entry.GrowTime)
            grow.OnValueChanged = function(_, v)
                entry.GrowTime = math.Clamp(math.floor(tonumber(v) or 0), MM.MIN_GROW_TIME, MM.MAX_GROW_TIME)
            end

            moneyField(strains, "Raw price (per " .. unit .. ")", entry.RawPrice, function(v) entry.RawPrice = v end)
            moneyField(strains, "Dried price (per " .. unit .. ")", entry.DriedPrice, function(v) entry.DriedPrice = v end)
        end
    end
    strains:ControlHelp("Prices are at 100% quality. Changing a grow time also rescales tubs already growing.")

    -- Quality value -------------------------------------------------------------
    local max = MM.MAX_MULTIPLIER * 100
    local quality = section(panel, "Quality value %")
    for i, q in ipairs(C.Qualities) do
        percentSlider(quality, q.Name .. " %", max, draft.Qualities[i] or q.Multiplier, function(v)
            draft.Qualities[i] = v
        end)
    end
    percentSlider(quality, C.Contaminated.Name .. " %", max, draft.Contaminated, function(v)
        draft.Contaminated = v
    end)
    quality:ControlHelp("Percent of the sell price paid for each quality.")

    -- Actions ----------------------------------------------------------------
    local saveBtn = panel:Button("Save")
    saveBtn.DoClick = function() request(REQ_UPDATE, table.Copy(draft)) end

    local revertBtn = panel:Button("Discard changes")
    revertBtn.DoClick = function() build(panel) end

    local resetBtn = panel:Button("Reset to config defaults")
    local armed = 0
    resetBtn.DoClick = function()
        if armed < RealTime() then
            armed = RealTime() + 3
            resetBtn:SetText("Click again to confirm reset")
            timer.Simple(3, function()
                if IsValid(resetBtn) then resetBtn:SetText("Reset to config defaults") end
            end)
            return
        end
        armed = 0
        request(REQ_RESET)
    end
end

hook.Add("PopulateToolMenu", "MushroomMania.Settings", function()
    spawnmenu.AddToolMenuOption("Utilities", "Mushroom Mania", "MushroomManiaSettings", "Settings", "", "", function(panel)
        settingsPanel = panel
        build(panel)
    end)
end)

-- Re-check permission when the menu opens (covers admin mods without CAMI events).
-- The panel is only rebuilt if the permission actually changed, so drafts survive.
hook.Add("OnSpawnMenuOpen", "MushroomMania.Settings", function()
    request(REQ_SYNC)
end)

--------------------------------------------------------------------------------
-- Sync from server
--------------------------------------------------------------------------------
net.Receive(MM.NET_SETTINGS, function()
    local canEdit = net.ReadBool()
    local before = util.TableToJSON(MM.GetSettings())

    MM.CanEdit = canEdit
    MM.ApplySettings(net.ReadTable())
    MM.SyncDarkRP()

    if not IsValid(settingsPanel) then return end
    if canEdit ~= builtAsEditor or util.TableToJSON(MM.GetSettings()) ~= before then
        build(settingsPanel)
    end
end)
