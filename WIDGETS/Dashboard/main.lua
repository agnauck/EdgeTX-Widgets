--[[
Version: 1.0.1

AUTHOR
======
Alexander Gnauck (gnauck@gmail.com)

LICENSE
=======
This script is provided under the GNU General Public License v3.
See <https://www.gnu.org/licenses/gpl-3.0.en.html> for details.

DESCRIPTION
===========
Displays info about the active model, including name ad image.
Additional up to 10 values can be configured to be shown on the screen

The is build on the new LVGL LUA API and works only nn color ui radios.
Currently its only optimized for landscape screem, portrait may be added in 
future versions.
--]]

-- docs: https://luadoc.edgetx.org/lua-api-reference/constants/units
local UNIT_STRINGS = {
  [0] = "",       -- UNIT_RAW  
  [1] = "V",      -- UNIT_VOLTS
  [2] = "A",      -- UNIT_AMPS
  [3] = "mA",     -- UNIT_MILLIAMPS
  [4] = "kts",    -- UNIT_KTS
  [5] = "m/s",    -- UNIT_METERS_PER_SECOND
  [6] = "f/s",    -- UNIT_FEET_PER_SECOND
  [7] = "km/h",   -- UNIT_KMH
  [8] = "mph",    -- UNIT_MPH
  [9] = "m",      -- UNIT_METERS
  [10] = "f",     -- UNIT_FEET
  [11] = "°C",    -- UNIT_CELSIUS
  [12] = "°F",    -- UNIT_FAHRENHEIT
  [13] = "%",     -- UNIT_PERCENT
  [14] = "mAh",   -- UNIT_MAH (Milliamp Hour)
  [15] = "mW",    -- UNIT_WATTS
  [16] = "W",     -- UNIT_MILLIWATTS
  [17] = "db",    -- UNIT_DB
  [18] = "rpm",   -- UNIT_RPMS
  [19] = "g",     -- UNIT_G
  [20] = "°",     -- UNIT_DEGREE
  [21] = "rad",   -- UNIT_RADIANS
  [22] = "ml",    -- UNIT_MILLILITERS
  [23] = "fOz",   -- UNIT_FLOZ
  [24] = "ml/m"   -- UNIT_MILLILITERS_PER_MINUTE
}

local UNIT_ID_TO_STRING = {
    "V", "A", "mA", "kts", "m/s", "f/s", "km/h", "mph", "m", "f",
    "°C", "°F", "%", "mAh", "W", "mW", "dB", "rpm", "g", "°",
    "rad", "ml", "fOz", "ml/m", "Hz", "mS", "uS", "km"
}

-- defines the precision of certain units
local UNIT_PRECISION = {
  ["V"] = 1,  -- 7.4 V
  ["m"] = 0,
  ["f"] = 0,
  ["%"] = 0,
  ["mW"] = 0,
  ["W"] = 0
}

-- defines name overrides for units
local NAME_OVERRIDES = {
  ["tx-voltage"] = "TxBt",
  ["timer1"] = "T1",
  ["timer2"] = "T2",
  ["timer3"] = "T3"
}

local BORDER_THIKNESS = 0

local function getSensorId(sensor)
  local fieldInfo = getFieldInfo(sensor)
  return fieldInfo and fieldInfo.id or nil
end

-- local function getBattSensorId()
--   local batsens = { "RxBt", "Cels", "A1", "A2", "A3", "A4" }
--   for i = 1, #batsens do
--     local fieldInfo = getFieldInfo(batsens[i])
--     if fieldInfo ~= nil then
--       return fieldInfo.id
--     end
--   end
--   return 0
-- end


local options = {
  { "Value1",  SOURCE, getSensorId("tx-voltage") },
  { "Value2",  SOURCE, getSensorId("RxBt") },
  { "Value3",  SOURCE, getSensorId("TPWR") },
  { "Value4",  SOURCE, getSensorId("RQly") },
  { "Value5",  SOURCE, nil },
  { "Value6",  SOURCE, nil },
  { "Value7",  SOURCE, nil },
  { "Value8",  SOURCE, nil },
  { "Value9",  SOURCE, nil },
  { "Value10", SOURCE, nil }
}

-- formats a time value to hh:mm:ss for timers
local function hms(tim)
  local n = math.abs(tim)  
  local prefix = (tim < 0 and "-" or " ")
  return prefix .. string.format("%02d:%02d:%02d", math.floor(n / 3600), math.floor((n % 3600) / 60), n % 60)
end

local function isTimer(id)
  return id == "T1" or id == "T2" or id == "T3"
end

local function formatCachedField(sensorId)
  if not sensorId or sensorId == 0 then return "---", "---" end
  local rawValue = getValue(sensorId)
  if not rawValue or type(rawValue) == "table" then return "---", "---" end

  local info = getFieldInfo(sensorId)
  if not info then return "---", "---" end

  local name = info.name or "???"

  -- print("[Widget-Log] formatCachedField: " .. sensorId)
  -- print("[Widget-Log] name: " .. name)
  -- if info.unit ~= nil then
  --   print("[Widget-Log] unit: " .. info.unit)
  -- else
  --   print("[Widget-Log] unit: nil")
  -- end

  -- we override some sensor name here with the static array definition
  if NAME_OVERRIDES[name] then
    name = NAME_OVERRIDES[name]
  end

  if isTimer(name) then
    return hms(rawValue), name
  end

  -- based on original sensor precision
  local sensorPrec = info.prec or 0
  if sensorPrec > 0 then
    rawValue = rawValue / (10 ^ sensorPrec)
  end

  local unitStr = UNIT_STRINGS[info.unit] or ""
  if name == "TxBt" and unitStr == "" then
    unitStr = "V"
  end

  local displayPrec = UNIT_PRECISION[unitStr] or 0

  local formatStr = "%." .. tostring(displayPrec) .. "f"
  local finalValue = string.format(formatStr, rawValue) .. unitStr

  return finalValue, name
end

local VALUE_ROWS = 0


local function create(zone, options)
  local wgt = {
    zone = zone,
    options = options,

    modelName = "",
    modelBitmap = "",
    activeSensorCount = 0,

    displayData = {
      { name = "", value = "" },
      { name = "", value = "" },
      { name = "", value = "" },
      { name = "", value = "" },
      { name = "", value = "" },
      { name = "", value = "" },
      { name = "", value = "" },
      { name = "", value = "" },
      { name = "", value = "" },
      { name = "", value = "" }
    }
  }

  return wgt
end

local function valueRow(wgt, idx1, idx2)
    return {
      type = "rectangle",
      flexFlow = lvgl.FLOW_ROW,      
      w = lvgl.PERCENT_SIZE + 100,
      h = lvgl.PERCENT_SIZE + math.floor(100 / VALUE_ROWS),
      align = VCENTER,
      thickness = BORDER_THIKNESS,
      children = {
        {
          -- left name/value pair
          type = "rectangle",          
          w = lvgl.PERCENT_SIZE + 50,
          h = lvgl.PERCENT_SIZE + 100,
          thickness = BORDER_THIKNESS,
          children = {
            {
              type = "label",              
              align = LEFT + VTOP,
              color = COLOR_THEME_PRIMARY1,
              font = SMLSIZE,
              text = (function() return " " .. wgt.displayData[idx1].name .. ":" end)
            },
            {
              type = "label",
              w = lvgl.PERCENT_SIZE + 100,
              align = RIGHT + VCENTER,
              font = MIDSIZE,
              text = (function() return wgt.displayData[idx1].value end)
            },
          }
        },
        {
          -- right name/value pair
          type = "rectangle",          
          w = lvgl.PERCENT_SIZE + 50,
          h = lvgl.PERCENT_SIZE + 100,
          thickness = BORDER_THIKNESS,
          children = {
           {
              type = "label",              
              align = LEFT + VTOP,
              color = COLOR_THEME_PRIMARY1,
              font = SMLSIZE,
              text = (function()
                local name = wgt.displayData[idx2].name
                if name and name ~= "" then
                  return " " .. name .. ":"
                else
                  return ""
                end
              end)
            },
            {
              type = "label",
              --w = lvgl.PERCENT_SIZE + 50,
              w = lvgl.PERCENT_SIZE + 100,
              align = RIGHT + VCENTER,
              font = MIDSIZE,
              text = (function() return wgt.displayData[idx2].value end)
            },
          }
        }
      }
    }
end



local function update(wgt, options)
  wgt.options = options
  lvgl.clear()

  wgt.activeSensorCount = 0

  -- reset default values
  for i = 1, 10 do
    wgt.displayData[i].name = ""
    wgt.displayData[i].value = ""
  end

  for i = 1, 10 do
    local optKey = "Value" .. tostring(i)
    local sourceId = options[optKey]

    if sourceId and sourceId ~= 0 then
      wgt.activeSensorCount = i
      local valStr, sName = formatCachedField(sourceId)
      wgt.displayData[i].name = sName
      wgt.displayData[i].value = valStr
    else
      break
    end
  end



  VALUE_ROWS = math.max(1, math.ceil(wgt.activeSensorCount / 2))

  -- build the sensor data array
  local sensorArray = {}
  for row = 1, VALUE_ROWS do
    local idx1 = (row - 1) * 2 + 1
    local idx2 = idx1 + 1

    table.insert(sensorArray, valueRow(wgt, idx1, idx2))
  end

  lvgl.rectangle({
    w = lvgl.PERCENT_SIZE + 100,
    h = lvgl.PERCENT_SIZE + 100,
    thickness = BORDER_THIKNESS,
    flexFlow = lvgl.FLOW_ROW,
    children = {
      {
        type = "rectangle",
        thickness = BORDER_THIKNESS,
        h = lvgl.PERCENT_SIZE + 100,
        w = lvgl.PERCENT_SIZE + 40,
        align = LEFT | VTOP,
        flexFlow = lvgl.FLOW_COLUMN,
        children = {
          { 
            type = "label",
            color = COLOR_THEME_SECONDARY1,
            h = 30, font = DBLSIZE,
            text = (function() return wgt.modelName end) 
          },
          {
            type = "image",
            x = 0,
            y = 0,
            w = wgt.zone.w * 40 / 100 - 10,
            h = wgt.zone.h - 30,
            file = (function() return "/IMAGES/" .. wgt.modelBitmap end),                                                                                                                                                           fill = false }
        }
      },
      {
        type = "rectangle",
        thickness = BORDER_THIKNESS,
        flexFlow = lvgl.FLOW_COLUMN,
        h = lvgl.PERCENT_SIZE + 100,
        w = lvgl.PERCENT_SIZE + 60,
        children = sensorArray
      },
    }
  })
end



local function background(wgt)
  -- nothing here yet
end

function refresh(wgt)
  local modelInfo = model.getInfo()
  wgt.modelName = modelInfo.name
  wgt.modelBitmap = modelInfo.bitmap

  for i = 1, (wgt.activeSensorCount or 0) do
    local optKey = "Value" .. tostring(i)
    local sourceId = wgt.options[optKey]

    if sourceId and sourceId ~= 0 then
      local valStr, _ = formatCachedField(sourceId)
      wgt.displayData[i].value = valStr
    end
  end
end

return { name = "Dashboard", options = options, create = create, update = update, refresh = refresh, background =
background, useLvgl = true }
