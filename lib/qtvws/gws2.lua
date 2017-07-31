-- by Qige <qigezhao@gmail.com>
-- 2017.06.03

local iwinfo = require "iwinfo"
local ccff = require "qutil.ccff"

local abb2 = require "qtvws.abb"
local radio2 = require "qtvws.radio"

local prt = print
local out = io.write
local s = ccff.val.s
local n = ccff.val.n

local gws2 = {}

-- .iw, .param, .wmac
gws2.cache = {}

function gws2.param()
  local gws = {}
	local gws_abb = abb2.param()
  local gws_radio = radio2.update()

  gws.abb = gws_abb
  gws.radio = gws_radio

  --prt('qtvws.gws2 raw> ', gws.abb.wmac, gws.abb.noise, gws.abb.signal)
  --prt('qtvws.gws2 raw> ', gws.radio.txpower, gws.radio.channel)

	return gws
end

function gws2.set(cmds)
  --prt('gws2.exec raw> cmds =', cmds)
  if (cmds) then
    if (cmds.region) then
      prt('region = ' .. cmds.region)
      radio2.set('region', cmds.region)
    end
    if (cmds.channel) then
      prt('channel = ' .. cmds.channel)
      radio2.set('channel', cmds.channel)
    end
    if (cmds.txpower) then
      prt('txpower = ' .. cmds.txpower)
      radio2.set('txpower', cmds.txpower)
    end
    if (cmds.wifi) then
      prt('wifi = ' .. cmds.wifi)
      abb2.set('wifi', cmds.wifi)
    end
    if (cmds.chanbw) then
      prt('chanbw = ' .. cmds.chanbw)
      abb2.set('chanbw', cmds.chanbw)
    end
    if (cmds.mode) then
      prt('mode = ' .. cmds.mode)
      abb2.set('mode', cmds.mode)
    end
    if (cmds.siteno) then
      prt('siteno = ' .. cmds.siteno)
      abb2.set('siteno', cmds.siteno)
    end
  else
    prt('gws2 raw> (empty command)')
  end
end

return gws2
