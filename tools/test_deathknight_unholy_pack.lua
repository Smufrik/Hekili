local function read_file(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function expect(condition, message)
    if not condition then
        error(message, 2)
    end
end

local function expect_contains(text, needle, message)
    expect(text:find(needle, 1, true) ~= nil, message .. "\nmissing: " .. needle)
end

local unholy = read_file("MistsOfPandaria/DeathKnightUnholy.lua")

expect_contains(unholy, 'spec:RegisterPack( "Unholy", 20260603, [[Hekili:', "Unholy default pack date must be bumped when a new import string is installed.")
expect(not unholy:find('spec:RegisterPack(%s*"Unholy"%s*,%s*20260201', 1), "Unholy default pack must not keep the previous pack date.")

local pack = unholy:match('spec:RegisterPack%(%s*"Unholy"%s*,%s*20260603%s*,%s*%[%[(.-)%]%]%s*%)')
expect(pack ~= nil, "Unholy default pack must be registered with the expected date.")
expect(#pack == 5157, "Unholy default pack string length changed unexpectedly: " .. tostring(#pack))
expect(pack:sub(1, 80) == "Hekili:TZvBVnUns4FlPfWWPn112joD3dX7h6wu0U3DTfN3EF0sks02crwsqVKSUWq)2Vzi1lKuKu0oj", "Unholy default pack string prefix does not match the supplied import string.")
expect(pack:sub(-80) == "HWjL9zYSuArNlhh6070DwRp9Z31ESvAt)K2fL3BZMtL)L8ZZf)ex6QqZk9DzbGvD9Qv7l3aqWPnU()8d", "Unholy default pack string suffix does not match the supplied import string.")

print("death knight unholy pack checks passed")
