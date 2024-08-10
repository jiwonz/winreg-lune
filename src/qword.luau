--!nocheck
--!optimize 2

local function leftPad(str, length, padChar)
    padChar = padChar or "0"
    local strLength = #str
    if strLength >= length then
        return str
    end
    return string.rep(padChar, length - strLength) .. str
end

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

local function binaryStringToByteArray(binaryString)
    local byteArray = {}
    local length = #binaryString

    if length % 8 ~= 0 then
        error("Binary string length is not a multiple of 8")
    end

    for i = 1, length, 8 do
        local byteStr = binaryString:sub(i, i + 7)
        local byteValue = 0

        for j = 1, 8 do
            byteValue = byteValue * 2 + (byteStr:sub(j, j) == "1" and 1 or 0)
        end

        table.insert(byteArray, byteValue)
    end

	local b = buffer.create(8)
	for i = 0, 7 do
		buffer.writeu8(b, i, byteArray[8 - i])
	end

    return b
end

local function detectNumberFormat(str)
    -- Remove leading/trailing whitespace
    str = str:match("^%s*(.-)%s*$")

    -- Check for hexadecimal format (must have '0x' or '0X' prefix)
    if str:match("^0[xX]%x+$") then
        return "hexadecimal"

    -- Check for decimal format (including negative numbers and decimals)
    elseif str:match("^-?%d+%.?%d*$") then
        return "decimal"

    -- If it doesn't match either format
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
		error(`QWORD must be a string-typed number, god {hexOrDec}`)
	elseif numberFormat == "hexadecimal" then
		hexOrDec = hexToDecimal(hexOrDec)
	end
	if detectNumberFormat(hexOrDec) == "decimal" then
		return setmetatable({
			_buffer = binaryStringToByteArray(leftPad(decimalToBinary(hexOrDec), 64)),
			_decimal = hexOrDec
		}, QWORD)
	end
	error(`QWORD must be hexadecimal or decimal, got {hexOrDec}`)
end
