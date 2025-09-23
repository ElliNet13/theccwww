print("Welcome to the default site!")
print("This is the home page of the default site.")
print("If you are the owner of this site, you can change the home page by editing files/index.lua")
if theccwww.promptYesNo("Do you want to download this page?") then
    theccwww.save(theccwww.link.domain, theccwww.link.page)
end
