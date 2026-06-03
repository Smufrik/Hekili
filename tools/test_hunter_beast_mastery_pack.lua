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

local bm = read_file("MistsOfPandaria/HunterBeastMastery.lua")

expect_contains(bm, 'spec:RegisterPack( "Beast Mastery", 20260603, [[Hekili:', "Beast Mastery default pack date must be bumped when a new import string is installed.")
expect(not bm:find('spec:RegisterPack%(%s*"Beast Mastery"%s*,%s*20260201', 1), "Beast Mastery default pack must not keep the previous pack date.")

local pack = bm:match('spec:RegisterPack%(%s*"Beast Mastery"%s*,%s*20260603%s*,%s*%[%[(.-)%]%]%s*%)')
expect(pack ~= nil, "Beast Mastery default pack must be registered with the expected date.")
expect(#pack == 3829, "Beast Mastery default pack string length changed unexpectedly: " .. tostring(#pack))
expect(pack:sub(1, 80) == "Hekili:TVvBVTnos4Flblqq62D1zjhNUDrCa6lxVTfx7vSUh2VjjAj6yHil5tsUP5qG(TFZqkrrkrkjl", "Beast Mastery default pack string prefix does not match the supplied import string.")
expect(pack:sub(-80) == "s9AK5Toq6PAfWj09cBL8A6jPxLxbOxVQb6Km)vc(ogTZux7NuSUPTEoUvzqsouSfBWjuy7MSO7yd6(Fc", "Beast Mastery default pack string suffix does not match the supplied import string.")
expect(not pack:find("hunterbm", 1, true), "The trailing class label must not be included in the Beast Mastery import string.")

print("hunter beast mastery pack checks passed")
