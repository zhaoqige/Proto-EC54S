-- by Qige <qigezhao@gmail.com>
-- 2017.06.29 setmetatable|signal|ccff|conf

local ccff = require 'qutil.ccff'
local PROTO = require 'qec54s.ec54s'

local ts = os.time
local sfmt = string.format
local echo = io.write
local cfgr = ccff.conf.get

local Agent = {}

Agent.conf = {}
Agent.conf._SIGNAL = '/tmp/.ec54s_signal'
Agent.conf.siteno = cfgr('ec54s','v2','siteno') or '254'
Agent.conf.remote = cfgr('ec54s','v2','server') or '192.168.1.3'
Agent.conf.remote_port = cfgr('ec54s','v2','server_port') or 3001
Agent.conf.port = cfgr('ec54s','v2','port') or 3001

function Agent.run(remote)
  local agent
  local error_message

  local s = sfmt("Agent (%s|%s|%s:%s) start @ %d\n", 
    Agent.conf.siteno, Agent.conf.port, 
    Agent.conf.remote, Agent.conf.remote_port,
    ts())
  echo(s)
  Agent.log(s)

  agent = PROTO.agent.daemon(
    Agent.conf.siteno, 
    remote or Agent.conf.remote, 
    Agent.conf.remote_port, 
    Agent.conf.port
  )

  error_message = agent:service_init(1 or 0.2)    -- rel: 0.2, debug: 1

  if (error_message == nil) then
    local i
    while true do
      if (Agent.QUIT_SIGNAL()) then
        break
      end
      agent:service_handle()
      agent:idle()
    end
  else
    print(error_message)
  end

  agent:destroy()
  local s = sfmt("Agent stopped @ %d\n", ts())
  echo(s)
  Agent.log(s)
end

function Agent.log(message)
  local fsig = Agent.conf._SIGNAL
  ccff.file.write(fsig, message)
end

function Agent.QUIT_SIGNAL()
  local signal =  false
  local exit_array = {
    "exit","exit\n",
    "stop","stop\n",
    "quit","quit\n",
    "bye","byte\n",
    "down","down\n"
  }
  local fsig = Agent.conf._SIGNAL
  local sig = ccff.file.read(fsig)
  for k,v in ipairs(exit_array) do
    if (sig == v) then
      signal = true
      break
    end
  end
  return signal
end

return Agent
