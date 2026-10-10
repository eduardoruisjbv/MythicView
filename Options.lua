-- Mythic View options panel: Game Menu > Options > AddOns > Mythic View, or /mv.
-- Built on the native Settings API; every control writes straight into
-- MythicViewDB.settings and asks the camera to re-apply.
local _, ns = ...

local settingObjects = {}

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
  if not Settings.RegisterCanvasLayoutSubcategory then return end

  local panel = CreateFrame("Frame")
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  title:SetPoint("CENTER", panel, "CENTER", 0, 80)
  title:SetText("Combat controls")

  local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  description:SetPoint("TOP", title, "BOTTOM", 0, -16)
  description:SetWidth(460)
  description:SetJustifyH("CENTER")
  description:SetText("Mouse look, reticle targeting, click casting, crosshair, and ally cycling.")

  local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  button:SetSize(220, 28)
  button:SetPoint("TOP", description, "BOTTOM", 0, -24)
  button:SetText("Open combat controls")
  button:SetScript("OnClick", function()
    if not ns.OpenCombatModeOptions then return end
    local settingsPanel = _G.SettingsPanel
    if settingsPanel and settingsPanel:IsShown() then
      if HideUIPanel then
        HideUIPanel(settingsPanel)
      else
        settingsPanel:Hide()
      end
    end
    ns.OpenCombatModeOptions()
  end)

  ns.combatModeCategory = Settings.RegisterCanvasLayoutSubcategory(
    parentCategory, panel, "Combat controls"
  )
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

  Header("Legend:  |cff66dd88[Recommended]|r keep enabled   |cffe0c060[Optional]|r personal preference   |cffe07050[Not recommended]|r may cause bugs")
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
  RegisterCombatControlsSubcategory(category)
end
