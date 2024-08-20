local binaryUtil = {}

local function sm(a, b)
	local result
	if a % b == 0 then
		result = a
	else
		result = math.ceil(a / b) * b
	end
	return result
end

function binaryUtil.zeroPad(str, length)
	local strLength = #str
	if strLength >= length then
		return str
	end
	return string.rep("0", length - strLength) .. str
end

function binaryUtil.binaryStringToByteArray(binaryString: string)
	local byteArray = {}
	local length = #binaryString

	if length % 8 ~= 0 then
		error("Binary string length is not a multiple of 8 (cannot slice into bytes)")
	end

	for i = 1, length, 8 do
		local byteStr = binaryString:sub(i, i + 7)
		local byteValue = 0

		for j = 1, 8 do
			byteValue = byteValue * 2 + (byteStr:sub(j, j) == "1" and 1 or 0)
		end

		table.insert(byteArray, byteValue)
	end

	local byteCount: number = #byteArray
	local b = buffer.create(byteCount)
	for i = 0, byteCount - 1 do
		buffer.writeu8(b, i, byteArray[byteCount - i])
	end

	return b
end

function binaryUtil.zeroPadBinaryString(binaryString: string)
	local length = #binaryString
	return binaryUtil.zeroPad(binaryString, sm(length, 8))
end

function binaryUtil.byteToBinary(byte: number)
	local binary_str = ""
	for i = 7, 0, -1 do
		local bit = bit32.band(bit32.rshift(byte, i), 1)
		binary_str = binary_str .. bit
	end
	return binary_str
end

function binaryUtil.byteArrayToBinary(buf: buffer): string
	local length = buffer.len(buf)
	local binaries = table.create(length)
	for offset = 0, length - 1 do
		table.insert(binaries, binaryUtil.byteToBinary(buffer.readu8(buf, offset)))
	end
	return table.concat(binaries)
end

return binaryUtil
