--!strict

local winreg = require("..")

local hkcu = winreg.RegKey.predef("HKEY_CURRENT_USER")

-- local robloxStudioReg = hkcu:openSubkey("Software\\Roblox\\RobloxStudio")
-- local contentFolderValue = robloxStudioReg:getRawValue("ContentFolder")

-- print(contentFolderValue)

local software = hkcu:openSubkey("Software")

print("before:", software:getValue("jiwonz"))

software:setValue("jiwonz", 123456)

print("after:", software:getRawValue("jiwonz"))
