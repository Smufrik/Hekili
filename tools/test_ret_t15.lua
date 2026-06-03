local function read_file(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function expect_contains(text, needle, message)
    if not text:find(needle, 1, true) then
        error(message .. "\nmissing: " .. needle, 2)
    end
end

local function expect_not_contains(text, needle, message)
    if text:find(needle, 1, true) then
        error(message .. "\nfound: " .. needle, 2)
    end
end

local ret = read_file("MistsOfPandaria/PaladinRetribution.lua")
local apl = read_file("MistsOfPandaria/Priorities/PaladinRetribution.simc")
local toc = read_file("Hekili.toc")
local core = read_file("Hekili.lua")

expect_contains(toc, "## Interface: 50504", "TOC interface must target WoW 5.5.4.")
expect_contains(toc, "## Version: v5.5.4-1", "TOC version must identify the 5.5.4 addon build.")
expect_contains(core, 'Hekili.Version = "v5.5.4-1"', "Addon runtime version must identify the 5.5.4 build.")
expect_contains(ret, 'spec:RegisterPack( "Retribution", 20260603, [[Hekili:', "Ret default pack date must be bumped when a new import string is installed.")
expect_contains(ret, "Hekili:9Qv3UTTnu4NLIbi0015jlB30neLl2UzRxumm1RLeTeTnxKL0iPsAam0Z(oKYYIKIuYjdTOOTj8Nd)o)9XZHqXlJ)sCuoIJJ)CGFWh8)G)QfblxUEZTXr8NRXXr1OShq7HFOeDe(3)gZPKTnCsvPyUNlQq5czWQAOzW8rKJ)ofTJ3MUz9h)PpghTTHuW)ZY4TwpN1BGTwJZI)8T(Xrhi554ULIzzXrF5aH1Mk(lQn9mqAtR2b)EMabTPfeghMExfTn9pWpqkilayrR2rkaW8dTP)fQaLtk)12ufK3(PU9ZwutXzvh3I4)y4pVTaZyKY9jv7sEa(F27j7c32SB3cghXzlYREQ0t(79Ruo08c7iz)b(fHDeX4y6ZVmXvxjg79cFq4XQ9nj1vpHPjDdBFl)tt((J4s(LzHXyyuHarCAd)WG6PoAhUeB5rCcUeFKGz31VcQqtWvnSsaXj8dum7qvrUx3H(MqFpjaGJnprShwiitSneOjPrirBwBi6(W5G0CazslQaqV9SVPQkVOHXxqXWMpDQByuzgbSTDBArtDNJe9iUCVWP)efbwYM6BoDIJO7X8fCYrCcVkjNGVlCT)nQqHu(Vnegr)GvguAaoDA0Wu8rePKDxyWnEVfu6N7GZ9HRSESdR4Db(Nfxo5rsjoPUHwxXWD6Og20vPlokvy0uRUH9niAobvk8n9wj9Sj37vIq5jIPILZrfW2xOo8cCjcYxY9gBLaVWGkkmkQIUHHtiC8XohoWeu(aMVuCipIOeHixCEWe2ZLzjSIkE4spBhITiafpK(ea1r2dHlVcWemdyc(gbgzeEYUg6ZAJIPmmv440IgOzOsrafLAWSG)kotYTcPBLCCzgwXboEYPDJVoLstRke0cSKdiGdqnwsB8V5O4C6fdmyhfGWKelqnVnCZejL9epA5cAr8qA)0hUC)uiMItW0LFizDDwNSTcIrluHRXgkvSmU3Qk8G4)6ceLL8igimYKxqAbhtQWZjpNMtp7Z0b01ACsYifbBMKbuDQNqe(7z4SWSk4ghq)xyS4EjkGYCR5EFV5wYDH(lcEDEy7xpDvMVr7Yt)y2ipgDHLrByOCqfyap2d4jKfdeZ2QYgMHabZHTJrRcPxeQT7t5hWdvqyldvlwOVKQR7ummcth5ySyRroowJAKJJLmkYb)1kAgH5GusFeOEfVCSP3i4S3WBFXZ1hev1Ys6LApVQRt0Qtpq60N4GoxsZbOCoWwxNXVlW3AGTzqITkHh7b6xLvtV5KQ2CZ5E9PPxvKTn6mBg6P12lUkBAR5KQAR5CJ0wNaFeJHzC26x2vNJUZUhTRVk4m7o7UPHEoMvTwu5G9b5XrGKzWEo3A7s)G4ONq0srrVXr)5X6kkhYfsdmABDr7NIJqqlxv04O)akuhfhjNq2toEhQPGd)4NL9O3Fy)wCugfQDektu0B9oBDV1M61Dud2R207AtNPLj5266KRn9nHTP(YrmAKQnfMr0mfGDP2anWRIGyoyhUoepUlpRi)(WRd6xpq1KIaWRmaC)g66guvbEBBQuhm6lSn90P20(jn7oucphxyKEt3Eh3Wg4Zanyn4fUP)1xg1OQa8RDAT7XJzVKDNORSGUZnqImpPsnuZvN3y1eqwF1VdeKVYXzL8sOF9wCf8i0TnthjPxX(Gu0nZcb9HxNGC2nRqM36uMt04AVn1YXkNs1617hgWJQefq4JocC7BWvfuU7TuMQSCik1cSShABemzPLOorhOedFbAa8)LPHFWla(bFFHFGa(l9f4Vh0dnsRQtILTuBzx6S2CzbQltVvBZLAsynk0ZDl3Zfa()3uPfXogisfWnP1unQ)Dg7AyqcB38r2U1kWgbkm(MzzevVnXOd4rSeNzK1HUA5tsKpdbO1YrNh92B1F8ni2uvd3YCIAcDZnr8eq)QmRkusg1rkpyt6xdJQDFRNlpFVcdx6pZ5(lQmfgVwGbvrGVbgH2aaGoZtnmiDrRdQk2C7emC9voo)sf(wO9bjoNPmxNbO2RRYD0sWmvNAPenpZq0(oyM2nf4MLEItY1lIOyyTbgHHEaogVdGenUPCNZeAv5EzuHRTfVQ96lsHodl1eySVlCPyUvn)W0wyKFyMdRNF44bvUI8dh70w(HZLQMFywR01C1J5mYgkKZ4(DwKtpXJ6OE1E3mYoOmPzgGNRx7rXsmdAg9YpssYaFN5)6jdA4uRwSlbn6XeRmPi0JjmFWNRiyWCl2IcgVgf3)Qz4sSrp6MdC1mCb2U4AA6GvBuTRxS4g2vZ0BD7Q5tlDf2vZTyZUoEnQ2v31oyNY3EE1SxzVYDPcUtFhvMRQwUEc3RBUIRvK20H1UZXN41XUq7FzUyH0IU8TkeB5nU630wZVjJUpnekPUBERFEhJ03HVFJbZ6w1p6cjb702m1pBdxsXkSLF9hsVIXb46jDUifJN4zAsR()e)Fp", "Ret default pack must use the supplied converted in-game string.")

expect_contains(ret, 'spec:RegisterSetBonus( "ret_tier15_2pc", 138159 )', "Ret T15 2pc must be tracked via its spec-specific hidden aura.")
expect_contains(ret, 'spec:RegisterSetBonus( "ret_tier15_4pc", 138164 )', "Ret T15 4pc must be tracked via its spec-specific hidden aura.")
expect_contains(ret, 'spec:RegisterSetBonus( "ret_tier16_2pc", 144586 )', "Ret T16 2pc must be tracked via its spec-specific hidden aura.")
expect_contains(ret, 'spec:RegisterSetBonus( "ret_tier16_4pc", 144593 )', "Ret T16 4pc must be tracked via its spec-specific hidden aura.")
expect_contains(ret, "state.set_bonus.ret_tier15_2pc", "Ret T15 2pc logic must use the spec-specific set-bonus key.")
expect_contains(ret, "state.set_bonus.ret_tier15_4pc", "Ret T15 4pc logic must use the spec-specific set-bonus key.")
expect_contains(ret, "state.set_bonus.ret_tier16_2pc", "Ret T16 2pc logic must use the spec-specific set-bonus key.")
expect_contains(ret, "state.set_bonus.ret_tier16_4pc", "Ret T16 4pc logic must use the spec-specific set-bonus key.")
expect_contains(ret, "GetPlayerAuraBySpellID( 138169 )", "Ret T15 4pc proc must read the live Templar's Verdict proc aura.")
expect_contains(ret, "GetPlayerAuraBySpellID( 144587 )", "Ret T16 2pc must read the live Warrior of the Light buff.")
expect_contains(ret, "GetPlayerAuraBySpellID( 144595 )", "Ret T16 4pc must read the live Divine Crusader buff.")
expect_contains(ret, 'alias = { "ret_tier15_4pc" }', "Old templars_verdict saved-priority conditions must alias to the Ret T15 4pc proc.")
expect_contains(ret, 'alias = { "divine_crusader" }', "Ret T16 4pc saved-priority conditions must alias to the Divine Crusader proc.")
expect_contains(ret, "applyRetTier16DivineCrusader()", "Holy Power spenders must emulate the Ret T16 4pc proc.")
expect_contains(ret, 'removeBuff("divine_crusader")', "Divine Storm must consume the Ret T16 4pc proc.")

expect_contains(apl, "set_bonus.ret_tier15_4pc>0", "Ret APL must gate Crusader Strike on the spec-specific 4pc key.")
expect_contains(apl, "buff.ret_tier15_4pc.down", "Ret APL must read the Ret T15 4pc proc buff.")
expect_contains(apl, "debuff.ret_tier15_2pc.down&glyph.mass_exorcism.enabled", "Ret APL must read the T15 2pc target debuff.")
expect_contains(apl, "buff.ret_tier16_4pc.react", "Ret APL must consume the T16 4pc Divine Crusader proc.")
expect_contains(apl, "buff.ret_tier16_4pc.react&(holy_power=5|buff.ret_tier16_4pc.remains<=2)&(buff.divine_purpose.down|buff.ret_tier16_4pc.remains<=2)", "Ret APL must use the wowsims T16 4pc/Divine Purpose priority gate.")
expect_contains(apl, "set_bonus.ret_tier15_2pc>0&debuff.ret_tier15_2pc.down&target.health.pct<20&buff.avenging_wrath.down", "Ret APL must include the wowsims T15 2pc execute Exorcism rule.")
expect_not_contains(apl, "buff.templars_verdict", "Ret APL must not use the unrelated templars_verdict glyph buff for T15.")

print("ret_t15 regression checks passed")
