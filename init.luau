--!strict

local Result = require("Result")
local process = require("@lune/process")
local pathfs = require("submodules/pathfs")
local winreg = {}

type HKEY = "HKEY_CLASSES_ROOT"
| "HKEY_CURRENT_USER"
| "HKEY_LOCAL_MACHINE"
| "HKEY_USERS"
| "HKEY_PERFORMANCE_DATA"
| "HKEY_PERFORMANCE_TEXT"
| "HKEY_PERFORMANCE_NLSTEXT"
| "HKEY_CURRENT_CONFIG"
| "HKEY_DYN_DATA"
| "HKEY_CURRENT_USER_LOCAL_SETTINGS"

export type RegKey = typeof(setmetatable(
	{} :: {
		hkey: HKEY,
		reg: string,
		openedSubKey: string?
	},
	{} :: RegKeyImpl
))

type RegKeyImpl = {
	__index: RegKeyImpl,
	predef: (hkey: HKEY) -> (RegKey),
	openSubkey: (self: RegKey, subkey: string) -> Result.Result<RegKey, string>
}

local RegKey = {} :: RegKeyImpl
RegKey.__index = RegKey

function RegKey.predef(hkey)
	return setmetatable({
		hkey = hkey,
		reg = winreg.getRegProgram()
	}, RegKey)
end

function RegKey.openSubkey(self, subkey)
	subkey = self.hkey .. "\\" .. subkey
	local result = process.spawn(self.reg, { "QUERY", subkey, "/ve" })
	if result.ok then
		self.openedSubKey = subkey
		return Result.Ok(self)
	end
	return Result.Err(`Could not find subkey '{subkey}' ({result.stderr})`)
end

winreg.RegKey = RegKey

function winreg.getRegProgram()
	if process.os == "windows" then
		local path = pathfs.Path.from(process.env.windir)
		path:push("system32")
		path:push("reg.exe")
		if pathfs.isFile(path) then
			return path:toString()
		end
	end
	return "REG"
end

return winreg
