local tArgs = { ... }

local showOurs = true
local showOthers = false
local jMode = true

for k, v in pairs(tArgs) do
	if string.sub(v, 1, 1) == "-" and string.len(v) > 1 then
		if string.match(v, "a") then
			showOthers = true
			showOurs = true
		elseif string.match(v, "A") then
			showOurs = false
			showOthers = true
		elseif string.match(v, "j") then
			jMode = true
		end
	end
end

local function propsStringNormalize(lengths, props)
	str = ""
	for k, v in pairs(lengths) do
		while v > string.len(props[k]) do
			if k == 1 then
				props[k] = props[k].." "
			elseif k ~= 3 then
				props[k] = " "..props[k]
			else
				break
			end
		end
		if k ~= 1 then
			str = str.."  "
		end
		str = str..props[k]
	end
	return str
end

local lengths = {4, 3, 7}

local procs = systemc.get_processes()

local outp = {{"USER", "PID", "COMMAND"}}

for k, v in pairs(procs) do
	if (showOurs and k == process.uid) or (showOthers and k ~= process.uid) then
		proc = {}
		local procstr = tostring(v.uid)
		table.insert(proc, procstr)
		lengths[1] = math.max(lengths[1], string.len(procstr))
		procstr = tostring(k)
		table.insert(proc, procstr)
		lengths[2] = math.max(lengths[2], string.len(procstr))
		procstr = tostring(v.exec)
		table.insert(proc, procstr)
		lengths[3] = math.max(lengths[3], string.len(procstr))
		table.insert(outp, proc)
	end
end

local function colorPrint(color, text)
	local fg = term.getTextColor()
	local bg = term.getBackgroundColor()
	term.setTextColor(color)
	print(text)
	term.setTextColor(fg)
end


if term.isColour() then
	for n, sItem in pairs(outp) do
		colorPrint(colors.green, propsStringNormalize(lengths, sItem))
	end
else
	for n, sItem in pairs(outp) do
		print(propsStringNormalize(lengths, sItem))
	end
end
