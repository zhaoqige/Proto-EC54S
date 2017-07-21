-- by Qige <qigezhao@gmail.com>
-- 2017.06.26: basic structure

local ccff = require "qutil.ccff"

local gws34 = require "qtvws.radio4k"
local gws5k = require "qtvws.radio5k"

local sfmt = string.format

local function string_has(str, key)
  local p1, p2 = string.find(str, key)
  if (p1 ~= nil) then
    return true
  end
  return false
end

local radio = {}

-- gws5-31-33: /dev/gws5001Dev + 9533 CPU
-- gws5-44-33: /dev/gws5001Dev + 9344 CPU
-- else gws3000 or gws4000, compatible with "rfinfo"
function radio.hw_arch()
  local hw_arch = nil

  local cpu, dev
  local cpu_raw = ccff.execute('cat /proc/cpuinfo | grep system')
  local dev_raw = ccff.execute('ls /dev/gws* 2>/dev/null')

  if (string_has(cpu_raw, '9533')) then
    cpu = '9533'
    hw_arch = 'gws5k'    -- gws5-9531-33
  elseif (string_has(cpu_raw, '9344')) then
    cpu = '9344'
    if (string_has(dev_raw, 'gws5001Dev')) then
      dev = 'gws5001Dev'
      hw_arch = 'gws5k'    -- gws5-9344-33
    end
  else
    hw_arch = nil
  end

  return hw_arch
end

-- configuration init when loaded
radio.conf = {}
radio.conf.hw = radio.hw_arch() or 'gws34'

function radio.update()
  local dev = {}
  local hw = radio.conf.hw
  if (hw == 'gws5k') then
    dev = gws5k.update()
  else
    dev = gws34.update()
  end

  --print('radio.update dev raw> txpower|channel =', dev.txpower, dev.channel)

  return dev
end

function radio.set(key, value)
  local hw = radio.conf.hw
  if (key and value) then
    if (hw == 'gws5k') then
      gws5k.set(key, value)
    else
      gws34.set(key, value)
    end
  end
end


return radio
