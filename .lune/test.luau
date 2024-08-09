--!strict

local winreg = require("..")

local hkcu = winreg.RegKey.predef("HKEY_CURRENT_USER")

print("Result:", hkcu:openSubkey("Software\\Roblox\\RobloxStudio"):unwrap())
