-- by Qige <qigezhao@gmail.com>
-- 2017.07.06 rfinfo|update|get

local ccff = require 'qutil.ccff'

local sfmt = string.format
local ts = os.time

local gws5k = {}

gws5k.conf = {}
gws5k.conf.rfinfo_cmd = 'rfinfo'
gws5k.conf.rfinfo_cache = '/tmp/.gws_rfinfo'
gws5k.conf.rfinfo_cache_bar = 15

gws5k.cache = {}
gws5k.cache.ts_rfinfo = 0

function gws5k.update()
  local dev = {}
  dev.txpower = gws5k.get_int('txpower') or 0
  dev.channel = gws5k.get_int('channel') or 0
  
  --print('gws5k.update raw> txpower|channel|ts_last =', dev.txpower, dev.channel, gws5k.cache.ts_rfinfo)
  
  return dev
end

function gws5k.prep_cache()
  local ts_now = ts()
  local ts_cache = gws5k.cache.ts_rfinfo or 0
  local ts_bar = gws5k.conf.rfinfo_cache_bar or 4
  
  if (ts_now - ts_cache >= ts_bar) then
    local rfinfo_cmd = gws5k.cache.rfinfo_cmd or 'rfinfo'
    local rfinfo_cache = gws5k.cache.rfinfo_cache or '/tmp/.gws_rfinfo'

    local cmd = sfmt("%s > %s", rfinfo_cmd, rfinfo_cache)
    ccff.execute(cmd)
    
    gws5k.cache.ts_rfinfo = ts_now
  end
end

function gws5k.get_int(key)
  local result = 0
  local cmd
  local rfinfo_cache = gws5k.cache.rfinfo_cache or '/tmp/.gws_rfinfo'
  
  gws5k.prep_cache()    -- update cache if needed
  
  if (key == 'channel') then
    cmd = sfmt("cat %s | grep Chan: | grep [0-9\.\-]* -o", rfinfo_cache)
  elseif (key == 'txpower') then
    cmd = sfmt("cat %s | grep Tx | grep Power: | grep [0-9\.\-]* -o", rfinfo_cache)
  elseif (key == 'region') then
    cmd = sfmt("cat %s | grep Region: | grep [0-9\.\-]* -o", rfinfo_cache)
  elseif (key == 'rxgain') then
    cmd = sfmt("cat %s | grep Rx | grep Gain: | grep [0-9\.\-]* -o", rfinfo_cache)
  end

  --print("gws5k.get_int raw> cmd =", cmd)
  result = tonumber(ccff.execute(cmd)) or 0
  return result
end

function gws5k.set(key, value)
  local cmd
  if (key == 'channel') then
    cmd = sfmt('setchan %d; gws -C %d\n', value, value)
  elseif (key == 'txpower') then
    cmd = sfmt('settxpower %d; gws -P %d\n', value, value)
  elseif (key == 'region') then
    cmd = sfmt('setregion %d; gws -R %d\n', value, value)
  end
  
  ccff.execute(cmd)
  gws5k.cache.ts_rfinfo = 0    -- update cache immediately
end

return gws5k