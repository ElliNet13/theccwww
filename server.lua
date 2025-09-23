-- Requirements
local tinyyaml = require("tinyyaml")

-- Open the modem
peripheral.find("modem", rednet.open)

-- Load config
local dir = fs.getDir(shell.getRunningProgram())

if not fs.exists(dir .. "/config.yaml") then
    fs.copy(dir .. "/server.default.yaml", dir .. "/config.yaml")
end

local file = fs.open(dir .. "/config.yaml", "r")
local config = tinyyaml.parse(file.readAll())
file.close()
local hostname = config.hostname

print("Starting server as " .. hostname)

-- Check if files exist
if not fs.exists(dir .. "/files") then
    fs.makeDir(dir .. "/files")
    fs.copy(dir .. "/index.default.lua", dir .. "/files/index.lua")
    fs.copy(dir .. "/404.default.lua", dir .. "/files/404.lua")
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
            message = "404"
        end
        local file = fs.open(dir .. "/files/" .. message, "r")
        local content = file.readAll()
        file.close()
        rednet.send(id, content, "theccwww")
    end
end

local function errorHandler(err)
    rednet.unhost("theccwww")
    return err       -- rethrow the original error
end

xpcall(serverLoop, errorHandler)