local tArgs = { ... }

local clear = true

local exec = "/rom/programs/shell"

if #tArgs > 0 then
	if tArgs[1] == "--noclear" then
		clear = false
	end
end

if clear then
	term.clear()
	term.setCursorPos(1,1)
end

sDir = "/"
_shell = {}
_shell.dir = function () return sDir end
_shell.getRunningProgram = function () return fs.combine(systemc.binDir, "init") end
local _alias = {}
_shell.setAlias = function (v1, v2) _alias[v1] = v2 end
_shell.aliases = function () return _alias end

local tCompletionInfo = {}

function _shell.setCompletionFunction( sProgram, fnComplete )
  tCompletionInfo[ sProgram ] = {
    fnComplete = fnComplete
  }
end
_shell.getCompletionInfo = function () return tCompletionInfo end

-- Setup paths
local sPath = ".:/rom/programs"
if term.isColor() then
	sPath = sPath..":/rom/programs/advanced"
end
if turtle then
	sPath = sPath..":/rom/programs/turtle"
else
    sPath = sPath..":/rom/programs/rednet:/rom/programs/fun"
    if term.isColor() then
    	sPath = sPath..":/rom/programs/fun/advanced"
    end
end
if pocket then
    sPath = sPath..":/rom/programs/pocket"
end
if commands then
    sPath = sPath..":/rom/programs/command"
end
if http then
	sPath = sPath..":/rom/programs/http"
end

sPath = sPath..":/"..systemc.binDir

_shell.path = function () return sPath end

-- Setup aliases
_shell.setAlias( "list", "ls" )
_shell.setAlias( "dir", "ls" )
_shell.setAlias( "cp", "copy" )
_shell.setAlias( "mv", "move" )
_shell.setAlias( "rm", "delete" )
_shell.setAlias( "clr", "clear" )
_shell.setAlias( "rs", "redstone" )
_shell.setAlias( "sh", "shell" )
if term.isColor() then
    _shell.setAlias( "background", "bg" )
    _shell.setAlias( "foreground", "fg" )
end

_shell.resolve = function ( _sPath )
	local sStartChar = string.sub( _sPath, 1, 1 )
	if sStartChar == "/" or sStartChar == "\\" then
		return fs.combine( "", _sPath )
	else
		return fs.combine( sDir, _sPath )
	end
end

_shell.programs = function( _bIncludeHidden )
	local tItems = {}
	
	-- Add programs from the path
    for sPath in string.gmatch(sPath, "[^:]+") do
    	sPath = _shell.resolve( sPath )
			if fs.isDir( sPath ) then
				local tList = fs.list( sPath )
        	for n=1,#tList do
            local sFile = tList[n]
						if not fs.isDir( fs.combine( sPath, sFile ) ) and
				  		(_bIncludeHidden or string.sub( sFile, 1, 1 ) ~= ".") then
							tItems[ sFile ] = true
						end
					end
				end
    end	

	-- Sort and return
	local tItemList = {}
	for sItem, b in pairs( tItems ) do
		table.insert( tItemList, sItem )
	end
	table.sort( tItemList )
	return tItemList
end

_shell.completeProgram = function ( sLine )
	if #sLine > 0 and string.sub( sLine, 1, 1 ) == "/" then
	    -- Add programs from the root
	    return fs.complete( sLine, "", true, false )

    else
        local tResults = {}
        local tSeen = {}

        -- Add aliases
        for sAlias, sCommand in pairs( _alias ) do
            if #sAlias > #sLine and string.sub( sAlias, 1, #sLine ) == sLine then
                local sResult = string.sub( sAlias, #sLine + 1 )
                if not tSeen[ sResult ] then
                    table.insert( tResults, sResult )
                    tSeen[ sResult ] = true
                end
            end
        end

        -- Add programs from the path
        local tPrograms = _shell.programs()
        for n=1,#tPrograms do
            local sProgram = tPrograms[n]
            if #sProgram > #sLine and string.sub( sProgram, 1, #sLine ) == sLine then
                local sResult = string.sub( sProgram, #sLine + 1 )
                if not tSeen[ sResult ] then
                    table.insert( tResults, sResult )
                    tSeen[ sResult ] = true
                end
            end
        end

        -- Sort and return
        table.sort( tResults )
        return tResults
    end
end

-- Setup completion functions
local function completeMultipleChoice( sText, tOptions, bAddSpaces )
    local tResults = {}
    for n=1,#tOptions do
        local sOption = tOptions[n]
        if #sOption + (bAddSpaces and 1 or 0) > #sText and string.sub( sOption, 1, #sText ) == sText then
            local sResult = string.sub( sOption, #sText + 1 )
            if bAddSpaces then
                table.insert( tResults, sResult .. " " )
            else
                table.insert( tResults, sResult )
            end
        end
    end
    return tResults
end
local function completePeripheralName( sText, bAddSpaces )
    return completeMultipleChoice( sText, peripheral.getNames(), bAddSpaces )
end
local tRedstoneSides = redstone.getSides()
local function completeSide( sText, bAddSpaces )
    return completeMultipleChoice( sText, tRedstoneSides, bAddSpaces )
end
local function completeFile( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return fs.complete( sText, _shell.dir(), true, false )
    end
end
local function completeDir( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return fs.complete( sText, _shell.dir(), false, true )
    end
end
local function completeEither( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return fs.complete( sText, _shell.dir(), true, true )
    end
end
local function completeEitherEither( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        local tResults = fs.complete( sText, _shell.dir(), true, true )
        for n=1,#tResults do
            local sResult = tResults[n]
            if string.sub( sResult, #sResult, #sResult ) ~= "/" then
                tResults[n] = sResult .. " "
            end
        end
        return tResults
    elseif nIndex == 2 then
        return fs.complete( sText, _shell.dir(), true, true )
    end
end
local function completeProgram( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return _shell.completeProgram( sText )
    end
end
local function completeHelp( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return help.completeTopic( sText )
    end
end
local function completeAlias( shell, nIndex, sText, tPreviousText )
    if nIndex == 2 then
        return _shell.completeProgram( sText )
    end
end
local function completePeripheral( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return completePeripheralName( sText )
    end
end
local tGPSOptions = { "host", "host ", "locate" }
local function completeGPS( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return completeMultipleChoice( sText, tGPSOptions )
    end
end
local tLabelOptions = { "get", "get ", "set ", "clear", "clear " }
local function completeLabel( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return completeMultipleChoice( sText, tLabelOptions )
    elseif nIndex == 2 then
        return completePeripheralName( sText )
    end
end
local function completeMonitor( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return completePeripheralName( sText, true )
    elseif nIndex == 2 then
        return _shell.completeProgram( sText )
    end
end
local tRedstoneOptions = { "probe", "set ", "pulse " }
local function completeRedstone( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return completeMultipleChoice( sText, tRedstoneOptions )
    elseif nIndex == 2 then
        return completeSide( sText )
    end
end
local tDJOptions = { "play", "play ", "stop " }
local function completeDJ( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return completeMultipleChoice( sText, tDJOptions )
    elseif nIndex == 2 then
        return completePeripheralName( sText )
    end
end
local tPastebinOptions = { "put ", "get ", "run " }
local function completePastebin( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return completeMultipleChoice( sText, tPastebinOptions )
    elseif nIndex == 2 then
        if tPreviousText[2] == "put" then
            return fs.complete( sText, _shell.dir(), true, false )
        end
    end
end
local tChatOptions = { "host ", "join " }
local function completeChat( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return completeMultipleChoice( sText, tChatOptions )
    end
end
local function completeSet( shell, nIndex, sText, tPreviousText )
    if nIndex == 1 then
        return completeMultipleChoice( sText, settings.getNames(), true )
    end
end
_shell.setCompletionFunction( "rom/programs/alias.lua", completeAlias )
_shell.setCompletionFunction( "rom/programs/cd.lua", completeDir )
_shell.setCompletionFunction( "rom/programs/copy.lua", completeEitherEither )
_shell.setCompletionFunction( "rom/programs/delete.lua", completeEither )
_shell.setCompletionFunction( "rom/programs/drive.lua", completeDir )
_shell.setCompletionFunction( "rom/programs/edit.lua", completeFile )
_shell.setCompletionFunction( "rom/programs/eject.lua", completePeripheral )
_shell.setCompletionFunction( "rom/programs/gps.lua", completeGPS )
_shell.setCompletionFunction( "rom/programs/help.lua", completeHelp )
_shell.setCompletionFunction( "rom/programs/id.lua", completePeripheral )
_shell.setCompletionFunction( "rom/programs/label.lua", completeLabel )
_shell.setCompletionFunction( "rom/programs/list.lua", completeDir )
_shell.setCompletionFunction( "rom/programs/mkdir.lua", completeFile )
_shell.setCompletionFunction( "rom/programs/monitor.lua", completeMonitor )
_shell.setCompletionFunction( "rom/programs/move.lua", completeEitherEither )
_shell.setCompletionFunction( "rom/programs/redstone.lua", completeRedstone )
_shell.setCompletionFunction( "rom/programs/rename.lua", completeEitherEither )
_shell.setCompletionFunction( "rom/programs/shell.lua", completeProgram )
_shell.setCompletionFunction( "rom/programs/type.lua", completeEither )
_shell.setCompletionFunction( "rom/programs/set.lua", completeSet )
_shell.setCompletionFunction( "rom/programs/advanced/bg.lua", completeProgram )
_shell.setCompletionFunction( "rom/programs/advanced/fg.lua", completeProgram )
_shell.setCompletionFunction( "rom/programs/fun/dj.lua", completeDJ )
_shell.setCompletionFunction( "rom/programs/fun/advanced/paint.lua", completeFile )
_shell.setCompletionFunction( "rom/programs/http/pastebin.lua", completePastebin )
_shell.setCompletionFunction( "rom/programs/rednet/chat.lua", completeChat )

if term.isColour() and settings.get( "bios.use_multishell" ) then
	os.run( {shell = _shell}, "/rom/programs/advanced/multishell.lua")
else
	os.run( {shell = _shell}, "/rom/programs/shell.lua")
end
