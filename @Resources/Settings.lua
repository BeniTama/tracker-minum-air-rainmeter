-- Dialog pengaturan pengingat (WaterTracker\Settings)
-- Menyimpan ke Variables.inc lalu memberi tahu skin utama lewat ReloadSettings().

local MAIN = 'WaterTracker'
local CHIPS = {0, 30, 60, 90, 120, 180}
local s, file, started

local function bang(...) SKIN:Bang(...) end
local function num(v, d) return tonumber(v) or d end

local function durText(mins)
  local h, m = math.floor(mins / 60), mins % 60
  if h > 0 and m > 0 then return h .. ' jam ' .. m .. ' mnt' end
  if h > 0 then return h .. ' jam' end
  return m .. ' mnt'
end

local function Draw()
  local accent = SKIN:GetVariable('Accent')
  local on = SKIN:GetVariable('ColorOnAccent')
  local text = SKIN:GetVariable('ColorText')
  local chipBg = SKIN:GetVariable('ColorButton2')
  local dim = SKIN:GetVariable('ColorDim')
  local track = SKIN:GetVariable('ColorTrack')

  for i, v in ipairs(CHIPS) do
    local sel = (s.ReminderMin == v)
    bang('!SetOption', 'MeterChip' .. i, 'Shape',
      'Rectangle 0,0,82,34,17 | Fill Color ' .. (sel and accent or chipBg) .. ' | StrokeWidth 0')
    bang('!SetOption', 'MeterChipText' .. i, 'FontColor', sel and on or text)
    bang('!SetOption', 'MeterChipText' .. i, 'FontWeight', sel and 700 or 500)
  end

  local custom
  if s.ReminderMin <= 0 then
    custom = 'Pengingat mati'
  else
    custom = 'Setiap ' .. durText(s.ReminderMin)
  end
  bang('!SetOption', 'MeterCustomText', 'Text', custom)
  bang('!SetOption', 'MeterStartValue', 'Text', string.format('%02d:00', s.ActiveStart))
  bang('!SetOption', 'MeterEndValue', 'Text', string.format('%02d:00', s.ActiveEnd))

  local isOn = s.ReminderNotif == 1
  bang('!SetOption', 'MeterSwitch', 'Shape',
    'Rectangle 0,0,40,22,11 | Fill Color ' .. (isOn and accent or track) .. ' | StrokeWidth 0')
  bang('!SetOption', 'MeterSwitch', 'Shape2',
    'Ellipse ' .. (isOn and 29 or 11) .. ',11,8 | Fill Color 255,255,255,255 | StrokeWidth 0')

  -- Bagian yang tidak relevan saat pengingat mati dibuat redup
  local active = s.ReminderMin > 0
  bang('!SetOption', 'MeterHoursLabel', 'FontColor', active and dim or track)

  bang('!UpdateMeter', '*')
  bang('!Redraw')
end

local function Set(key, value)
  s[key] = value
  bang('!SetVariable', key, value)
  bang('!WriteKeyValue', 'Variables', key, value, file)
  bang('!SetVariable', key, value, MAIN)
  bang('!CommandMeasure', 'MeasureLua', 'ReloadSettings()', MAIN)
  Draw()
end

function Initialize()
  file = SKIN:GetVariable('@') .. 'Variables.inc'
  s = {
    ReminderMin   = num(SKIN:GetVariable('ReminderMin'), 120),
    ActiveStart   = num(SKIN:GetVariable('ActiveStart'), 7),
    ActiveEnd     = num(SKIN:GetVariable('ActiveEnd'), 22),
    ReminderNotif = num(SKIN:GetVariable('ReminderNotif'), 1),
  }
  started = false
end

function Update()
  if not started then started = true; Draw() end
  return s.ReminderMin
end

function Chip(i) Set('ReminderMin', CHIPS[i]) end

-- Atur menit sendiri, langkah 15 menit (15 mnt - 6 jam)
function Step(delta)
  local v = s.ReminderMin
  if v <= 0 then
    if delta < 0 then return end
    v = 15
  else
    v = v + delta
    if v < 15 then v = 0 end          -- di bawah 15 mnt berarti mati
  end
  Set('ReminderMin', math.min(v, 360))
end

function StartHour(delta)
  local v = math.max(0, math.min(s.ActiveEnd - 1, s.ActiveStart + delta))
  Set('ActiveStart', v)
end

function EndHour(delta)
  local v = math.max(s.ActiveStart + 1, math.min(24, s.ActiveEnd + delta))
  Set('ActiveEnd', v)
end

function ToggleNotif() Set('ReminderNotif', 1 - s.ReminderNotif) end

function Test()
  bang('!CommandMeasure', 'MeasureLua', 'TestAlert()', MAIN)
end
