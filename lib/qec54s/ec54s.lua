-- by Qige <qigezhao@gmail.com>
-- 2017.06.29 base structure/components
-- 2017.07.03 packet format

--local uci = require 'uci'
local socket = require 'socket'

-- shortcut
local tbl_push = table.insert
local tbl_flat = table.concat
local sfmt = string.format
local schar = string.char
local ssub = string.sub
local echo = io.write
local ts = os.time


local EC54S = {}

EC54S.VERSION = 'B030717C'
EC54S.Util = require 'qec54s.ec54s_util'    -- UDP
--EC54S.Util = require 'qec54s.ec54s_util_tcp'    -- TODO: reserved for TCP

EC54S.Proto = require 'qec54s.ec54s_packet'    -- Packet encode()/decode()
EC54S.Device1 = require 'qtvws.gws2'    -- Radio device

EC54S.ERROR_TERMINATE = false  -- Message handler errors terminate process?

EC54S.agent = {}
EC54S.agent.__index = EC54S.agent

EC54S.agent.DEFAULT_PORT           = 3000
EC54S.agent.KEEP_ALIVE_TIME        = 60
EC54S.agent.TIMEOUT                = 5
EC54S.agent.PAYLOAD_LENGTH_MAX     = 80

EC54S.message = {}
EC54S.message.TYPE_DL_QUERY        = 0x11    -- 0001 0001
EC54S.message.TYPE_DL_SET          = 0x12    -- 0001 0010
EC54S.message.TYPE_UL_QUERY_REPLY  = 0x81    -- 1000 0001
EC54S.message.TYPE_UL_SET_ACK      = 0x82    -- 1000 0010
EC54S.message.TYPE_UL_REPORT       = 0x84    -- 1000 0100

EC54S.message.TYPE_HI              = 0x8F    -- 1000 1111
EC54S.message.TYPE_BYE             = 0x80    -- 1000 0000
EC54S.message.TYPE_KEEP_ALIVE      = 0xFF    -- 1111 1111

EC54S.CONNERR = {}
EC54S.CONNERR.err_message = {
    "Not authorized",
    "Invalid packet",
    "Unknown error"
}

-- ------------------------------------------------------------------------- --

function EC54S.agent.daemon(    -- Public API
    local_devid,	-- local assigned device id
    server, server_port,  -- server port
    port,         -- local port
    callback
    )

    local ec54s_agent = {}
    setmetatable(ec54s_agent, EC54S.agent)    -- Fake OOP
    ec54s_agent.VERSION = EC54S.VERSION .. ' Daemon'
    ec54s_agent.callback = callback
    ec54s_agent.server = server or '127.0.0.1'
    ec54s_agent.server_port = server_port or EC54S.agent.DEFAULT_PORT
    ec54s_agent.port = port or EC54S.agent.DEFAULT_PORT
    ec54s_agent.auto_report = false
    ec54s_agent.connected = false
    ec54s_agent.destroyed = false
    ec54s_agent.socket_fd = nil
    ec54s_agent.dl_timeout_times = 0
    ec54s_agent.dl_msg_seq = 0
    ec54s_agent.dl_msg_devid = 0
    ec54s_agent.ul_msg_seq = 0
    ec54s_agent.ul_msg_devid = local_devid or 0xff
    ec54s_agent.dl_port = tonumber(ec54s_agent.port)
    return (ec54s_agent)
end

function EC54S.agent:service_init(timeout)
    local ret
    if (self.connected) then
        return ("EC54S.agent: Already connected (error)")
    end

    if (socket == nil) then
        return ("EC54S.agent: Need LuaSocket (error)")
    end

    self.socket_fd = EC54S.Util.socket_raw()
    if (self.socket_fd == nil) then
        return ("EC54S.agent: Invalid local socket (error)")
    end
    
    ret = self.socket_fd:settimeout(timeout or 0)
    ret = self.socket_fd:setsockname('*', self.port)    -- if port available, return 1
    --print('agent raw> setsockname = ', ret)
    if (ret == nil) then
      self.socket_fd:close()
      return ("EC54S.agent: Local port inuse (error)")
    end
    EC54S.Util.socket_wait_connected(self.socket_fd)    -- when TCP, do nothing before connected
    self:message_send(EC54S.message.TYPE_HI)    -- Send HI to server after connected
    
    print(sfmt("EC54S.agent (%s) initialized.", self.VERSION))
    self.connected = true
    return nil
end

function EC54S.agent:service_handle()    -- Public API
    --EC54S.Util.dbg("EC54S.agent:service_handle()")
    if (self.connected == false) then
        EC54S.Util.dbg("EC54S.agent:service_handle(): Not connected")
    else
        if (self.auto_report) then    -- report right away
          self:message_send(EC54S.message.TYPE_UL_REPORT)
          --self:idle(1)    -- DEBUG USE ONLY!
        else
          --[
          -- wait for command
          local buf, peer, peer_port = EC54S.Util.socket_recv(self.socket_fd)
          if (buf ~= nil and peer ~= nil and peer ~= 'timeout') then
              print(string.format("EC54S.agent: remote +%s:%s said:",
                  peer or '-', peer_port or '-'))
              EC54S.Util.dump_hex(buf)
              --if (peer == self.server) then
                  self.dl_port = peer_port
                  self:message_handle(buf)
              --[[else
                  EC54S.Util.dbg(string.format("EC54S.agent: %s (bad remote +%s:%s)",
                      EC54S.CONNERR.err_message[1], peer or '-', peer_port or '-'))
              end]]--
              self.dl_timeout_times = 0
          else
              local tt = self.dl_timeout_times + 1
              print(sfmt("%d> EC54S.agent: (no message, timeout %d times)", ts(), tt))
              self.dl_timeout_times = tt
          end
          self.dl_port = 0
          --]]--
        end
    end
end

function EC54S.agent:idle(x)    -- Public API
    --EC54S.Util.dbg("EC54S.agent:idle()")
    socket.sleep(x or 0.1)
end

function EC54S.agent:disconnect()    -- Internal API
    --EC54S.Util.dbg("EC54S.agent:disconnect()")
    if (self.connected) then
        self:message_send(EC54S.message.TYPE_BYE)    -- Send BYE to server before disconnected
        self.socket_fd:close()
        self.connected = false
    else
        error("EC54S.agent: Already disconnected")
    end
end

function EC54S.agent:destroy()    -- Public API
    --EC54S.Util.dbg("EC54S.agent:distroy()")
    if (self.destroyed == false) then
        self.destroyed = true
        if (self.connected) then
          self:disconnect()
        end
        self.callback = nil
    end
end

-- ------------------------------------------------------------------------- --

function EC54S.agent:message_handle(message)
  -- TODO: return SEQ, Devid
  local dl_seq, dl_devid
  local cmds_raw, dl_seq, dl_devid = EC54S.Proto.decode(message)
  local cmd, value = EC54S.Proto.cmd_pickup(cmds_raw)

  --print('message_handle raw> cmds_raw|dl_seq|dl_devid = ', cmds_raw, dl_seq, dl_devid)
  --print('cmd_pickup() > cmd|value = ', cmd, value)
  
  if (cmd == 'report') then
    self:message_send(EC54S.message.TYPE_UL_REPORT, dl_devid or self.ul_msg_devid, dl_seq)
  elseif (cmd == 'hi') then
    self:message_send(EC54S.message.TYPE_HI, self.ul_msg_devid)
  elseif (cmd == 'bye') then
    self:message_send(EC54S.message.TYPE_BYE, self.ul_msg_devid)
  elseif (cmd == 'channel') then
    self:message_send(EC54S.message.TYPE_UL_SET_ACK, dl_devid, dl_seq)
    self:execute_command('setchan ' .. value)
  elseif (cmd == 'region') then
    self:message_send(EC54S.message.TYPE_UL_SET_ACK, dl_devid, dl_seq)
    self:execute_command('setregion ' .. value)
  elseif (cmd == 'mode') then
    self:message_send(EC54S.message.TYPE_UL_SET_ACK, dl_devid, dl_seq)
    self:execute_command('config_' .. value)
  elseif (cmd == 'siteno') then
    self:message_send(EC54S.message.TYPE_UL_SET_ACK, dl_devid, dl_seq)
    --self:config_save('siteno', value)
  end
end

function EC54S.agent:message_send(msg_type, devid, seq)
  
  local payload
  if (msg_type == EC54S.message.TYPE_UL_REPORT
    or msg_type == EC54S.message.TYPE_UL_QUERY_REPLY) then
    payload = self:report_update()
  elseif (msg_type == EC54S.message.TYPE_UL_SET_ACK) then
    payload = schar(EC54S.message.TYPE_UL_SET_ACK)
  elseif (msg_type == EC54S.message.TYPE_HI) then
    payload = schar(EC54S.message.TYPE_HI)
  elseif (msg_type == EC54S.message.TYPE_BYE) then
    payload = schar(EC54S.message.TYPE_BYE)
  else
    payload = schar(0x00)
  end
  
  local packet_raw = {}
  if (type(payload) == 'table') then
    packet_raw.data = tbl_flat(payload, '')
  else
    packet_raw.data = payload
  end
  
  -- fill in DL_REPORT|DL_SET seq & devid
  --print('message_send raw> seq|devid = ', devid, seq)
  if (seq) then packet_raw.seq = tonumber(seq) end
  if (devid) then packet_raw.devid = tonumber(devid) end
  local data = EC54S.Proto.encode(packet_raw)
  
  -- reply DL_REPORT|DL_SET right back
  -- or send to server:server_port
  local port = self.dl_port or self.server_port
  if (port == 0) then port = self.server_port end
  EC54S.Util.socket_send(self.socket_fd, data, self.server, port)
  
  -- DEBUG USE ONLY
  print(sfmt("EC54S.agent said +%s:%s (mt = %x)", self.server, port, msg_type))    -- print remote info
  EC54S.Util.dump_dec(data)    -- print in decimal
  EC54S.Util.dump_hex(data)    -- print in hexadecimal
end

-- ------------------------------------------------------------------------- --

function EC54S.agent:report_update()
    EC54S.Util.dbg("EC54S.agent:report_update()")
    
    local n = tonumber    -- shortcut
    
    local device = EC54S.Device1
    local gws_raw = device.param()
    local gws_abb = gws_raw.abb
    local gws_radio = gws_raw.radio
    
    local report_raw = {}
    tbl_push(report_raw, schar(EC54S.message.TYPE_UL_QUERY_REPLY)) -- BYTE 7: CMD_RPY
    
    local noise = gws_abb.noise or -110
    local signal = gws_abb.signal or noise
    noise = noise - (-110)
    signal = signal - (-110)
    if (signal < noise) then signal = noise end
    --print('agent raw> noise|signal = ', noise, signal)

    tbl_push(report_raw, schar(n(noise)))    -- Byte N1: noise
    tbl_push(report_raw, schar(n(signal)))    -- Byte N2: signal

    tbl_push(report_raw, schar(gws_radio.txpower or 0))    -- Byte N3: txpower
    tbl_push(report_raw, schar(gws_radio.channel or 0))    -- Byte N4: channel
    tbl_push(report_raw, schar(gws_abb.chanbw or 0))    -- Byte N5: chanbw

    tbl_push(report_raw, schar(EC54S.Util.mode_val(gws_abb.mode) or 0))    -- Byte N6: flag
    
    local peer_qty = gws_abb.peer_qty or 0
    tbl_push(report_raw, schar(peer_qty))    -- Byte N7: peer qty
    
    if (peer_qty > 0) then    -- Byte N7*X
      -- FIXME: add Byte N7*X @ 2017.07.03
      -- issue#1: rx_mcs|tx_mcs always = 0
      if (gws_abb.peers and #gws_abb.peers > 0) then
        for i, peer in ipairs(gws_abb.peers) do
          local peer_raw = {}
          local devid = ssub(peer.wmac, 13, 17) or '00:00'
          --print('ec54s raw> peer wmac|devid = ', peer.wmac, devid)
          tbl_push(peer_raw, schar('0x' .. ssub(devid, 1, 2)) .. schar('0x' .. ssub(devid, 4, 5)))    -- Byte X1, X2: last 2 bytes of Hex WMAC
          
          local rssi = peer.signal
          rssi = rssi - (-110)
          if (rssi < noise) then rssi = noise end
          tbl_push(peer_raw, schar(rssi or 0))    -- Byte X3
          
          tbl_push(peer_raw, schar(peer.rx_mcs or 0))    -- Byte X4
          tbl_push(peer_raw, schar(peer.tx_mcs or 0))    -- Byte X5

          tbl_push(peer_raw, schar(0))    -- Byte X6: reserved for txpower
          tbl_push(peer_raw, schar(0))    -- Byte X7: reserved for rxgain
        
          tbl_push(report_raw, tbl_flat(peer_raw)) -- append Byte X
        end
      end
    end

    local report = tbl_flat(report_raw, '')
    return report
end

-- ------------------------------------------------------------------------- --

-- TODO: Handle SET request
function EC54S.agent:execute_command(commands)    -- Internal API
    EC54S.Util.dbg("EC54S.agent:execute_command()")
    print('agent raw> command = ', commands)
    --ccff.exec(commands)
end

return (EC54S)
