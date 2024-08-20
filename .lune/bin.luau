local binaryUtil = require("../src/binaryUtil")

local zeroPadded = binaryUtil.zeroPadBinaryString("010")
print(zeroPadded)
print(buffer.readu8( binaryUtil.binaryStringToByteArray(zeroPadded) , 0))

local function byte_to_binary_string(byte)
    local binary_str = ""
    for i = 7, 0, -1 do
        local bit = bit32.band(bit32.rshift(byte, i), 1)
        binary_str = binary_str .. bit
    end
    return binary_str
end

print(byte_to_binary_string(255))
