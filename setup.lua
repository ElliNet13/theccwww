print("Welcome to the The Computercraft World Wide Web setup script!")
print("This script will install the The Computer program.")
print("Are you sure you want to continue? (y/n)")
local answer = read()

local destination = "/theccwww"

if answer ~= "y" then
    print("Aborting")
    return
end

-- If the destination exists, only delete things that are NOT config.yaml or files/
if fs.exists(destination) then
    for _, item in ipairs(fs.list(destination)) do
        if item ~= "config.yaml" and item ~= "files" then
            fs.delete(destination .. "/" .. item)
        end
    end
else
    fs.makeDir(destination)
end

-- Copy the new files into the destination
local sourceFiles = fs.getDir(shell.getRunningProgram()) .. "/files"
for _, file in ipairs(fs.list(sourceFiles)) do
    fs.copy(sourceFiles .. "/" .. file, destination .. "/" .. file)
end

-- Delete the files directory if it is empty
local filesPath = "/theccwww/files"
if fs.exists(filesPath) and fs.isDir(filesPath) then
    if #fs.list(filesPath) == 0 then
        fs.delete(filesPath)
    end
end

print("Setup finished!")
print("Installed to " .. destination)
print("To access websites, run the browser.lua script in the " .. destination .. " directory.")
print("To host your own website, run the server.lua script in the " .. destination .. " directory.")
