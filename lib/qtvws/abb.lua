-- by Qige <qigezhao@gmail.com>
-- 2017.06.19

local iwinfo = require "iwinfo"
local ccff = require "qutil.ccff"

local uget = ccff.conf.get
local uset = ccff.conf.set
local s = ccff.val.s
local n = ccff.val.n

local ts = os.time
local out = io.write
local prt = print
local tpush = table.insert
local sfmt = string.format


local abb2 = {}

abb2.cmd = {}
abb2.cmd.wmac = 'cat /sys/class/net/wlan0/address | tr -d "\n"'
abb2.cmd.meshid = 'uci get wireless.@wifi-iface[0].mesh_id > /tmp/.grid_meshid; cat /tmp/.grid_meshid | tr -d "\n"'

-- FIXME: should be read from config file
abb2.conf = {}
abb2.conf.dev = 'wlan0'
abb2.conf.api = 'nl80211'
abb2.conf.chanbw = uget('wireless', 'radio0', 'chanbw') or 8

-- limitations
abb2.bar = {}
abb2.bar.rf_min = -110
abb2.bar.peer_inactive = 3000

-- .iw, .param, .wmac
abb2.cache = {}

function abb2.init()
	local iw = abb2.cache.iw
	if (not iw) then
		local api = abb2.conf.api or 'nl80211'
		abb2.cache.iw = iwinfo[api]
		--iw = abb2.cache.iw
	end
end
function abb2.wmac()
  local cmd_wmac = abb2.cmd.wmac
  abb2.cache.wmac = ccff.execute(cmd_wmac)
  --prt('raw> ' .. abb2.cache.wmac)
end

function abb2.set(key, value)
  local cmd
  if (key == 'siteno') then
    uset('ec54s','v2','siteno', value)
  elseif (key == 'mode') then
    if (value == 'car' or value == 'CAR') then
      cmd = 'config_car; arn_car\n'
    elseif (value == 'ear' or value == 'EAR') then
      cmd = 'config_ear; arn_ear\n'
    elseif (value == 'mesh' or value == 'MESH') then
      cmd = 'config_mesh; arn_mesh\n'
    end
  elseif (key == 'chanbw') then
    cmd = sfmt('setchanbw %d\n', value)
  elseif (key == 'wifi') then
    if (value == '0') then
      cmd = 'reboot\n'
    elseif (value == '1') then
      cmd = 'wifi\n'
    elseif (value == '2') then
      cmd = 'wifi down\n'
    else
      cmd = 'wifi up\n'
    end
  end

  ccff.execute(cmd)
end

-- get all params
function abb2.param()
  -- init dev/api/iw
  abb2.init()

	local abb = {}
	local dev = abb2.conf.dev
  local api = abb2.conf.api
  local iw = abb2.cache.iw

  local fmt_rf = abb2.format.rf
  local fmt_mode = abb2.format.mode

  abb.wmac = abb2.cache.wmac or abb2.wmac() or '00:00:00:00:00:00'
  --prt('raw0> ' .. abb.wmac)

	abb.chanbw = abb2.conf.chanbw
	abb.mode = fmt_mode(iw.mode(dev)) or '-mode'
	abb.bssid = iw.bssid(dev) or '-bssid'

	local noise = fmt_rf(iw.noise(dev))
  if (noise == 0) then noise = -101 end -- gws4k noise=0
	local signal = fmt_rf(iw.signal(dev))
  if (signal < noise) then signal = noise end
  abb.noise = noise
  abb.signal = signal

	local peers = abb2.peers(abb.bssid, abb.noise)
	abb.peers = peers or {}
	abb.peer_qty = #peers or 0
  --prt('raw0> peer_qty = ' .. abb.peer_qty)

	abb.ts = os.time()

	return abb
end

-- get all peers in table
function abb2.peers(bssid, noise)
	local peers = {}
	local dev = abb2.conf.dev
  local api = abb2.conf.api
  local iw = abb2.cache.iw

	local ai, ae
	local al = iw.assoclist(dev)
	if al and next(al) then
    for ai, ae in pairs(al) do
      local peer = {}
      local signal = abb2.format.rf(ae.signal)
      local inactive = n(ae.inactive) or 65535
      if (signal ~= 0 and signal > noise and inactive < abb2.bar.peer_inactive) then
        peer.bssid = bssid
        peer.wmac = s(ai) or '0000'
        peer.ip = ''

        peer.signal = signal
        peer.noise = noise

        peer.inactive = inactive

        --print('abb.peers raw> rx_mcs|tx_mcs = ', ae.rx_mcs, ae.tx_mcs)
        peer.rx_mcs = n(ae.rx_mcs) or 0
        peer.rx_br = n(ae.rx_rate) or 0
        peer.rx_short_gi = n(ae.rx_short_gi) or 0
        peer.tx_mcs = n(ae.tx_mcs) or 0
        peer.tx_br = n(ae.tx_rate) or 0
        peer.tx_short_gi = n(ae.tx_short_gi) or 0

        tpush(peers, peer)
      end
    end
	end
	return peers
end


-- format string/number
abb2.format = {}
function abb2.format.mode(m)
	if (m == 'Master') then
		return 'CAR'
	elseif (m == 'Client') then
		return 'EAR'
	else
		return m
	end
end
function abb2.format.rf(v)
  local r = abb2.bar.rf_min
  if (v) then
    if (v < r) then
      r = abb2.bar.rf_min
    else
      r = v
    end
  end
  if (r < abb2.bar.rf_min) then r = abb2.bar.rf_min end
  return r
end


return abb2
