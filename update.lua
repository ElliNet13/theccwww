print("Would you like to update The Computercraft World Wide Web using HTTP? (y/n)")
local answer = read()

if answer ~= "y" then
    print("Aborting")
    return
end

local startingDir = shell.getDir()

-- Normalizes a path
local function normalizePath(path)
    if string.sub(path, 1, 1) ~= "/" then
        path = "/" .. path
    end
    if #path > 1 and string.sub(path, -1) == "/" then
        path = string.sub(path, 1, -2)
    end
    return path
end

local programDir = normalizePath(fs.getDir(shell.getRunningProgram()))
local CCArchive = programDir
print("[Updater] Starting HTTP update...")
local tempDir = "/tmptheccwwwhttpupdate" .. math.random(10000, 99999)
fs.makeDir(tempDir)

if not http then print("[Updater] HTTP is disabled and not available. Aborting update.") return end

print("[Updater] Checking internet connection...")
local testRequest = http.get("https://example.tweaked.cc")
if testRequest.getResponseCode() ~= 200 then print("[Updater] Could not connect to example.tweaked.cc. You may be offline. Aborting update.") return end

print("[Updater] Downloading update...")
local file = http.get("https://n8n.ellinet13.com/webhook/update.tar.gz?item=theccwww")
if file.getResponseCode() ~= 200 then print("[Updater] Could not download update because of HTTP error " .. file.getResponseCode() .. ". Aborting update.") return end

local fileData = file.readAll()
file.close()

if fileData == nil or fileData == "" then
    print("[Updater] Could not download update, file is empty. Aborting update.")
    return
end
        
local file = fs.open(fs.combine(tempDir, "theccwww.tar.gz"), "w")
file.write(fileData)
file.close()

local tar = normalizePath(fs.combine(CCArchive, "tar.lua"))
print("[Updater] Using tar: " .. tar)

print("[Updater] Extracting update...")
shell.setDir(tempDir)
shell.run(tar, "-xzf", "theccwww.tar.gz")
        
print("[Updater] Running setup...")
shell.run("setup.lua")

print("[Updater] Cleaning up...")
shell.setDir("/")
fs.delete(tempDir)
shell.setDir(startingDir)