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


-- The full link you are at
---@type string
---@const
theccwww.link.fulllink = nil

-- The page you are at
---@type string
---@const
theccwww.link.page = nil

-- The domain you are at
---@type string
---@const
theccwww.link.domain = nil
