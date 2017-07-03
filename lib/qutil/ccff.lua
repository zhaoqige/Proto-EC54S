-- by Qige <qigezhao@gmail.com>
-- 2017.06.30

local uci = require 'uci'

local ccff = {}

function ccff.execute(cmd)
	if (cmd) then
		local pipe = io.popen(cmd)
		local prompt = pipe:read("*all")
		io.close(pipe)
		return prompt
	end
	return nil
end

ccff.conf = {}
function ccff.conf.get(conf, sec, opt)
  local result
	if (uci) then
		if (conf and sec and opt) then
			local uc = uci.cursor()
			result = uc:get(conf, sec, opt)
		end
	end
	return result
end

function ccff.conf.set(conf, sec, opt, val)
	if (uci) then
		if (conf and sec and opt and val) then
			local uc = uci.cursor()
			uc:set(conf, sec, opt, val)
		end
	end
end

ccff.file = {}
function ccff.file.read(path)
	local content = ''
	if (path) then
    local fd = io.open(path, "r+")
    if (fd) then
      content = fd:read("*all")
      fd:close()
    end
	end
	return content
end

function ccff.file.write(path, data)
	if (path and data) then
		local fd = io.open(path, "w")
		fd:write(data)
		fd:close()
	end
end

function ccff.file.cp(src, des)
	local content = ccff.read(src)
	ccff.write(des, content)
end

function ccff.triml(str, cnt)
  if (str) then
    return string.sub(str, 1 + cnt, -1)
  end
end

function ccff.trimr(str, cnt)
  if (str) then
    return string.sub(str, 1, -1 - cnt)
  end
end

ccff.val = {}
function ccff.val.s(str)
  if (str) then
    return tostring(str)
  end
  return '?'
end

function ccff.val.n(str)
  if (str) then
    return tonumber(str)
  end
  return 0
end

return ccff