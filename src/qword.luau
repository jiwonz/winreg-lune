--!nocheck
--!optimize 2

local binaryUtil = require("binaryUtil")

local function decimalToBinary(decimalString)
	local binaryString = ""
	local decimalNumber = decimalString

	while decimalNumber ~= "0" do
		local remainder = tonumber(decimalNumber:sub(-1)) % 2
		binaryString = remainder .. binaryString

		local newDecimal = ""
		local carry = 0
		for i = 1, #decimalNumber do
			local digit = tonumber(decimalNumber:sub(i, i)) + carry * 10
			local quotient = math.floor(digit / 2)
			carry = digit % 2
			if newDecimal ~= "" or quotient > 0 then
				newDecimal = newDecimal .. quotient
			end
		end
		decimalNumber = newDecimal == "" and "0" or newDecimal
	end

	return binaryString == "" and "0" or binaryString
end

local function detectNumberFormat(str)
	str = str:match("^%s*(.-)%s*$")

	if str:match("^0[xX]%x+$") then
		return "hexadecimal"

	elseif str:match("^-?%d+%.?%d*$") then
		return "decimal"

	else
		return "unknown"
	end
end

local function addStrings(a, b)
	local result = ""
	local carry = 0
	local i, j = #a, #b

	while i > 0 or j > 0 or carry > 0 do
		local sum = carry
		if i > 0 then sum = sum + tonumber(a:sub(i, i)); i = i - 1 end
		if j > 0 then sum = sum + tonumber(b:sub(j, j)); j = j - 1 end
		result = tostring(sum % 10) .. result
		carry = math.floor(sum / 10)
	end

	return result
end

local function multiplyString(s, n)
	local result = "0"
	for _ = 1, tonumber(n) do
		result = addStrings(result, s)
	end
	return result
end

local function hexToDecimal(hex_str)
	hex_str = hex_str:gsub("^0x", ""):upper()
	local decimal = "0"
	local hex_to_dec = {
		["0"] = 0, ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4,
		["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9,
		["A"] = 10, ["B"] = 11, ["C"] = 12, ["D"] = 13, ["E"] = 14, ["F"] = 15
	}

	for i = 1, #hex_str do
		local digit = hex_to_dec[hex_str:sub(i, i)]
		decimal = addStrings(multiplyString(decimal, "16"), tostring(digit))
	end

	return decimal
end

export type QWORD = typeof(setmetatable(
	{} :: {
		_buffer: buffer,
		_decimal: string
	},
	{} :: QWORDImpl
))

type QWORDImpl = {
	__index: QWORDImpl,
	__tostring: (self: QWORD) -> (string),
	toBuffer: (self: QWORD) -> (buffer)
}

local QWORD = {} :: QWORDImpl
QWORD.__index = QWORD

function QWORD.__tostring(self)
	return "QWORD(" .. self._decimal .. ")"
end

function QWORD.toBuffer(self)
	return self._buffer
end

return function(hexOrDec: string): QWORD
	local numberFormat = detectNumberFormat(hexOrDec)
	if numberFormat == "unknown" then
		error(`QWORD must be a string-typed number, got {hexOrDec}`)
	elseif numberFormat == "hexadecimal" then
		hexOrDec = hexToDecimal(hexOrDec)
	end
	if detectNumberFormat(hexOrDec) == "decimal" then
		return setmetatable({
			_buffer = binaryUtil.binaryStringToByteArray(binaryUtil.zeroPad(decimalToBinary(hexOrDec), 64)),
			_decimal = hexOrDec
		}, QWORD)
	end
	error(`QWORD must be hexadecimal or decimal, got {hexOrDec}`)
end
