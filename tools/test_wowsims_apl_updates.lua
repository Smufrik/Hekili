local function read_file( path )
    local file = assert( io.open( path, "rb" ) )
    local contents = file:read( "*a" )
    file:close()
    return contents
end

local function expect_contains( text, needle, message )
    if not text:find( needle, 1, true ) then
        error( message .. "\nmissing: " .. needle, 2 )
    end
end

local function expect_not_contains( text, needle, message )
    if text:find( needle, 1, true ) then
        error( message .. "\nfound: " .. needle, 2 )
    end
end

local elemental = read_file( "MistsOfPandaria/Priorities/ShamanElemental.simc" )
local rogue_combat = read_file( "MistsOfPandaria/Priorities/RogueCombat.simc" )
local frost_dk = read_file( "MistsOfPandaria/Priorities/DeathKnightFrost.simc" )
local unholy_dk = read_file( "MistsOfPandaria/Priorities/DeathKnightUnholy.simc" )
local bm = read_file( "MistsOfPandaria/Priorities/HunterBeastMastery.simc" )
local mm = read_file( "MistsOfPandaria/Priorities/HunterMarksmanship.simc" )
local sv = read_file( "MistsOfPandaria/Priorities/HunterSurvival.simc" )
local affliction = read_file( "MistsOfPandaria/Priorities/WarlockAffliction.simc" )
local balance = read_file( "MistsOfPandaria/Priorities/DruidBalance.simc" )
local windwalker = read_file( "MistsOfPandaria/Priorities/MonkWindwalker.simc" )

expect_contains( elemental, "actions.single_target+=/unleash_elements,if=talent.unleashed_fury.enabled&!buff.ascendance.up", "Elemental P5 should not use Unleash Elements during Ascendance." )
expect_contains( elemental, "cooldown.ascendance.remains<2&debuff.flame_shock.remains<16", "Elemental P5 should refresh Flame Shock before Ascendance." )
expect_contains( elemental, "actions.single_target+=/ascendance,if=debuff.flame_shock.remains>15", "Elemental P5 should enter Ascendance with a long Flame Shock." )

expect_contains( rogue_combat, "actions.generator+=/revealing_strike,if=energy>=40", "Combat Rogue P5 should use the 50e Sinister Strike live generator fallback from wowsims." )
expect_not_contains( rogue_combat, "actions.generator+=/sinister_strike\n", "Combat Rogue generator fallback should not still be unconditional Sinister Strike." )

expect_contains( frost_dk, "actions.masterfrost+=/horn_of_winter,if=buff.horn_of_winter.down&runic_power<20", "Frost DK Masterfrost should delay Horn of Winter unless RP is low." )
expect_contains( frost_dk, "actions.masterfrost+=/empower_rune_weapon,if=runic_power.deficit>=40&(runes.frost.count=0|runes.death.count=0)", "Frost DK Masterfrost should keep ERW ahead of low-value Horn of Winter." )

expect_contains( unholy_dk, "trinket.proc.strength.up|trinket.proc.haste.up", "Unholy DK should include SoO trinket proc windows in cooldown alignment." )

expect_contains( bm, "actions.core_rotation+=/dire_beast,if=talent.dire_beast.enabled", "BM Hunter should include Dire Beast in core P5 priority." )
expect_contains( bm, "actions.core_rotation+=/fervor,if=talent.fervor.enabled&focus<=50", "BM Hunter should include Fervor focus recovery in core P5 priority." )
expect_contains( mm, "actions.sustain_phase+=/dire_beast,if=talent.dire_beast.enabled", "MM Hunter should include Dire Beast in the sustain P5 priority." )
expect_contains( sv, "actions.cooldowns+=/dire_beast,if=talent.dire_beast.enabled", "SV Hunter should include Dire Beast in P5 cooldown priority." )

expect_contains( affliction, "actions+=/malefic_grasp,interrupt=1,chain=1,if=dot.agony.ticking&dot.corruption.ticking&dot.unstable_affliction.ticking&mana.pct>20&dot.agony.remains>gcd", "Affliction should keep Malefic Grasp filler gated on an active Agony window." )

expect_contains( balance, "actions+=/celestial_alignment,if=trinket.proc.intellect.up&(buff.lunar_eclipse.up|buff.solar_eclipse.up)", "Balance should account for portable P5 intellect proc windows." )
expect_contains( balance, "actions+=/moonfire,if=trinket.proc.intellect.up&debuff.moonfire.remains<=6", "Balance should allow P5 trinket Moonfire refreshes." )
expect_contains( balance, "actions+=/sunfire,if=trinket.proc.intellect.up&debuff.sunfire.remains<=6", "Balance should allow P5 trinket Sunfire refreshes." )

expect_contains( windwalker, "actions+=/use_items,if=buff.tigereye_brew_use.up|buff.bloodlust.up|target.time_to_die<=30", "Windwalker should align on-use effects with TEB/bloodlust P5 windows." )
expect_contains( windwalker, "actions+=/invoke_xuen,if=talent.invoke_xuen.enabled&toggle.cooldowns&(buff.tigereye_brew_use.up|buff.bloodlust.up|target.time_to_die<45)", "Windwalker should align Xuen with TEB/bloodlust P5 windows." )

print( "wowsims APL update regression checks passed" )
