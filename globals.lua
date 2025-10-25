-- globals.lua for defining functions and variables for site's on The Computercraft World Wide Web
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class theccwww
theccwww = {}

---Sends you to another website
---@param site string The URL of the website
---@param page string The page of the website
function theccwww.gotosite(site, page) end

---Sends you to another page on the site
---@param page string The path or page name
function theccwww.gotopage(page) end


---The full link you are at
---@type string
---@const
theccwww.link.fulllink = nil

---The page you are at
---@type string
---@const
theccwww.link.page = nil

---The domain you are at
---@type string
---@const
theccwww.link.domain = nil

---Function to prompt yes/no 
---@param question string
---@return boolean
function theccwww.promptYesNo(question) end

---Require a link 
---@param domain string The domain that hosts the file
---@param path string The path to the lua file on the domain
---@return any
function theccwww.require(path, domain) end

---The domain you are at
---@type table
---@const
theccwww.speakers = nil

---Function to get a file handle, will be nil if the upload is canceled.
---@param mode string The mode to open the file in
---@return file* | nil
function theccwww.file(mode) end


-- Main global table for dynamic pages
---@class TheCCWWWServer
theccwwwserver = {}

-- HTTP method (GET, POST, etc.)
---@type string
theccwwwserver.method = "GET"

-- Requested path, e.g. "/index"
---@type string
theccwwwserver.path = "/"

-- Query parameters parsed from URL
---@type table<string, string>
theccwwwserver.query = {}

-- Request headers
---@type table<string, string>
theccwwwserver.headers = {}

-- POST body as string (empty for GET)
---@type string
theccwwwserver.body = ""

-- HTTP status code to return (default 200)
---@type integer
theccwwwserver.statusCode = 200

-- URL to redirect client (optional)
---@type string|nil
theccwwwserver.redirect = nil

-- Log message to server console
---@param msg string
theccwwwserver.log = function(msg) end

-- Generate a UUID string
---@return string
theccwwwserver.uuid = function() end