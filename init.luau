--!strict

local process = require("@lune/process")
local pathfs = require("submodules/pathfs")
local RegExp = require("submodules/RegExp")
local qword = require("src/qword")
local binaryUtil = require("src/binaryUtil")
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
	bytes: string | buffer,
	vtype: RegTypes
}

--[=[
	If name is empty or length <= 0 (aka "") it means (Default) key
]=]
export type Name = string?

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

function winreg.exist(path: string)
	local result = process.spawn(winreg.getRegProgram(), { "QUERY", path, "/ve" })
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
		local zeroPadded = binaryUtil.zeroPadBinaryString(v)
		return binaryUtil.binaryStringToByteArray(zeroPadded)
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
	end,
	buffer = function(v: buffer): RegValue
		return {
			bytes = binaryUtil.byteArrayToBinary(v),
			vtype = "REG_BINARY"
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

function winreg.toRawBytes(bytes: string | buffer): string
	if typeof(bytes) == "buffer" then
		return binaryUtil.byteArrayToBinary(bytes)
	end
	return bytes
end

export type RegKey = typeof(setmetatable(
	{} :: {
		hkey: string
	},
	{} :: RegKeyImpl
))

type RegKeyImpl = {
	__index: RegKeyImpl,
	--[=[
		Open one of predefined keys:
		* `HKEY_CLASSES_ROOT`
		* `HKEY_CURRENT_USER`
		* `HKEY_LOCAL_MACHINE`
		* `HKEY_USERS`
		* `HKEY_PERFORMANCE_DATA`
		* `HKEY_PERFORMANCE_TEXT`
		* `HKEY_PERFORMANCE_NLSTEXT`
		* `HKEY_CURRENT_CONFIG`
		* `HKEY_DYN_DATA`
		* `HKEY_CURRENT_USER_LOCAL_SETTINGS`
	]=]
	predef: (hkey: HKEY) -> (RegKey),
	--[=[
		Open subkey.
	]=]
	openSubkey: (self: RegKey, path: string) -> (RegKey),
	--[=[
		Get type and raw bytes (`string`) with registry value `RegValue` struct.
	]=]
	getRawValue: (self: RegKey, name: Name) -> (RegValue),
	--[=[
		Get a value from registry and seamlessly convert it to the specified luau type.

		Will get the `Default` value if `name` is an empty string.
	]=]
	getValue: (self: RegKey, name: Name) -> (any),
	--[=[
		Write raw bytes (`string` or `buffer`) from `RegValue` struct to a registry value.

		Will get the `Default` value if `name` is an empty string.
	]=]
	setRawValue: (self: RegKey, name: Name, regValue: RegValue) -> (),
	--[=[
		Seamlessly convert a value from a luau type and write it to the registry value.

		Will set the `Default` value if `name` is an empty string.
	]=]
	setValue: (self: RegKey, name: Name, value: any) -> (),
	--[=[
		Get a array of keys in current RegKey.

		Will set the `Default` value if `name` is an empty string.
	]=]
	getKeys: (self: RegKey) -> ({ { path: string, hkey: string, key: string } }),
	--[=[
		Get a array of values in current RegKey.
	]=]
	getValues: (self: RegKey) -> ({ [string]: RegValue }),
	--[=[
		Create this registry key. Open a subkey if the key already exists.
	]=]
	createSubkey: (self: RegKey, path: string) -> (),
	--[=[
		Join subkey path into current hkey path
	]=]
	joinSubkey: (self: RegKey, path: string) -> (string),
	--[=[
		Delete specified subkey. Key names are not case sensitive.
	]=]
	deleteSubkey: (self: RegKey, path: string) -> (),
	--[=[
		Delete specified value from registry.

		Will delete the `Default` value if `name` is an empty string.
	]=]
	deleteValue: (self: RegKey, name: Name) -> (),
	--[=[
		Delete all subkeys and values.
	]=]
	clear: (self: RegKey) -> (),
	--[=[
		Similar to `setValue()` but allows to update value only not type unlike `setValue()`.
	]=]
	updateValue: (self: RegKey, name: Name, value: any) -> (),
	--[=[
		Similar to `setRawValue()` but allows to update value only not type unlike `setRawValue()`.
	]=]
	updateRawValue: (self: RegKey, name: Name, regValue: RegValue) -> (),
	--[=[
		Rename a subkey.

		It's almost the same as performing `copySubkey()` and `removeSubkey()`.
	]=]
	renameSubkey: (self: RegKey, path: string, newPath: string) -> (),
	--[=[
		Copy all the values and subkeys from `path` to `dest` key.
	]=]
	copySubkey: (self: RegKey, path: string, dest: string) -> (),
	--[=[
		Clone this RegKey into `dest` and open the clone.
	]=]
	clone: (self: RegKey, dest: string) -> (),
	--[=[
		Delete this RegKey and its all subkeys.
	]=]
	destroy: (self: RegKey) -> (),
	--[=[
		Find first value of current RegKey.

		unlike `getValue()`, does not raise an error if value was not found.
	]=]
	findFirstValue: (self: RegKey, name: Name) -> (any?),
	--[=[
		Find first raw value of current RegKey.

		unlike `getRawValue()`, does not raise an error if value was not found.
	]=]
	findFirstRawValue: (self: RegKey, name: Name) -> (RegValue?)
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

function RegKey.openSubkey(self, path)
	local fullpath = self:joinSubkey(path)
	local exist = winreg.exist(fullpath)
	if exist then
		return setmetatable({
			hkey = fullpath
		}, RegKey)
	end
	error(`Failed to find subkey '{path}' (full path: '{fullpath}')`)
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
		error(`Failed to get value of '{name}' in '{self.hkey}' (reason: {result.stderr})`)
	end
end

function RegKey.getValue(self, name)
	local item = self:getRawValue(name)
	return winreg.parse(item.vtype :: any, winreg.toRawBytes(item.bytes))
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
	table.insert(params, winreg.toRawBytes(regValue.bytes))
	table.insert(params, "/f")
	local result = process.spawn(winreg.getRegProgram(), params)
	if not result.ok then
		error(`Failed to set value '{name}: {regValue.vtype} = {regValue.bytes}' in '{self.hkey}' (reason: {result.stderr})`)
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

function RegKey.getKeys(self)
	local params = { "QUERY", self.hkey }
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

		local keys = {}

		for _, item in items do
			local match = PATH_PATTERN:exec(item)

			if match then
				local path: string = match[1]
				local hkey: string = match[2]
				local key: string = match[3]
				table.insert(keys, {
					path = path,
					hkey = hkey,
					key = key:sub(2, -1)
				})
			end
		end

		return keys
	else
		error(`Failed to get keys in current path '{self.hkey}' (reason: {result.stderr})`)
	end
end

function RegKey.getValues(self)
	local params = { "QUERY", self.hkey }
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

		local values = {}

		for _, item in items do
			local match = ITEM_PATTERN:exec(item)

			if match then
				local name = trim(match[2])
				local type = trim(match[3])
				local value: string = match[4]
				values[name] = {
					vtype = type :: any,
					bytes = value
				}
			end
		end

		return values
	else
		error(`Failed to get values in current path '{self.hkey}' (reason: {result.stderr})`)
	end
end

function RegKey.createSubkey(self, path)
	local fullpath = self:joinSubkey(path)
	local params = { "ADD", fullpath, "/f" }
	local result = process.spawn(winreg.getRegProgram(), params)
	if result.ok then
		return setmetatable({
			hkey = fullpath
		}, RegKey)
	else
		error(`Failed to create subkey '{fullpath}' (reason: {result.stderr})`)
	end
end

function RegKey.joinSubkey(self, path)
	local fullpath = self.hkey .. "\\" .. path
	return fullpath
end

function RegKey.deleteSubkey(self, path)
	local fullpath = self:joinSubkey(path)
	local params = { "DELETE", fullpath, "/f" }
	local result = process.spawn(winreg.getRegProgram(), params)
	if not result.ok then
		error(`Failed to delete subkey '{fullpath}' (reason: {result.stderr})`)
	end
end

function RegKey.deleteValue(self, name)
	local params = { "DELETE", self.hkey, "/f" }
	if not name or name == "" then
		table.insert(params, "/ve")
	else
		table.insert(params, "/v")
		table.insert(params, name)
	end
	local result = process.spawn(winreg.getRegProgram(), params)
	if not result.ok then
		error(`Failed to delete value of '{name}' in '{self.hkey}' (reason: {result.stderr})`)
	end
end

function RegKey.clear(self)
	local params = { "DELETE", self.hkey, "/f", "/ve" }
	local result = process.spawn(winreg.getRegProgram(), params)
	if not result.ok then
		error(`Failed to clear values in '{self.hkey}' (reason: {result.stderr})`)
	end
end

function RegKey.updateValue(self, name, value)
	local regValue = winreg.toRegValue(value)
	local oldRegValue = self:getRawValue(name)
	if regValue then
		if regValue.vtype == oldRegValue.vtype then
			self:setRawValue(name, regValue)
		else
			error(`Could not update value. Cannot assign '{regValue.vtype}' into '{oldRegValue.vtype}'`)
		end
	else
		error(`Unsupported value type '{typeof(value)}'`)
	end
end

function RegKey.updateRawValue(self, name, regValue)
	local oldRegValue = self:getRawValue(name)
	if regValue.vtype == oldRegValue.vtype then
		self:setRawValue(name, regValue)
	else
		error(`Could not update value. Cannot assign '{regValue.vtype}' into '{oldRegValue.vtype}'`)
	end
end

winreg.RegKey = RegKey

return winreg
