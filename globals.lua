-- globals.lua for defining functions and variables for site's on The Computercraft World Wide Web

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

---Sends you to another page on the site
---@param domain string The domain that hosts the file
---@param path string The path to the file on the domain
function theccwww.save(domain, path) end

---Function to prompt yes/no 
---@param question string
---@return boolean
---@diagnostic disable-next-line: missing-return
function theccwww.promptYesNo(question) end

---Require a link 
---@param domain string The domain that hosts the file
---@param path string The path to the lua file on the domain
---@return any
---@diagnostic disable-next-line: missing-return
function theccwww.require(domain, path) end

---The domain you are at
---@type table
---@const
theccwww.speakers = nil

---Function to get a file handle, will be nil if the upload is canceled.
---@param mode string The mode to open the file in
---@return file* | nil
---@diagnostic disable-next-line: missing-return
function theccwww.upload(mode) end
