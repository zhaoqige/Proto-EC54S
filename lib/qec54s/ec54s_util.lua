-- learn from https://github.com/geekscape/mqtt_lua
-- by Qige <qigezhao@gmail.com>
-- 2017.06.29

local echo = io.write

local function isPsp() return (Socket ~= nil) end
if (isPsp()) then socket = Socket end    -- Compatibility !

local debug_flag = false
local function set_debug(value) debug_flag = value end
local function dbg(message)
    if (debug_flag) then
        print(string.format("util dbg> %s @ %d", message, os.time()))
    end
end

local function dump_dec(str)
    if (str) then
        local index
        for index = 1, string.len(str) do
            echo(string.format("B%d-%d ", index, string.byte(str, index)))
        end
        print()
    end
end

local function dump_hex(str)
    if (str) then
        local index
        for index = 1, string.len(str) do
            echo(string.format("B%d-%02X ", index, string.byte(str, index)))
        end
        print()
    end
end

-- ------------------------------------------------------------------------- --

local timer
if (isPsp()) then
    timer = Timer.new()
    timer:start()
end

local function get_time()
    if (isPsp()) then
        return (timer:time()/1000)
    else
        return (socket.gettime())
    end
end

local function expired(last_time, duration, type)
    local time_expired = get_time() >= (last_time + duration)
    return (time_expired)
end

-- ------------------------------------------------------------------------- --

local function shift_left(value, shift)
    return (value * 2 ^ shift)
end
local function shift_right(value, shift)
    return (value / 2 ^ shift)
end

-- ------------------------------------------------------------------------- --

local function socket_raw()
    return socket.udp()
end

local function socket_send(socket_fd, data, host, port)
    if (socket_fd and data and host and port) then
        socket_fd:sendto(data, host, port)
        --print('util raw> message:')
        --dump_dec(data)
        --dump_hex(data)
    end
end

local function socket_recv(socket_fd)
  if (socket_fd) then
    return socket_fd:receivefrom()
  end
  return nil
end

local function socket_wait_connected(socket_fd)
    if (isPsp()) then
        while(socket_fd.isConnected == false) do
            print('util raw> not connected @ %d', os.time())
            System.sleep(0.5)
        end
    else
        socket.sleep(0.001) -- So that socket.receive doesn't block
    end
end

-- ------------------------------------------------------------------------- --

local function mode_val(mode)
  --print('Utility raw> mode = ', mode)
  if (mode) then
    if (mode == 'Master' or mode == 'CAR' or mode == 'car') then
      return 2
    elseif (mode == 'Client' or mode == 'EAR' or mode == 'ear') then
      return 1
    end
  end
  return 0
end

local Utility = {}

Utility.set_debug     = set_debug
Utility.dbg           = dbg
Utility.dump_dec      = dump_dec
Utility.dump_hex      = dump_hex

Utility.get_time      = get_time
Utility.expired       = expired

Utility.shift_left    = shift_left
Utility.shift_right   = shift_right

Utility.socket_raw    = socket_raw
Utility.socket_send   = socket_send
Utility.socket_recv   = socket_recv
Utility.socket_wait_connected = socket_wait_connected

Utility.mode_val      = mode_val

return Utility
