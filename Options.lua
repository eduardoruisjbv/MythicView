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
    print("|cffd9bf8cMythic View|r: menu indisponível nesta versão do jogo.")
  end
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
    good = { "|cff66dd88[Recomendado]|r ", "Recomendado ficar ligado: seguro e testado." },
    optional = { "|cffe0c060[Opcional]|r ", "Opcional: depende do seu gosto, não causa problemas." },
    risky = { "|cffe07050[Não recomendado]|r ", "Não recomendado: pode brigar com a câmera nativa do jogo e causar bugs." },
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

  Header("Legenda:  |cff66dd88[Recomendado]|r deixe ligado   |cffe0c060[Opcional]|r gosto pessoal   |cffe07050[Não recomendado]|r pode causar bugs")
  Header("Estilo")
  local presetSetting = Register("preset", Settings.VarType.String, "Estilo de câmera")
  Settings.CreateDropdown(category, presetSetting, function()
    local container = Settings.CreateControlTextContainer()
    for _, presetID in ipairs(ns.PRESET_ORDER) do
      local preset = ns.PRESETS[presetID]
      container:Add(presetID, preset.name, preset.description)
    end
    return container:GetData()
  end, "Muda distância, enquadramento, ritmo e intensidade de toda a câmera.")
  Percent("zoomScale", "Distância da câmera", 70, 150,
    "Multiplica a distância de todos os perfis do estilo escolhido.")

  if ns.SHAKES_ENABLED then
  Header("Tremores e impacto")
  Percent("shakeIntensity", "Intensidade dos tremores", 0, 200,
    "Força de todos os tremores e impactos (golpes, dano, aterrissagem, entrada em combate).")
  Checkbox("hitImpacts", "Tremor ao acertar e ao ser atingido",
    "Empurrão de zoom/FOV e tremor quando um golpe seu acerta ou quando você toma dano.")
  Checkbox("hitstop", "Micro-freeze nos golpes",
    "A câmera congela por alguns quadros no pico do golpe antes de tremer.")
  Percent("stepSway", "Balanço dos passos", 0, 200,
    "Balanço lateral da câmera a cada passo, no ritmo da velocidade real.")
  Checkbox("breathing", "Respiração parado",
    "Deriva lenta e quase invisível da câmera quando você está parado.")
  Checkbox("verticalShake", "Tremor vertical (experimental)",
    "Inclina a câmera para cima/baixo em impactos e passos. O WoW não informa a inclinação real da câmera, então pode brigar com o movimento nativo — deixe desligado se a câmera 'subir e descer' ao correr.", "risky")
  end

  Header("Enquadramento")
  Checkbox("speedDrag", "Afastar com a velocidade (speed drag)",
    "A câmera fica para trás ao acelerar e alcança ao frear.", "good")
  Checkbox("lookAhead", "Antecipar curvas (look-ahead)",
    "Ao virar ou andar de lado, o quadro abre espaço para onde você vai.", "good")
  Checkbox("composition", "Manter regra dos terços",
    "Quando o zoom ou o FOV mudam dinamicamente, o ombro acompanha para o personagem não sair do lugar na tela.", "good")
  Checkbox("rubberBand", "Abrir com muitos inimigos (rubber band)",
    "Cada atacante além de quatro estica o quadro um pouco mais.", "optional")
  Checkbox("aimOnCast", "Zoom de mira ao conjurar",
    "Magias com tempo de conjuração e canalizações aproximam a câmera sobre o ombro, como mirar com o arco.", "optional")

  Header("Motor do jogo")
  Checkbox("smoothCollision", "Colisão suave + silhueta atrás de paredes",
    "A câmera tolera mais obstáculos antes de se aproximar e o personagem aparece em silhueta quando encoberto.", "good")
  Checkbox("freeFollow", "Câmera segue atrás ao andar (free follow)",
    "O jogo gira a câmera para trás do personagem enquanto você anda, com atraso suave.", "risky")

  Settings.RegisterAddOnCategory(category)
  ns.category = category
end
