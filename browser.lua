-- Start modems
peripheral.find("modem", rednet.open)

print("Enter the link to go to: ")
local destination = read()

-- Look up the destination
local domain, path = destination:match("^([^/]+)(/?.*)$")

if not domain then
    print("Invalid link")
    return
end

if not path then
    path = ""
end

-- Make theccwww
local theccwww = {}

-- Set the link
theccwww.link = {
    fulllink = destination,
    page = path,
    domain = domain
}

local server = nil
local sandbox = {}

-- Goto a page
function theccwww.gotopage(page)
    local x, y = term.getSize()
    print("Changing page to " .. (page or ("The homepage of" .. theccwww.link.domain)))
    theccwww.link.page = page or ""
    theccwww.link.fulllink = theccwww.link.domain .. "/" .. theccwww.link.page

    print("Sending message to " .. theccwww.link.domain)
    local gotSent = rednet.send(server, page or "", "theccwww")

    if not gotSent then
        error("Failed to send message to " .. theccwww.link.domain)
    end

    local id, message
    local maxWait = 5         -- seconds
    local elapsed = 0

    repeat
        -- Wait 1 second each loop
        id, message = rednet.receive("theccwww", 1)

        elapsed = elapsed + 1
        print("Loading page... will timeout in " .. (maxWait - elapsed) .. " seconds")

        if elapsed >= maxWait then
            error("Timeout: no response from server within " .. maxWait .. " seconds")
        end
    until id == server

    term.clear()
    term.setCursorPos(1, 1)
    load(message, "Website", "t", sandbox)()
    print()
    term.setCursorPos(1, y)
    print("Site done (Execution finished): " .. theccwww.link.fulllink)
end

-- Goto a site
function theccwww.gotosite(site, page)
    print("Changing site to " .. site)

    theccwww.link.domain = site
    theccwww.link.fulllink = site .. "/" .. (page or "")

    print("Looking up server for " .. site)
    -- Lookup server first
    server = rednet.lookup("theccwww", site)
    if not server then
        error("No server found for domain " .. site)
    end

    print("Sending message to " .. server)

    -- Send only the page path
    local gotSent = rednet.send(server, page or "")

    if not gotSent then
        error("Failed to send message to " .. site)
    end

    theccwww.gotopage(page or "")
end

-- Create a sandbox
sandbox = {
    print = print,
    error = error,
    pairs = pairs,
    ipairs = ipairs,
    type = type,
    tonumber = tonumber,
    tostring = tostring,
    math = math,
    string = string,
    table = table,
    server = server,
    theccwww = theccwww,
    term = term,
    rednet = {
        receive = rednet.receive,
        send = rednet.send
    },
    read = read,
    os = {
        clock = os.clock,
        time = os.time,
        date = os.date,
        pullEvent = os.pullEvent,
        sleep = os.sleep
    }
}

-- Go to the home page
theccwww.gotosite(theccwww.link.domain, theccwww.link.page)
