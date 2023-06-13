local tArgs = {...}

local function usage ()
	print ("Usage: chmod [oga]+[rwxs] file1 file2")
	print("Or: chmod XXX file")
end

if tostring(tonumber(tArgs[1])) == tArgs[1] then
	local owner = tonumber(string.sub(tArgs[1], 1, 1))
	if owner == nil then error ("String expected") end
	local group = tonumber(string.sub(tArgs[1], 2, 2))
	if group == nil then error ("String expected") end
	local others = tonumber(string.sub(tArgs[1], 3, 3))
	if others == nil then error ("String expected") end
	local i = 2
	while i <= #tArgs do
		if fs.exists(tArgs[i]) then fs.setPerms(tArgs[i], { powner = owner, pgroup = group, pothers = others }) end 
		i = i + 1
	end
else
	local i = 2
	while i <= #tArgs do
		if string.sub(tArgs[i], 1, 1) ~= "/" then
			tArgs[i] = fs.combine(shell.dir(), tArgs[i])
		end
		
		local perms = fs.getPerms(tArgs[i])
		local o = 3
		local b = {}
		local add = false
		if string.sub(tArgs[1], 1, 1) == "+" or string.sub(tArgs[1], 1, 1) == "-" then
			o = 2
			b = { "powner", "pgroup", "pothers" }
			add = string.sub(tArgs[1], 1, 1) == "+"
		elseif string.match(tArgs[1], "+") == "+" then
			local u = string.match(tArgs[1], "([^=]+)+")
			local y = 1
			while y <= #u do
				if string.sub(u, y,y) == "u" then table.insert(b, "powner") end
				if string.sub(u, y,y) == "g" then table.insert(b, "pgroup") end
				if string.sub(u, y,y) == "o" then table.insert(b, "pothers") end
				y = y + 1
			end
			o = #u + 1
			add = true
		elseif string.match(tArgs[1], "-") == "-" then
			local u = string.match(tArgs[1], "([^=]+)-")
			local y = 1
			while y <= #u do
				if string.sub(u, y,y) == "u" then table.insert(b, "powner") end
				if string.sub(u, y,y) == "g" then table.insert(b, "pgroup") end
				if string.sub(u, y,y) == "o" then table.insert(b, "pothers") end
				y = y + 1
			end
			o = #u + 1
			add = false
		else
			usage()
			return
		end

		while o <= #tArgs[1] do
			local r = 1
			while r <= #b do
				local t = string.sub(tArgs[1], o, o)
				if t == "r" and add and not fs.canRead(perms[b[r]]) then perms[b[r]] = perms[b[r]] + 4
				elseif t == "r" and not add and fs.canRead(perms[b[r]]) then perms[b[r]] = perms[b[r]] - 4 end
				if t == "w" and add and not fs.canWrite(perms[b[r]]) then perms[b[r]] = perms[b[r]] + 2
				elseif t == "w" and not add and fs.canWrite(perms[b[r]]) then perms[b[r]] = perms[b[r]] - 2 end
				if t == "x" and add and not fs.canExec(perms[b[r]]) then perms[b[r]] = perms[b[r]] + 1
				elseif t == "x" and not add and fs.canExec(perms[b[r]]) then perms[b[r]] = perms[b[r]] - 1 end
				if t == "s" and add then perms.psuid = true
				elseif t == "s" and not add then perms.psuid = false end
				r = r + 1
			end
			o = o + 1
		end
		fs.setPerms(tArgs[i], perms)
		i = i + 1
	end

end
