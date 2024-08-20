--!strict

local winreg = require("..")

local hkcu = winreg.RegKey.predef("HKEY_CURRENT_USER")

-- local robloxStudioReg = hkcu:openSubkey("Software\\Roblox\\RobloxStudio")
-- local contentFolderValue = robloxStudioReg:getRawValue("ContentFolder")

-- print(contentFolderValue)

local software = hkcu:openSubkey("Software")

-- print("before:", software:getValue("jiwonz"))
-- local b0 = software:getValue("jiwonz")
-- print("read uint8:", buffer.readu8(b0, 0))

-- local b = buffer.create(1)
-- buffer.writeu8(b, 0, 255)
-- software:setRawValue("jiwonz", {
-- 	vtype = "REG_BINARY",
-- 	bytes = b
-- })

-- print("after:", software:getRawValue("jiwonz"))

print(software:getValues())
print(software:getKeys())
