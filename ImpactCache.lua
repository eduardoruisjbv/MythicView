-- Optional bridge to MuscleMemory's curated spell-purpose catalog.
-- Mythic View stores a compact, versioned lookup cache and never infers that
-- an unknown ability is a direct hit.
local _, ns = ...
ns = ns or {}

local CACHE_SCHEMA = 1
local CACHE_TTL = 90 * 24 * 60 * 60
local VALID_KINDS = { direct = true, mixed = true, periodic_only = true, non_damage = true, unknown = true }
local runtimeCache = {}

local function IdentityKey()
  local _, classToken = UnitClass("player")
  local specIndex = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
    and C_SpecializationInfo.GetSpecialization() or 0
  local specID = specIndex and C_SpecializationInfo.GetSpecializationInfo(specIndex) or 0
  return tostring(classToken or "?") .. ":" .. tostring(specID or 0)
end

local function CacheRoot()
  if not MythicViewDB then return nil end
  MythicViewDB.impactSpellCache = MythicViewDB.impactSpellCache or { schema = CACHE_SCHEMA, entries = {} }
  local root = MythicViewDB.impactSpellCache
  if root.schema ~= CACHE_SCHEMA or type(root.entries) ~= "table" then
    root.schema, root.entries = CACHE_SCHEMA, {}
  end
  return root.entries
end

function ns.GetImpactClassification(spellID)
  if type(spellID) ~= "number" or spellID <= 0 or (issecretvalue and issecretvalue(spellID)) then
    return { kind = "unknown", confidence = 0, source = "invalid" }
  end

  local muscleMemory = _G.MuscleMemoryAPI
  if not muscleMemory or type(muscleMemory.GetImpactClassification) ~= "function" then
    return { kind = "unknown", confidence = 0, source = "catalog-unavailable", spellID = spellID }
  end

  local profileKey = IdentityKey()
  -- Query the tiny, pure catalog API first so the cache key follows its data
  -- version. This also avoids treating stale entries as current after updates.
  local ok, kind, confidence, source, version = pcall(muscleMemory.GetImpactClassification, spellID)
  if not ok or not VALID_KINDS[kind] then
    return { kind = "unknown", confidence = 0, source = "classification-unavailable", spellID = spellID }
  end

  local apiVersion = tostring(version or "1")
  local cacheKey = table.concat({ profileKey, apiVersion, tostring(spellID) }, ":")
  local cached = runtimeCache[cacheKey]
  if cached then return cached end

  local stored = CacheRoot()
  local entry = stored and stored[cacheKey]
  local now = time and time() or 0
  if entry and entry.schema == CACHE_SCHEMA and entry.kind and VALID_KINDS[entry.kind]
      and entry.apiVersion == apiVersion and now > 0 and now - (entry.updated or 0) <= CACHE_TTL then
    runtimeCache[cacheKey] = entry
    return entry
  end
  local result = {
    schema = CACHE_SCHEMA,
    kind = kind,
    confidence = type(confidence) == "number" and confidence or 0,
    source = tostring(source or "MuscleMemory"),
    apiVersion = tostring(version or apiVersion),
    updated = now,
    spellID = spellID,
  }
  if kind ~= "unknown" and stored and now > 0 then stored[cacheKey] = result end
  runtimeCache[cacheKey] = result
  return result
end
