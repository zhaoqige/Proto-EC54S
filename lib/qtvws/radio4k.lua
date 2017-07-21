-- by Qige <qigezhao@gmail.com>
-- 2017.07.06 rfinfo|update|get

local ccff = require 'qutil.ccff'

local sfmt = string.format
local ts = os.time

local gws4k = {}

gws4k.conf = {}
gws4k.conf.rfinfo_cmd = 'rfinfo'
gws4k.conf.rfinfo_cache = '/tmp/.gws_rfinfo'
gws4k.conf.rfinfo_cache_bar = 15

gws4k.cache = {}
gws4k.cache.ts_rfinfo = 0

function gws4k.update()
  local dev = {}
  dev.txpower = gws4k.get_int('txpower') or 0
  dev.channel = gws4k.get_int('channel') or 0
  
  --print('gws4k.update raw> txpower|channel|ts_last =', dev.txpower, dev.channel, gws4k.cache.ts_rfinfo)
  
  return dev
end

function gws4k.prep_cache()
  local ts_now = ts()
  local ts_cache = gws4k.cache.ts_rfinfo or 0
  local ts_bar = gws4k.conf.rfinfo_cache_bar or 4
  
  if (ts_now - ts_cache >= ts_bar) then
    local rfinfo_cmd = gws4k.cache.rfinfo_cmd or 'rfinfo'
    local rfinfo_cache = gws4k.cache.rfinfo_cache or '/tmp/.gws_rfinfo'

    local cmd = sfmt("%s > %s", rfinfo_cmd, rfinfo_cache)
    ccff.execute(cmd)
    
    gws4k.cache.ts_rfinfo = ts_now
  end
end

function gws4k.get_int(key)
  local result = 0
  local cmd
  local rfinfo_cache = gws4k.cache.rfinfo_cache or '/tmp/.gws_rfinfo'
  
  gws4k.prep_cache()    -- update cache if needed
  
  if (key == 'channel') then
    cmd = sfmt("cat %s | grep Chan: | grep [0-9\.\-]* -o", rfinfo_cache)
  elseif (key == 'txpower') then
    cmd = sfmt("cat %s | grep Tx | grep Power: | grep [0-9\.\-]* -o", rfinfo_cache)
  elseif (key == 'region') then
    cmd = sfmt("cat %s | grep Region: | grep [0-9\.\-]* -o", rfinfo_cache)
  elseif (key == 'rxgain') then
    cmd = sfmt("cat %s | grep Rx | grep Gain: | grep [0-9\.\-]* -o", rfinfo_cache)
  end

  --print("gws4k.get_int raw> cmd =", cmd)
  result = tonumber(ccff.execute(cmd)) or 0
  return result
end

function gws4k.set(key, value)
  local cmd
  if (key == 'channel') then
    cmd = sfmt('setchan %d\n', value)
  elseif (key == 'txpower') then
    cmd = sfmt('settxpower %d\n', value)
  elseif (key == 'region') then
    cmd = sfmt('setregion %d\n', value)
  end
  
  ccff.execute(cmd)
  gws4k.cache.ts_rfinfo = 0    -- update cache immediately
end

return gws4k