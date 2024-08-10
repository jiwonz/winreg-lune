--!strict

local process = require("@lune/process")
local pathfs = require("submodules/pathfs")
local RegExp = require("submodules/RegExp")
local qword = require("src/qword")
local winreg = {}

export type HKEY = "HKEY_CLASSES_ROOT"
| "HKEY_CURRENT_USER"
| "HKEY_LOCAL_MACHINE"
| "HKEY_USERS"
| "HKEY_PERFORMANCE_DATA"
| "HKEY_PERFORMANCE_TEXT"
| "HKEY_PERFORMANCE_NLSTEXT"
| "HKEY_CURRENT_CONFIG"
| "HKEY_DYN_DATA"
| "HKEY_CURRENT_USER_LOCAL_SETTINGS"

export type RegTypes = "REG_SZ"
| "REG_MULTI_SZ"
| "REG_EXPAND_SZ"
| "REG_DWORD"
| "REG_QWORD"
| "REG_BINARY"
| "REG_NONE"

export type RegValue = {
	bytes: string,
	vtype: RegTypes
}

local KEY_PATTERN = RegExp.new("(\\[a-zA-Z0-9_\\s]+)*")
local PATH_PATTERN  = RegExp.new("^(HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER|HKEY_CLASSES_ROOT|HKEY_USERS|HKEY_CURRENT_CONFIG)(.*)$")
local ITEM_PATTERN  = RegExp.new("^(.*)\\s(REG_SZ|REG_MULTI_SZ|REG_EXPAND_SZ|REG_DWORD|REG_QWORD|REG_BINARY|REG_NONE)\\s+([^\\s].*)$")
local REG_TYPES = {
	"REG_SZ",
	"REG_MULTI_SZ",
	"REG_EXPAND_SZ",
	"REG_DWORD",
	"REG_QWORD",
	"REG_BINARY",
	"REG_NONE"
}

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

function winreg.exist(key: string)
	local result = process.spawn(winreg.getRegProgram(), { "QUERY", key, "/ve" })
	if result.ok then
		return true
	end
	return false
end

local parsers = {
	REG_DWORD = function(v)
		return tonumber(v)
	end,
	REG_QWORD = function(v)
		return qword(v)
	end,
	REG_BINARY = function(v)
		return buffer.fromstring(v)
	end,
	REG_NONE = function()
		return nil
	end
}
winreg.parse = function(type: RegTypes, encodedValue: string?): any
	local v = encodedValue or ""
	local parser = parsers[type]
	if parser then
		return parser(v)
	end
	return encodedValue
end :: ((type: "REG_SZ", encodedValue: string) -> (string))
& ((type: "REG_MULTI_SZ", encodedValue: string) -> (string))
& ((type: "REG_DWORD", encodedValue: string) -> (number))
& ((type: "REG_QWORD", encodedValue: string) -> (buffer))
& ((type: "REG_BINARY", encodedValue: string) -> (buffer))
& ((type: "REG_NONE", encodedValue: string) -> (nil))

local regTypeMap = {
	string = function(v: string): RegValue
		return {
			bytes = v,
			vtype = "REG_SZ"
		}
	end,
	number = function(v: number): RegValue
		return {
			bytes = tostring(v),
			vtype = "REG_DWORD"
		}
	end,
	boolean = function(v: boolean): RegValue
		return {
			bytes = v and "1" or "0",
			vtype = "REG_DWORD"
		}
	end
}
function winreg.toRegValue(value: any): RegValue?
	local regTypeMapMatch = regTypeMap[typeof(value)]
	if regTypeMapMatch then
		return regTypeMapMatch(value)
	end
	return
end

export type RegKey = typeof(setmetatable(
	{} :: {
		hkey: string
	},
	{} :: RegKeyImpl
))

type RegKeyImpl = {
	__index: RegKeyImpl,
	predef: (hkey: HKEY) -> (RegKey),
	openSubkey: (self: RegKey, subkey: string) -> (RegKey),
	getRawValue: (self: RegKey, name: string?) -> (RegValue),
	getValue: (self: RegKey, name: string?) -> (any),
	setRawValue: (self: RegKey, name: string?, regValue: RegValue) -> (),
	setValue: (self: RegKey, name: string?, value: any) -> ()
}

local RegKey = {} :: RegKeyImpl
RegKey.__index = RegKey

local function trim(str: string): string
	return str:match("^%s*(.-)%s*$") or str
end

function RegKey.predef(hkey)
	if not winreg.exist(hkey) then
		error(`'{hkey}' is not a valid HKEY`)
	end
	return setmetatable({
		hkey = hkey :: string
	}, RegKey)
end

function RegKey.openSubkey(self, subkey)
	subkey = self.hkey .. "\\" .. subkey
	local exist = winreg.exist(subkey)
	if exist then
		return setmetatable({
			hkey = subkey
		}, RegKey)
	end
	error(`Could not find subkey '{subkey}'`)
end

function RegKey.getRawValue(self, name)
	local params = { "QUERY", self.hkey }
	if not name or name == "" then
		table.insert(params, "/ve")
	else
		table.insert(params, "/v")
		table.insert(params, name)
	end
	local result = process.spawn(winreg.getRegProgram(), params)
	if result.ok then
		local items = {}
		local lines = result.stdout:split('\r\n')

		for i, line in lines do
			line = trim(line);
			if #line > 1 then
				if i ~= 1 then
					table.insert(items, line)
				end
			end
		end

		local item = items[#items] or ""
		local match = ITEM_PATTERN:exec(item)

		if match then
			local type = trim(match[3])
			local value: string = match[4]
			return {
				vtype = type :: any,
				bytes = value
			}
		else
			error("Failed to parse value item (no match found)")
		end
	else
		error(`Failed to get value of '{name}' (reason: {result.stderr})`)
	end
end

function RegKey.getValue(self, name)
	local item = self:getRawValue(name)
	return winreg.parse(item.vtype :: any, item.bytes)
end

function RegKey.setRawValue(self, name, regValue)
	if not table.find(REG_TYPES, regValue.vtype) then
		error(`Illegal type specified '{regValue.vtype}'`)
	end
	local params = { "ADD", self.hkey }
	if not name or name == "" then
		table.insert(params, "/ve")
	else
		table.insert(params, "/v")
		table.insert(params, name)
	end
	table.insert(params, "/t")
	table.insert(params, regValue.vtype)
	table.insert(params, "/d")
	table.insert(params, regValue.bytes)
	table.insert(params, "/f")
	local result = process.spawn(winreg.getRegProgram(), params)
	if not result.ok then
		error(`Failed to add value '{name}: {regValue.vtype} = {regValue.bytes}' (reason: {result.stderr})`)
	end
end

function RegKey.setValue(self, name, value)
	local regValue = winreg.toRegValue(value)
	if regValue then
		self:setRawValue(name, regValue)
	else
		error(`Unsupported value type '{typeof(value)}'`)
	end
end

winreg.RegKey = RegKey

return winreg
