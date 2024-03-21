package.path = "/engine/?.lua"
require "bootstrap"

local ltask = require "ltask"

ltask.uniqueservice "s|network"
ltask.uniqueservice("s|arguments", ...)
ltask.uniqueservice "s|vfsmgr"

local socket = dofile "/pkg/s/socket.lua"

local fd, err
while true do
    fd, err = socket.bind("tcp", "0.0.0.0", 2018)
    if fd then
        break
    end
    print(err)
    ltask.sleep(10)
end

local SERVICE_ROOT <const> = 1
local function post_spawn(name, ...)
    return ltask.send(SERVICE_ROOT, "spawn", name, ...)
end

post_spawn "s|ios/event"
post_spawn "s|android/event"

while true do
    local newfd, err = socket.listen(fd)
    if newfd then
        post_spawn("s|agent", newfd)
    else
        print(err)
    end
end
