local disk = peripheral.find("drive")

if not disk or not disk.isDiskPresent() then
    print("No disk found")
    return
end

local destination = disk.getMountPath()

print("Are you sure you want to create an installer for " .. destination .. "? (y/n)")
local answer = read()

if answer ~= "y" then
    print("Aborting")
    return
end

for _, file in ipairs(fs.list(destination)) do
    fs.delete(destination.."/"..file)
end

fs.makeDir(destination.."/files")

local prodFiles = {
    "browser.lua",
    "server.lua",
    "tinyyaml.lua",
    "server.default.yaml",
    "404.default.lua",
    "index.default.lua",
    "globals.lua"
}

for _, file in ipairs(prodFiles) do
    fs.copy(fs.getDir(shell.getRunningProgram()) .. "/" .. file, destination.."/files/"..file)
end

fs.copy(fs.getDir(shell.getRunningProgram()) .. "/setup.lua", destination.."/setup.lua")

print("Disk created!")