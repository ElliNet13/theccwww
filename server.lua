-- Requirements
local tinyyaml = require("tinyyaml")

-- Open the modem
peripheral.find("modem", rednet.open)

-- Load config
local dir = fs.getDir(shell.getRunningProgram())
local files = fs.combine(dir, "files")

if not fs.exists(dir .. "/config.yaml") then
    print("Creating config.yaml with default config")
    print("Make sure to change your hostname in the file!")
    fs.copy(dir .. "/server.default.yaml", dir .. "/config.yaml")
end

local file = fs.open(dir .. "/config.yaml", "r")
local config = tinyyaml.parse(file.readAll())
file.close()
local hostname = config.hostname

print("Starting server as " .. hostname)
print("Files: " .. files)

-- Check if files exist
if not fs.exists(files) then
    print("Creating files directory with default files")
    fs.makeDir(files)
end

-- Create 404 page
if not fs.exists(files .. "/404.lua") then
    print("Creating 404 page")
    fs.copy(files .. "/404.default.lua", files .. "/404.lua")
end

-- Create index page
if not fs.exists(files .. "/index.lua") then
    print("Creating index page")
    fs.copy(files .. "/index.default.lua", files .. "/index.lua")
end

-- Start hosting
rednet.host("theccwww", hostname)

local function serverLoop()
    while true do
        local id, message = rednet.receive("theccwww")
        if message == "" then
            print("Sending index to " .. id)
            message = "index"
        end
        if fs.exists(dir .. "/files/" .. message ) then
            -- No more changes to the message is needed, it is just a file
            print("Sending file " .. message .. " to " .. id)
        elseif fs.exists(dir .. "/files/" .. message .. ".lua") then
            -- It's a page
            print("Sending page " .. message .. " to " .. id)
            message = message .. ".lua"
        else
            -- It's a 404
            print("Sending 404 to " .. id .. " because " .. message .. " does not exist")
            message = "404.lua"
        end
        local path = fs.combine(files, message)
        if not string.find(path, files .. "/") then
            print("[CANCELED] Computer " .. id .. " requested file " .. message .. " outside of " .. files .. " directory")
            path = fs.combine(files, "404.lua")
        end
        print("Sending final path " .. path .. " to " .. id)
        local file = fs.open(path, "r")
        local content = file.readAll()
        file.close()
        rednet.send(id, content, "theccwww")
        print("[DONE] Sent " .. path .. " to " .. id)
    end
end

serverLoop()
