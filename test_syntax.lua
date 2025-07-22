-- Simplified test file to check syntax around line 480
local spec = {}
function spec:RegisterAbilities() end

spec:RegisterAbilities( {
    aspect_of_the_cheetah = {
        id = 5118,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        handler = function ()
            spec:apply_aspect( "aspect_of_the_cheetah" )
        end,
    },

    aspect_of_the_hawk = {
        id = 13165,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        handler = function ()
            applyBuff( "aspect_of_the_hawk" )
        end,
    },
} )
