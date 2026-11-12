-- Water Tracker: penyimpanan riwayat minum + kalender
-- Format History.txt (satu baris per hari):  2026-11-12=5|08:10,09:30,11:02,13:40,15:15

local MONTHS = {'Januari','Februari','Maret','April','Mei','Juni','Juli',
                'Agustus','September','Oktober','November','Desember'}
local DAYS = {'Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'}

local file, data, today, selected, viewY, viewM, started, calOpen

local function ymd(y, m, d) return string.format('%04d-%02d-%02d', y, m, d) end

local function parseDate(s)
  local y, m, d = s:match('^(%d+)-(%d+)-(%d+)$')
  return tonumber(y), tonumber(m), tonumber(d)
end

local function offsetDate(s, n)
  local y, m, d = parseDate(s)
  return os.date('%Y-%m-%d', os.time{year = y, month = m, day = d + n, hour = 12})
end

local function rgb(s)
  local r, g, b = (s or ''):match('(%d+)%s*,%s*(%d+)%s*,%s*(%d+)')
  return (r or 255) .. ',' .. (g or 255) .. ',' .. (b or 255)
end

local function num(v, default) return tonumber(v) or default end

local function bang(...) SKIN:Bang(...) end

local function Get(d) return data[d] or {count = 0, times = {}} end

local function Load()
  data = {}
  local f = io.open(file, 'r')
  if not f then return end
  for line in f:lines() do
    local d, c, times = line:match('^(%d+%-%d+%-%d+)=(%d+)|?(.*)$')
    if d then
      local e = {count = tonumber(c), times = {}}
      for tm in times:gmatch('[^,%s]+') do table.insert(e.times, tm) end
      data[d] = e
    end
  end
  f:close()
end

local function Save()
  local keys = {}
  for k, v in pairs(data) do
    if v.count > 0 then table.insert(keys, k) end
  end
  table.sort(keys)
  local f = io.open(file, 'w')
  if not f then return end
  for _, k in ipairs(keys) do
    f:write(k .. '=' .. data[k].count .. '|' .. table.concat(data[k].times, ',') .. '\n')
  end
  f:close()
end

-- Ubah jumlah gelas pada tanggal d sebanyak delta (+1 / -1)
local function Change(d, delta)
  if d > today then return end
  local e = data[d] or {count = 0, times = {}}
  data[d] = e
  if delta > 0 then
    e.count = e.count + 1
    if d == today then table.insert(e.times, os.date('%H:%M')) end
  elseif e.count > 0 then
    e.count = e.count - 1
    if #e.times > e.count then table.remove(e.times) end
  end
end

-- Kirim nilai hari ini ke variabel skin
local function Push()
  local e = Get(today)
  bang('!SetVariable', 'Count', e.count)
  bang('!SetVariable', 'LastTime', e.times[#e.times] or '-')
  bang('!SetVariable', 'Previous', Get(offsetDate(today, -1)).count)
  if calOpen == 1 then
    bang('!SetVariable', 'CalFill', SKIN:GetVariable('Accent'))
    bang('!SetVariable', 'CalIcon', SKIN:GetVariable('ColorOnAccent'))
  else
    bang('!SetVariable', 'CalFill', SKIN:GetVariable('ColorButton2'))
    bang('!SetVariable', 'CalIcon', SKIN:GetVariable('ColorText'))
  end
  bang('!UpdateMeasureGroup', 'Data')
end

local function Draw()
  local target = num(SKIN:GetVariable('Target'), 8)
  local glass = num(SKIN:GetVariable('GlassSize'), 250)
  local accent = rgb(SKIN:GetVariable('Accent'))
  local done = rgb(SKIN:GetVariable('ColorDone'))
  local text = SKIN:GetVariable('ColorText')
  local dim = SKIN:GetVariable('ColorDim')

  local first = os.time{year = viewY, month = viewM, day = 1, hour = 12}
  local offset = (tonumber(os.date('%w', first)) + 6) % 7          -- minggu dimulai Senin
  local nDays = tonumber(os.date('%d', os.time{year = viewY, month = viewM + 1, day = 0, hour = 12}))

  bang('!SetOption', 'MeterCalMonth', 'Text', MONTHS[viewM] .. ' ' .. viewY)

  local reached, logged, sum = 0, 0, 0
  for i = 1, 42 do
    local day = i - offset
    local bg, num_, cnt = 'MeterCalBg' .. i, 'MeterCalNum' .. i, 'MeterCalCnt' .. i
    if day >= 1 and day <= nDays then
      local key = ymd(viewY, viewM, day)
      local e = Get(key)
      local fill, fcol = '0,0,0,1', text
      if key > today then
        fcol = dim
      elseif e.count >= target then
        fill, fcol = done .. ',255', '255,255,255,255'
        reached = reached + 1
      elseif e.count > 0 then
        local ratio = e.count / target
        fill = accent .. ',' .. math.floor(55 + 150 * ratio)
        if ratio >= 0.4 then fcol = '255,255,255,255' end
      end
      if e.count > 0 then logged = logged + 1; sum = sum + e.count end

      local stroke = 'StrokeWidth 0'
      if key == selected then
        stroke = 'StrokeWidth 1.6 | Stroke Color ' .. text
      elseif key == today then
        stroke = 'StrokeWidth 1.6 | Stroke Color ' .. accent .. ',255'
      end
      bang('!SetOption', bg, 'Shape', 'Ellipse 18.5,15,14 | Fill Color ' .. fill .. ' | ' .. stroke)
      bang('!SetOption', num_, 'Text', day)
      bang('!SetOption', num_, 'FontColor', fcol)
      bang('!SetOption', num_, 'FontWeight', key == today and 700 or 500)
      bang('!SetOption', cnt, 'Text', e.count > 0 and tostring(e.count) or '')
    else
      bang('!SetOption', bg, 'Shape', 'Ellipse 18.5,15,14 | Fill Color 0,0,0,0 | StrokeWidth 0')
      bang('!SetOption', num_, 'Text', '')
      bang('!SetOption', cnt, 'Text', '')
    end
  end

  -- Detail tanggal terpilih
  local y, m, d = parseDate(selected)
  local wday = tonumber(os.date('%w', os.time{year = y, month = m, day = d, hour = 12}))
  local e = Get(selected)
  local title = DAYS[wday + 1] .. ', ' .. d .. ' ' .. MONTHS[m]
  if selected == today then title = title .. '  (hari ini)' end
  local info, times
  if e.count > 0 then
    info = e.count .. ' gelas  -  ' .. (e.count * glass) .. ' ml'
    if #e.times > 0 then
      times = 'Jam: ' .. table.concat(e.times, '  ')
    else
      times = 'Jam minum tidak tercatat'
    end
  elseif selected > today then
    info, times = 'Belum terjadi', ''
  else
    info, times = 'Tidak ada catatan', ''
  end
  bang('!SetOption', 'MeterDetailTitle', 'Text', title)
  bang('!SetOption', 'MeterDetailInfo', 'Text', info)
  bang('!SetOption', 'MeterDetailTimes', 'Text', times)

  local summary
  if logged == 0 then
    summary = 'Belum ada catatan di bulan ini'
  else
    local avg = string.format('%.1f', sum / logged):gsub('%.', ',')
    summary = reached .. ' hari target tercapai  -  rata-rata ' .. avg .. ' gelas/hari'
  end
  bang('!SetOption', 'MeterCalSummary', 'Text', summary)

  bang('!UpdateMeter', '*')
  bang('!Redraw')
end

local function Commit(d)
  Save(); Push(); Draw()
end

-- ===== Dipanggil dari skin =====

function Initialize()
  file = SKIN:GetVariable('@') .. 'History.txt'
  Load()
  today = os.date('%Y-%m-%d')
  selected = today
  local t = os.date('*t')
  viewY, viewM = t.year, t.month
  calOpen = num(SKIN:GetVariable('CalOpen'), 0)
  started = false
end

function Update()
  local now = os.date('%Y-%m-%d')
  if not started or now ~= today then
    if started then
      local t = os.date('*t')
      viewY, viewM = t.year, t.month
      if selected == today then selected = now end
    end
    started = true
    today = now
    Push(); Draw()
  end
  return Get(today).count
end

function AddToday() Change(today, 1); Commit() end
function RemoveToday() Change(today, -1); Commit() end

-- Klik segmen ke-n: isi sampai n, atau batalkan gelas ke-n kalau sudah terisi tepat n
function ToggleToday(n)
  local c = Get(today).count
  local goal = (c == n) and n - 1 or n
  while Get(today).count < goal do Change(today, 1) end
  while Get(today).count > goal do Change(today, -1) end
  Commit()
end

function ResetToday()
  data[today] = nil
  Commit()
end

function ChangeSelected(delta) Change(selected, delta); Commit() end

function ChangeTarget(delta)
  local t = math.max(1, math.min(12, num(SKIN:GetVariable('Target'), 8) + delta))
  bang('!SetVariable', 'Target', t)
  bang('!WriteKeyValue', 'Variables', 'Target', t, SKIN:GetVariable('@') .. 'Variables.inc')
  Push(); Draw()
end

function Select(i)
  local first = os.time{year = viewY, month = viewM, day = 1, hour = 12}
  local offset = (tonumber(os.date('%w', first)) + 6) % 7
  local nDays = tonumber(os.date('%d', os.time{year = viewY, month = viewM + 1, day = 0, hour = 12}))
  local day = i - offset
  if day >= 1 and day <= nDays then
    selected = ymd(viewY, viewM, day)
    Draw()
  end
end

function Month(delta)
  viewM = viewM + delta
  if viewM < 1 then viewM = 12; viewY = viewY - 1 end
  if viewM > 12 then viewM = 1; viewY = viewY + 1 end
  Draw()
end

function GoToday()
  local t = os.date('*t')
  viewY, viewM, selected = t.year, t.month, today
  Draw()
end

function ToggleCal()
  calOpen = 1 - calOpen
  bang('!SetVariable', 'CalOpen', calOpen)
  bang('!WriteKeyValue', 'Variables', 'CalOpen', calOpen, SKIN:GetVariable('@') .. 'Variables.inc')
  Push(); Draw()
end
