
if systemc ~= nil then
	error("SystemC is already running!")
end

local tArgs = { ... }

local target = "graphical" 

if #tArgs >= 2 and tArgs[1] == "-target" then
	target = tArgs[2]
end

local runningProgram = shell.getRunningProgram()
local programName = fs.getName(runningProgram)
os.loadAPI(fs.combine(runningProgram:sub( 1, #runningProgram - #programName ), "../lib/systemc.lua"))

--TLCO

local a = _G.printError
function _G.printError()
	_G.printError=a
	_G['rednet'] = nil
	print("Starting version "..systemc.version())
	print()
	--[[parallel.waitForAny(
		function()
			while not systemc.loaded do
				sleep()
			end
			if term.isColour() then
				os.run( {uid = 0}, "/rom/programs/advanced/multishell")
			else
				os.run( {uid = 0}, "/rom/programs/shell")
			end
			os.run( {uid = 0}, "/rom/programs/shutdown")
		end,
		function()]]
			local runningProgram = shell.getRunningProgram()
			local programName = fs.getName(runningProgram)

			systemc.run(fs.combine(runningProgram:sub( 1, #runningProgram - #programName ), "../"), target)
		--end )
	print("SystemC halted! Shutting down!")
	sleep (1)
	os.shutdown ()

end
os.queueEvent("terminate")

sleep(1)
