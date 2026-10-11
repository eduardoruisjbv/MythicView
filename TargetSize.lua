-- Conservative target-size cache. No nameplate pixels are treated as creature
-- geometry: only explicit player overrides and coarse, low-confidence game
-- classifications influence zoom. Entries are keyed by map + creature ID.
local _, ns = ...
ns = ns or {}

local CACHE_SCHEMA = 1
local MAX_ENTRIES = 384
local SMALL_ZOOM = -0.75
local ELITE_ZOOM = 0.45
local RARE_ELITE_ZOOM = 0.70
local BOSS_ZOOM = 0.95
local offsets = { small = SMALL_ZOOM, medium = 0, large = 1.35 }
local smoothOffset, wantedOffset = 0, 0
local targetIdentity
local refreshedAt = 0
local activeCacheKey

local function Readable(value)
  return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function ReadableTrue(value)
  return Readable(value) and value == true
end

local function CreatureID(guid)
  if type(guid) ~= "string" or (issecretvalue and issecretvalue(guid)) then return nil end
  if not guid:match("^Creature%-") and not guid:match("^Vehicle%-") then return nil end
  local _, _, _, _, _, rawID = strsplit("-", guid)
  local id = tonumber(rawID)
  return id and id > 0 and id or nil
end

local function CacheEntries()
  if not MythicViewDB then return nil end
  MythicViewDB.targetSizeCache = MythicViewDB.targetSizeCache or { schema = CACHE_SCHEMA, entries = {} }
  local root = MythicViewDB.targetSizeCache
  if root.schema ~= CACHE_SCHEMA or type(root.entries) ~= "table" then
    root.schema, root.entries = CACHE_SCHEMA, {}
  end
  return root.entries
end

local function TargetCacheKey(unit)
  local guid = UnitGUID(unit)
  local creatureID = CreatureID(guid)
  local mapID
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, result = pcall(C_Map.GetBestMapForUnit, unit)
    if ok then mapID = result end
  end
  if not creatureID or not Readable(mapID) then return nil, guid end
  return tostring(mapID) .. ":" .. tostring(creatureID), guid
end

local function ClassificationOffset(unit)
  local classification
  if UnitClassification then
    local ok, result = pcall(UnitClassification, unit)
    if ok then classification = result end
  end
  if not Readable(classification) then return 0, "unknown", 0 end
  if classification == "minus" then return SMALL_ZOOM, "small", 0.35 end
  if classification == "elite" then return ELITE_ZOOM, "large", 0.30 end
  if classification == "rareelite" then return RARE_ELITE_ZOOM, "large", 0.35 end
  if classification == "worldboss" or classification == "boss" then return BOSS_ZOOM, "large", 0.40 end
  return 0, "medium", 0.20
end

local function Trim(entries)
  local count, oldestKey, oldestTime = 0, nil, math.huge
  for key, entry in pairs(entries) do
    count = count + 1
    local updated = entry.updated or 0
    if updated < oldestTime then oldestTime, oldestKey = updated, key end
  end
  if count > MAX_ENTRIES and oldestKey then entries[oldestKey] = nil end
end

function ns.RefreshTargetSize(unit)
  unit = unit or "target"
  local now = GetTime()
  local guid = UnitGUID(unit)
  local readableGUID = Readable(guid) and guid or false
  if readableGUID == targetIdentity and now - refreshedAt < 0.25 then return end
  targetIdentity, refreshedAt = readableGUID, now
  activeCacheKey = nil

  if unit ~= "target" or not ReadableTrue(UnitExists(unit))
      or not ReadableTrue(UnitCanAttack("player", unit))
      or ReadableTrue(UnitIsDeadOrGhost(unit)) then
    wantedOffset = 0
    return
  end

  local key = TargetCacheKey(unit)
  activeCacheKey = key
  local entries = CacheEntries()
  local entry = key and entries and entries[key]
  if entry and entry.schema == CACHE_SCHEMA and offsets[entry.size] and entry.source == "manual" then
    wantedOffset = offsets[entry.size]
    return
  end
  if entry and entry.schema == CACHE_SCHEMA and entry.source == "classification"
      and type(entry.zoomOffset) == "number" then
    wantedOffset = entry.zoomOffset
    return
  end

  local offset, size, confidence = ClassificationOffset(unit)
  wantedOffset = offset
  if key and entries and size ~= "unknown" then
    entries[key] = {
      schema = CACHE_SCHEMA, size = size, source = "classification",
      confidence = confidence, zoomOffset = offset, updated = now,
    }
    Trim(entries)
  end
end

function ns.SetTargetSizeOverride(size)
  local entries = CacheEntries()
  local key = TargetCacheKey("target")
  if not entries or not key then return false, "target-identity-unavailable" end
  if size == "auto" then
    if entries[key] and entries[key].source == "manual" then entries[key] = nil end
  elseif offsets[size] then
    entries[key] = { schema = CACHE_SCHEMA, size = size, source = "manual", confidence = 1, updated = GetTime() }
    Trim(entries)
  else
    return false, "expected-small-medium-large-or-auto"
  end
  targetIdentity = nil
  ns.RefreshTargetSize("target")
  return true
end

function ns.UpdateTargetSizeZoom(elapsed, enabled)
  if enabled then ns.RefreshTargetSize("target") else wantedOffset = 0 end
  local delta = math.max(0, math.min(elapsed or 0, 0.1))
  local alpha = 1 - math.exp(-delta / 0.65)
  smoothOffset = smoothOffset + (wantedOffset - smoothOffset) * alpha
  if math.abs(smoothOffset - wantedOffset) < 0.01 then smoothOffset = wantedOffset end
  return smoothOffset
end

function ns.GetTargetSizeCacheInfo()
  local entries = CacheEntries()
  return activeCacheKey and entries and entries[activeCacheKey] or nil
end
