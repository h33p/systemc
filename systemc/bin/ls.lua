
local function colorPrint(color, text)
	local fg = term.getTextColor()
	local bg = term.getBackgroundColor()
	term.setTextColor(color)
	print(text)
	term.setTextColor(fg)
end

local function getPermString(perms)
	local str = ""
	if fs.canRead(perms) then
		str = str.."r"
	else
		str = str.."-"
	end
	if fs.canWrite(perms) then
		str = str.."w"
	else
		str = str.."-"
	end
	if fs.canExec(perms) then
		str = str.."x"
	else
		str = str.."-"
	end
	return str
end

local function propsStringNormalize(lengths, props)
	str = ""
	for k, v in pairs(lengths) do
		while v > string.len(props[k]) do
			if k == 1 then
				props[k] = props[k].." "
			else
				props[k] = " "..props[k]
			end
		end
		if k ~= 1 then
			str = str.."  "
		end
		str = str..props[k]
	end
	return str
end

local tArgs = { ... }

-- Get all the files in the directory
local sDir = shell.dir()

local showProps = false
local bShowHidden = settings.get("list.show_hidden")
local asterExec = false
local slashDir = false
local human = false
local numIDs = true
local sort = true

for k, v in pairs(tArgs) do
	if string.sub(v, 1, 1) and string.len(v) > 1 then
		if string.match(v, "l") then
			showProps = true
		end
		if string.match(v, "a") then
			bShowHidden = true
		end
		if string.match(v, "F") then
			slashDir = true
			asterExec = true
		end
		if string.match(v, "f") then
			bShowHidden = true
			sort = false
		end
		if string.match(v, "p") then
			slashDir = true
		end
		if string.match(v, "h") then
			human = true
		end
		if string.match(v, "n") then
			numIDs = true
		end
	end
end
if tArgs[#tArgs] ~= nil and string.sub(tArgs[#tArgs], 1, 1) ~= "-" then
	sDir = shell.resolve( tArgs[#tArgs] )
end

print(sDir)

-- Sort into dirs/files, and calculate column count
local tAll = fs.list( sDir )
local tFiles = {}
local tDirs = {}

if sort then
	table.sort(tAll)
end

local lengths = {0, 0, 0, 0}

for n, sItem in pairs( tAll ) do
	if bShowHidden or string.sub( sItem, 1, 1 ) ~= "." then
		local sPath = fs.combine( sDir, sItem )
		if showProps then
			local perms = fs.getPerms(sPath)
			if perms == nil then
				print ("Null perms: " .. sPath)
			end
			local props = {}
			local propstr = ""
			if fs.isDir(sPath) then
				propstr = propstr.."d"
			else
				propstr = propstr.."-"
			end
			propstr = propstr..getPermString(perms.powner)
			propstr = propstr..getPermString(perms.pgroup)
			propstr = propstr..getPermString(perms.pothers)
			if perms.psuid then
				propstr = propstr.."s"
			end
			lengths[1] = math.max(lengths[1], string.len(propstr))
			table.insert(props, propstr)
			propstr = tostring(perms.owner).."\t"..tostring(perms.group)
			lengths[2] = math.max(lengths[2], string.len(propstr))
			table.insert(props, propstr)
			propstr = fs.getSize(sPath)
			lengths[3] = math.max(lengths[3], string.len(propstr))
			table.insert(props, propstr)
			propstr = sItem
			if slashDir and fs.isDir(sPath) then
				propstr = propstr.."/"
			elseif asterExec and fs.isExecuteable(sPath) then
				propstr = propstr.."*"
			end
			table.insert(props, propstr)
			
			if fs.isDir( sPath ) then
				table.insert( tDirs, props )
			else
				table.insert( tFiles, props )
			end
		else
			if fs.isDir( sPath ) then
				table.insert( tDirs, sItem )
			else
				table.insert( tFiles, sItem )
			end
		end
	end
end

if showProps then
	if term.isColour() then
		for n, sItem in pairs(tDirs) do
			colorPrint(colors.green, propsStringNormalize(lengths, sItem))
		end
		for n, sItem in pairs(tFiles) do
			colorPrint(colors.white, propsStringNormalize(lengths, sItem))
		end
	else
		for n, sItem in pairs(tDirs) do
			print(propsStringNormalize(lengths, sItem))
		end
		for n, sItem in pairs(tFiles) do
			print(propsStringNormalize(lengths, sItem))
		end
	end
else
	if term.isColour() then
		textutils.pagedTabulate( colors.green, tDirs, colors.white, tFiles )
	else
		textutils.pagedTabulate( tDirs, tFiles )
	end
end
