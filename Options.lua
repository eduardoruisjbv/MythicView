-- Mythic View options panel: Game Menu > Options > AddOns > Mythic View, or /mv.
-- Built on the native Settings API; every control writes straight into
-- MythicViewDB.settings and asks the camera to re-apply.
local _, ns = ...

local settingObjects = {}
local keybindRefreshers = {}
local keybindEventFrame
local nativeInputPopup = "MYTHICVIEW_COMBAT_CONTROLS_INPUT"

if StaticPopupDialogs and not StaticPopupDialogs[nativeInputPopup] then
  StaticPopupDialogs[nativeInputPopup] = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 4096,
    OnShow = function(self)
      local data = self.data
      local value = data and data.get and data.get()
      local editBox = self.editBox or _G[self:GetName() .. "EditBox"]
      if not editBox then return end
      editBox:SetMultiLine(data and data.multiline == true)
      editBox:SetHeight(data and data.multiline and 96 or 20)
      editBox:SetText(type(value) == "string" and value or "")
      editBox:SetFocus()
      editBox:HighlightText()
    end,
    OnAccept = function(self)
      local data = self.data
      local editBox = self.editBox or _G[self:GetName() .. "EditBox"]
      if data and data.set and editBox then data.set(editBox:GetText()) end
    end,
    EditBoxOnEnterPressed = function(self)
      local parent = self:GetParent()
      local data = parent.data
      if data and data.multiline then
        self:Insert("\n")
        return
      end
      if data and data.set then data.set(self:GetText()) end
      parent:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
end

-- Lets the camera update a control it changed itself (e.g. a style switch
-- adopting that style's aim behaviour).
function ns.RefreshOptionValue(key, value)
  local setting = settingObjects[key]
  if setting and setting.GetValue and setting:GetValue() ~= value then
    setting:SetValue(value)
  end
end

function ns.OpenOptions()
  if ns.category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(ns.category:GetID())
  else
    print("|cffd9bf8cMythic View|r: menu unavailable in this game version.")
  end
end

local function RegisterCombatControlsSubcategory(parentCategory)
  if not (Settings.RegisterVerticalLayoutSubcategory and Settings.RegisterProxySetting) then
    return
  end

  local CM = ns.CombatMode
  local definitions = CM and CM.UI and CM.UI.Options and CM.UI.Options.tabDefs
  if not definitions or #definitions == 0 then
    return
  end

  local combatCategory = Settings.RegisterVerticalLayoutSubcategory(parentCategory, "Combat controls")
  ns.combatModeCategories = {}
  local combatLayout = SettingsPanel and SettingsPanel.GetLayout
      and SettingsPanel:GetLayout(combatCategory)
  local TAGS = {
    recommended = { "|cff66dd88[Recommended]|r ", "Recommended: safe default for most players." },
    optional = { "|cffe0c060[Optional]|r ", "Optional: personal preference; adjust when useful." },
    risky = { "|cffe07050[Not recommended]|r ", "Not recommended: changing this may interfere with reticle targeting." },
    advanced = { "|cffc084fc[Advanced]|r ", "Advanced: intended for users who want to customize behavior." },
  }
  local TAG_BY_LABEL = {
    ["Auto Unlock"] = "recommended",
    ["Click Casting Only"] = "recommended",
    ["Skip Self"] = "recommended",
    ["Reticle Targeting CVar Overrides"] = "risky",
    ["Custom Condition"] = "advanced",
    ["Situational Condition"] = "advanced",
  }
  local function tagFor(label, explicitTag)
    if explicitTag then return explicitTag end
    if type(label) == "string" and label:match("^Macro Preline:") then return "advanced" end
    return TAG_BY_LABEL[label] or "optional"
  end
  local function taggedLabel(label, explicitTag)
    local tag = TAGS[tagFor(label, explicitTag)] or TAGS.optional
    return tag[1] .. (label or "")
  end
  if combatLayout and CreateSettingsListSectionHeaderInitializer then
    combatLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Combat controls"))
    if CreateSettingsListTextEntryInitializer then
      combatLayout:AddInitializer(CreateSettingsListTextEntryInitializer(
        "Tags: " .. TAGS.recommended[1] .. "safe for most players   "
          .. TAGS.optional[1] .. "personal preference   "
          .. TAGS.risky[1] .. "may interfere with targeting   "
          .. TAGS.advanced[1] .. "custom behavior"
      ))
    end
  end

  local function addInitializer(layout, initializer)
    if initializer and layout and layout.AddInitializer then
      layout:AddInitializer(initializer)
    end
  end

  local function button(layout, label, action, tooltip)
    if CreateSettingsButtonInitializer then
      addInitializer(layout, CreateSettingsButtonInitializer(taggedLabel(label), "Edit", action, tooltip, true))
    end
  end

  local function addKeybind(layout, category, o)
    local action = o.action
    local bindingIndex = action and C_KeyBindings and C_KeyBindings.GetBindingIndex
        and C_KeyBindings.GetBindingIndex(action)
    if bindingIndex and CreateKeybindingEntryInitializer then
      if CreateSettingsListTextEntryInitializer then
        local tag = TAGS[tagFor(o.label, o.tag)] or TAGS.optional
        addInitializer(layout, CreateSettingsListTextEntryInitializer(tag[1]))
      end
      local initializer = CreateKeybindingEntryInitializer(bindingIndex, true)
      if initializer.AddSearchTags then initializer:AddSearchTags(o.label, taggedLabel(o.label, o.tag)) end
      addInitializer(layout, initializer)
      local ok, current = pcall(o.get)
      keybindRefreshers[#keybindRefreshers + 1] = {
        get = o.get, set = o.set, last = ok and current or nil,
      }
      if not keybindEventFrame then
        keybindEventFrame = CreateFrame("Frame")
        keybindEventFrame:RegisterEvent("UPDATE_BINDINGS")
        keybindEventFrame:SetScript("OnEvent", function()
          for _, entry in ipairs(keybindRefreshers) do
            local valid, value = pcall(entry.get)
            if valid and value ~= entry.last then
              entry.last = value
              pcall(entry.set, value)
            end
          end
        end)
      end
      return
    end
    button(layout, o.label, function()
      if SettingsPanel and SettingsPanel:IsShown() and SettingsPanel.Close then
        SettingsPanel:Close()
      end
      if KeyBindingFrame_LoadUI then KeyBindingFrame_LoadUI() end
      if KeyBindingFrame then ShowUIPanel(KeyBindingFrame) end
    end, o.desc or "Open the game's key binding controls.")
  end

  local function nativeTextEditor(layout, o, getter, setter)
    button(layout, o.label, function()
      StaticPopup_Show(nativeInputPopup, o.desc or o.label, nil, {
        get = getter or o.get,
        set = setter or o.set,
        multiline = (o.multiline or 1) > 1,
      })
    end, o.desc)
  end

  for _, def in ipairs(definitions) do
    local category, layout = Settings.RegisterVerticalLayoutSubcategory(parentCategory, def.label)
    if category and layout then
      -- Some embedded tab builders create their own frame controls before the
      -- adapter can replace them with native Settings controls. Give those
      -- builders a hidden layout host so they can finish initialization safely.
      local scratchContent = CreateFrame("Frame", nil, UIParent)
      scratchContent:SetSize(528, 1)
      scratchContent:Hide()
      local settingIndex = 0
      local function registerSetting(o, kind)
        settingIndex = settingIndex + 1
        local default
        local ok, current = pcall(o.get)
        if ok then default = current end
        if default == nil then
          if kind == Settings.VarType.Boolean then
            default = false
          elseif kind == Settings.VarType.Number then
            default = o.min or 0
          else
            default = ""
          end
        end
        local setting = Settings.RegisterProxySetting(category,
          "MythicView_CombatMode_" .. def.id .. "_" .. settingIndex,
          kind, taggedLabel(o.label or def.label, o.tag), default,
          function() return o.get() end,
          function(value) return o.set(value) end)
        return setting
      end

      local ctx = { content = scratchContent, width = 528 }
      function ctx:Header(text)
        if type(text) == "table" then text = text.text end
        if CreateSettingsListSectionHeaderInitializer then
          addInitializer(layout, CreateSettingsListSectionHeaderInitializer(text))
        end
      end
      function ctx:Description(text)
        if type(text) == "table" then text = text.text end
        if CreateSettingsListTextEntryInitializer then
          addInitializer(layout, CreateSettingsListTextEntryInitializer(text))
        elseif CreateSettingsListSectionHeaderInitializer then
          addInitializer(layout, CreateSettingsListSectionHeaderInitializer(text))
        end
      end
      function ctx:Gap() end
      function ctx:WatermarkPage(text)
        if type(text) == "table" then text = text.text end
        self:Description(text)
      end
      function ctx:Toggle(o)
        local setting = registerSetting(o, Settings.VarType.Boolean)
        local tooltip = o.desc
        if o.confirm then tooltip = (tooltip or "") .. "\n\nThis option may reload the user interface." end
        Settings.CreateCheckbox(category, setting, tooltip)
      end
      function ctx:Slider(o)
        local setting = registerSetting(o, Settings.VarType.Number)
        local options = Settings.CreateSliderOptions(o.min, o.max,
          o.step or math.max((o.max or 1) - (o.min or 0), 1) / 100)
        Settings.CreateSlider(category, setting, options, o.desc)
      end
      function ctx:Dropdown(o)
        local setting = registerSetting(o, Settings.VarType.String)
        Settings.CreateDropdown(category, setting, function()
          local container = Settings.CreateControlTextContainer()
          for _, value in ipairs(o.order or {}) do
            local label = o.values and o.values[value] or value
            if o.display then label = o.display(value) end
            container:Add(value, label)
          end
          return container:GetData()
        end, o.desc)
      end

      function ctx:Keybind(o) addKeybind(layout, category, o) end
      function ctx:TextInput(o) nativeTextEditor(layout, o) end
      function ctx:SpellMultiSelect(o) nativeTextEditor(layout, o) end
      function ctx:MountMultiSelect(o) nativeTextEditor(layout, o) end
      function ctx:Button(o) button(layout, o.label, o.func, o.desc) end
      function ctx:ButtonRow(buttons)
        for _, o in ipairs(buttons) do button(layout, o.label, o.func, o.desc) end
      end
      function ctx:PlaceFrame(_, _)
        button(layout, "Click casting assignments", function()
          local clickCasting = ns.combatModeCategories and ns.combatModeCategories.clickcasting
          if clickCasting and Settings.OpenToCategory then Settings.OpenToCategory(clickCasting:GetID()) end
        end, "Open the native Mythic View Click Casting settings.")
      end
      function ctx:Place(_) end
      ctx.nativeSettings = true
      function ctx:ColorPicker(o)
        button(layout, o.label, function()
          local color = o.get()
          local r, g, b, a = color[1], color[2], color[3], color[4] or 1
          local function apply(_, opacity)
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local opacityValue = opacity
            if type(opacityValue) ~= "number" then
              opacityValue = OpacitySliderFrame and OpacitySliderFrame:GetValue()
            end
            local na = type(opacityValue) == "number" and (1 - opacityValue) or a
            o.set(nr, ng, nb, na)
          end
          ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, opacity = 1 - a, hasOpacity = true,
            swatchFunc = apply,
            opacityFunc = apply,
            cancelFunc = function(previous)
              local previousOpacity = previous.opacity
              o.set(previous.r, previous.g, previous.b,
                type(previousOpacity) == "number" and (1 - previousOpacity) or a)
            end,
          })
        end, o.desc)
      end

      if def.build then def.build(ctx) end
      ns.combatModeCategories[def.id] = category
    end
  end
  ns.combatModeCategory = combatCategory
end

function ns.BuildOptions()
  if ns.category then return end
  if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then
    return
  end

  local db = ns.GetSettings()
  local defaults = ns.SETTINGS_DEFAULTS
  local category, layout = Settings.RegisterVerticalLayoutCategory("Mythic View")

  local function Header(text)
    if layout and CreateSettingsListSectionHeaderInitializer then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
  end

  local function Register(key, varType, label)
    local variable = "MythicView_" .. key
    local setting = Settings.RegisterAddOnSetting(category, variable, key, db, varType, label, defaults[key])
    local function OnChanged() ns.ApplySettings() end
    if setting.SetValueChangedCallback then
      setting:SetValueChangedCallback(OnChanged)
    elseif Settings.SetOnValueChangedCallback then
      Settings.SetOnValueChangedCallback(variable, OnChanged)
    end
    settingObjects[key] = setting
    return setting
  end

  -- Every toggle is tagged so players know which ones are safe to leave on
  -- and which can fight the game's own camera.
  local TAGS = {
    good = { "|cff66dd88[Recommended]|r ", "Recommended to keep enabled: safe and tested." },
    optional = { "|cffe0c060[Optional]|r ", "Optional: personal preference; should not cause problems." },
    risky = { "|cffe07050[Not recommended]|r ", "Not recommended: may conflict with the native game camera and cause bugs." },
  }

  local function Checkbox(key, label, tooltip, tag)
    local info = TAGS[tag]
    if info then
      label = info[1] .. label
      tooltip = info[2] .. "\n\n" .. tooltip
    end
    Settings.CreateCheckbox(category, Register(key, Settings.VarType.Boolean, label), tooltip)
  end

  local function Percent(key, label, minValue, maxValue, tooltip)
    local options = Settings.CreateSliderOptions(minValue, maxValue, 5)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
      return string.format("%d%%", value)
    end)
    Settings.CreateSlider(category, Register(key, Settings.VarType.Number, label), options, tooltip)
  end

  Header("Legend")
  if layout and CreateSettingsListTextEntryInitializer then
    layout:AddInitializer(CreateSettingsListTextEntryInitializer(
      "|cff66dd88[Recommended]|r Keep enabled for most setups."
    ))
    layout:AddInitializer(CreateSettingsListTextEntryInitializer(
      "|cffe0c060[Optional]|r Personal preference."
    ))
    layout:AddInitializer(CreateSettingsListTextEntryInitializer(
      "|cffe07050[Not recommended]|r May conflict with the native camera."
    ))
  else
    Header("[Recommended] Keep enabled   [Optional] Personal preference   [Not recommended] May conflict")
  end
  Header("Style")
  local presetSetting = Register("preset", Settings.VarType.String, "Camera style")
  Settings.CreateDropdown(category, presetSetting, function()
    local container = Settings.CreateControlTextContainer()
    for _, presetID in ipairs(ns.PRESET_ORDER) do
      local preset = ns.PRESETS[presetID]
      container:Add(presetID, preset.name, preset.description)
    end
    return container:GetData()
  end, "Changes the camera distance, framing, pacing, and overall intensity.")
  Checkbox("autoPvpCamera", "Automatically use PvP camera in arenas and battlegrounds",
    "Temporarily switches to PvP Competitive in arenas and battlegrounds: fixed 90-degree FOV, maximum addon zoom, centered framing, and no dynamic camera effects. Restores your selected style when you leave.", "good")
  Percent("zoomScale", "Camera distance", 70, 150,
    "Scales the distance of every profile in the selected style.")

  if ns.SHAKES_ENABLED then
  Header("Shake and impact")
  Percent("shakeIntensity", "Shake intensity", 0, 200,
    "Strength of all shakes and impacts (hits, damage, landing, and entering combat).")
  Checkbox("hitImpacts", "Shake on hits and damage taken",
    "Zoom/FOV kick and shake when your attacks land or when you take damage.")
  Checkbox("hitstop", "Hit-stop on hits",
    "The camera freezes for a few frames at the peak of a hit before shaking.")
  Percent("stepSway", "Footstep sway", 0, 200,
    "Side-to-side camera sway with each step, paced by actual movement speed.")
  Checkbox("breathing", "Idle breathing",
    "Slow, nearly imperceptible camera drift while standing still.")
  Checkbox("verticalShake", "Vertical shake (experimental)",
    "Tilts the camera up/down on impacts and footsteps. WoW does not expose the camera’s actual pitch, so this may conflict with native movement. Leave it off if the camera bobs while running.", "risky")
  end

  Header("Framing")
  Checkbox("speedDrag", "Pull back with speed (speed drag)",
    "The camera lags behind as you accelerate and catches up as you slow down.", "good")
  Checkbox("lookAhead", "Look ahead through turns",
    "Turning or strafing opens space in the direction you are moving.", "good")
  Checkbox("composition", "Maintain rule of thirds",
    "When zoom or FOV changes dynamically, the shoulder offset follows so your character stays in place on screen.", "good")
  Checkbox("rubberBand", "Widen for many enemies (rubber band)",
    "Each attacker beyond four widens the frame a little more.", "optional")
  Checkbox("aimOnCast", "Aim zoom while casting",
    "Cast-time spells and channels move the camera over your shoulder, like aiming a bow.", "optional")

  Header("Game engine")
  Checkbox("smoothCollision", "Smooth collision + silhouette behind walls",
    "The camera tolerates more obstacles before moving closer, and your character appears as a silhouette when occluded.", "good")
  Checkbox("freeFollow", "Camera follows behind while moving (free follow)",
    "The game turns the camera behind your character as you move, with smooth lag.", "risky")

  Settings.RegisterAddOnCategory(category)
  ns.category = category
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function() RegisterCombatControlsSubcategory(category) end)
  else
    RegisterCombatControlsSubcategory(category)
  end
end
