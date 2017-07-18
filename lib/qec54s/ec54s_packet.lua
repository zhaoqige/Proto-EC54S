-- by Qige <qigezhao@gmail.com>
-- 2017.06.30 encode|decode|length
-- 2017.07.03 dl_seq|dl_devid|seq_max

local tbl_push = table.insert
local tbl_flat = table.concat
local sfmt = string.format
local schar = string.char
local slen = string.len
local sbyte = string.byte
local ssub = string.sub
local sfind = string.find

local Packet = {}

Packet.conf = {}
Packet.conf.bytes_tail = "\n\n"
Packet.conf.seq_max = 65536

Packet.message = {}
Packet.message.TYPE_DL_QUERY        = 0x11    -- 0001 0001
Packet.message.TYPE_DL_SET          = 0x12    -- 0001 0010
Packet.message.TYPE_UL_QUERY_REPLY  = 0x81    -- 1000 0001
Packet.message.TYPE_UL_SET_ACK      = 0x82    -- 1000 0010
Packet.message.TYPE_UL_REPORT       = 0x84    -- 1000 0100

Packet.message.TYPE_HI              = 0x8F    -- 1000 1111
Packet.message.TYPE_BYE             = 0x80    -- 1000 0000
Packet.message.TYPE_KEEP_ALIVE      = 0xFF    -- 1111 1111

Packet.cache = {}
Packet.cache.dl_seq = 0
Packet.cache.dl_devid = 0
Packet.cache.ul_seq = 0

-- TODO: handle request defined SEQ, DevID
function Packet.encode(pkt)
  local length = 8
  local packet_raw = {}
  local packet = pkt or {}

  tbl_push(packet_raw, 5, Packet.conf.bytes_tail)
  if (packet.seq) then
    tbl_push(packet_raw, 2, Packet.dbl_char(packet.seq))
  else
    local ul_seq = Packet.cache.ul_seq or 0
    tbl_push(packet_raw, 2, Packet.dbl_char(ul_seq))
    ul_seq = ul_seq + 1    -- save ul seq
    ul_seq = ul_seq % Packet.conf.seq_max
    Packet.cache.ul_seq = ul_seq
  end

  if (packet.devid) then
    tbl_push(packet_raw, 3, Packet.dbl_char(packet.devid))
  else
    tbl_push(packet_raw, 3, Packet.dbl_char(0))
  end

  if (packet.data) then
	tbl_push(packet_raw, 4, packet.data)
    length = length + #packet.data
  else
	tbl_push(packet_raw, 4, schar(0x00))    -- default send 0x00
	length = length + 1
  end

  tbl_push(packet_raw, 1, Packet.dbl_char(length))

  local packet_flat = tbl_flat(packet_raw, '')
  return packet_flat
end

-- Note: when DL_SET|DL_REPORT, return seq, devid when decode
function Packet.decode(data)
  local cmds = ''
  local dl_seq, dl_devid, data_type
  if (data) then
    local data_length = #data    -- FIXME: assume packet whole sent together
    --print('data_length=' .. data_length)
    if (data_length >= 9) then
      local length_raw = ssub(data, 1, 2)
      local length = math.min(Packet.int(length_raw), data_length)
      --print('length=' .. length)
      local seq_raw = ssub(data, 3, 4)
      local seq = Packet.int(seq_raw)
      Packet.dl_seq = seq
      --print('Packet.decode raw> seq=' .. seq)
      local devid_raw = ssub(data, 5, 6)
      local devid = Packet.int(devid_raw)
      Packet.dl_devid = devid
      --print('Packet.decode raw> devid=' .. devid)

      -- when data type is 0x11 or 0x12, return seq & devid
      -- DEBUG USE ONLY: add 0x20, return seq & devid
      local data_raw_length = math.min(length - 8, data_length)
      data_type = ssub(data, 7, 7)    -- DEBUG: data_type == ' '
      --[[if (data_type == Packet.message.TYPE_DL_QUERY or data_type == Packet.message.TYPE_DL_SET) then
        dl_seq = seq
        dl_devid = devid
      end
      if (data_type == 0x20) then
        dl_seq = seq
        dl_devid = devid
      end
      print(sfmt('packet raw> seq|devid|data_type = %d,%d,[%x]', seq, devid, data_type))
      ]]--

      dl_seq = seq
      dl_devid = devid

      local data_raw = ssub(data, 8, 8+data_raw_length)
      cmds = data_raw
    else
      --cmds = 'R'
      
      -- add debug here, enter "nc 192.168.1.24 3000 -u"
      cmds = 'R'
    end
  end

  --print('packet raw> data|dl_seq|devid|data_type = ', data, dl_seq, dl_devid, data_type)
  return cmds, dl_seq, dl_devid
end

function Packet.cmd_pickup(str)
  local cmd, val
  if (str) then
    local str_len = #str
    if (str_len >= 3) then
      cmd, val = Packet.kv_pickup(str, 1)
      if (cmd and val) then
        if (cmd == 'C' or cmd == 'c') then
          cmd = 'channel'
        elseif (cmd == 'TP' or cmd == 'tp') then
          cmd = 'txpower'
        elseif (cmd == 'R' or cmd == 'r') then
          cmd = 'region'
        elseif (cmd == 'CB' or cmd == 'cb') then
          cmd = 'chanbw'
        elseif (cmd == 'SN' or cmd == 'sn') then
          cmd = 'siteno'
        elseif (cmd == 'W' or cmd == 'w') then
          cmd = 'wifi'
        elseif (cmd == 'M' or cmd == 'm') then
          cmd = 'mode'
        else
          cmd = nil
          val = nil
        end
      end
    else
      if (str == Packet.message.TYPE_DL_QUERY or str == 'r' or str == 'R') then
        cmd = 'report'
      elseif (str == 0x00) then
        cmd = 'hi'
      elseif (str == 0xff) then
        cmd = 'bye'
      else
        cmd = 'report'
      end
      val = nil
    end
  end
  return cmd, val
end

function Packet.kv_pickup(data, index)
	if (data) then
		local p1,p2,key,val = sfind(data, "([%w\.\-\_]*)=([%w\.\-\_]*)")
		if (key and val) then
			return key, val
		end
	end
	return nil, nil
end

-- Hi byte | Low byte
function Packet.dbl_char(val)
  if (val > Packet.conf.seq_max) then
    val = val % Packet.conf.seq_max
  end
  return schar(math.floor(val / 256)) .. schar(val % 256)
end

function Packet.int(str)
  if (str) then
    local hi = sbyte(str, 1, 2)
    local low = sbyte(str, 2, 3)
    local v = hi * 256 + low
    v = v % Packet.conf.seq_max
    return v
  end
  return 0
end

return Packet