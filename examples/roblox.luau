local winreg = require("..")

local hkcu = winreg.RegKey.predef("HKEY_CURRENT_USER")

local robloxStudioReg = hkcu:openSubkey("Software\\Roblox\\RobloxStudio")

local contentFolderValue: string = robloxStudioReg:getValue("ContentFolder")

local robloxPlayerReg = hkcu:openSubkey("Software\\ROBLOX Corporation\\Environments\\roblox-player")

local clientExeValue = robloxPlayerReg:getValue("clientExe")

print(`Roblox Studio content folder path: {contentFolderValue}\nRoblox Player exe path: {clientExeValue}`)
