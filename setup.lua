print("Welcome to the The Computercraft World Wide Web setup script!")
print("This script will install the The Computer program.")
print("Are you sure you want to continue? (y/n)")
local answer = read()

local destination = "/theccwww"

if answer ~= "y" then
    print("Aborting")
    return
end

if fs.exists(destination) then
    fs.delete(destination)
end

fs.makeDir(destination)

for _, file in ipairs(fs.list(fs.getDir(shell.getRunningProgram()) .. "/files")) do
    fs.copy(fs.getDir(shell.getRunningProgram()) .. "/files/" .. file, destination.."/"..file)
end

print("Setup finished!")
print("Installed to " .. destination)
print("To access websites, run the browser.lua script in the " .. destination .. " directory.")
print("To host your own website, run the server.lua script in the " .. destination .. " directory.")
