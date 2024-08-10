# winreg-lune (WIP)
A lune module that provides access to the Windows Registry through the REG commandline tool

## Usage
Install with git submodule
```sh
git submodule add [url] [path/to/submodule]
```

Example code
```luau
local hkcu = winreg.RegKey.predef("HKEY_CURRENT_USER")

local robloxStudioReg = hkcu:openSubkey("Software\\Roblox\\RobloxStudio")

```

## Inspiration
`winreg-lune` is heavily inspired by [winreg-rs](https://github.com/gentoo90/winreg-rs) and [node-winreg](https://github.com/fresc81/node-winreg)
