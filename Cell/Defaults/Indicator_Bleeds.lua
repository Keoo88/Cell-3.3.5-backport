local _, Cell = ...
local I = Cell.iFuncs

local bleedList

function I.CheckDebuffType(debuffType, spellId)
    if (not debuffType or debuffType == "") and bleedList[spellId] then
        return "Bleed"
    end
    return debuffType
end

-- data from https://wago.tools/db2/SpellEffect
-- EffectMechanic == 15
-- Effect == 6
--
-- Some bleeds do not have proper EffectMechanic flag
-- Those can however be found here https://wago.tools/db2/SpellCategories
-- Mechanic == 15
-- Crossreference with SpellEffect.Effect == 6

bleedList = {
    -- ==========================================================================
    -- WotLK 3.3.5a player bleeds (all ranks). The upstream list only carries
    -- modern-retail spell IDs, so max-rank WotLK bleeds were never recognized
    -- and CheckDebuffType never returned "Bleed". Added below (Mechanic=Bleeding).
    -- ==========================================================================
    -- DRUID: Rip
    [9492] = true, [9493] = true, [9752] = true, [9894] = true, [9896] = true, [27008] = true, [49799] = true, [49800] = true,
    -- DRUID: Rake (periodic bleed)
    [1822] = true, [1823] = true, [1824] = true, [9904] = true, [27003] = true, [48573] = true, [48574] = true,
    -- DRUID: Lacerate
    [33745] = true, [48567] = true, [48568] = true,
    -- DRUID: Pounce Bleed
    [9007] = true, [9824] = true, [9826] = true, [27007] = true, [49804] = true,
    -- ROGUE: Rupture
    [8639] = true, [8640] = true, [11273] = true, [11274] = true, [11275] = true, [26867] = true, [48671] = true, [48672] = true,
    -- ROGUE: Garrote
    [8631] = true, [8632] = true, [8633] = true, [11289] = true, [11290] = true, [26839] = true, [26884] = true, [48675] = true, [48676] = true,
    -- WARRIOR: Rend
    [772] = true, [6546] = true, [6547] = true, [6548] = true, [11572] = true, [11573] = true, [11574] = true, [25208] = true, [46845] = true, [47465] = true,
    -- WARRIOR: Deep Wounds (applied debuff)
    [12721] = true,
    [99100] = true, -- 裂伤 - Mangle
    [98282] = true, -- 小型撕裂 - Tiny Rend
    [97357] = true, -- 裂伤 - Gaping Wound
    [96700] = true, -- 毁灭 - Ravage
    [96592] = true, -- 毁灭 - Ravage
    [96570] = true, -- 裂伤 - Gaping Wound
    [95334] = true, -- Elementium Spike Shield - Elementium Spike Shield
    [93675] = true, -- 重伤 - Mortal Wound
    [93587] = true, -- 血祭 - Ritual of Bloodletting
    [91348] = true, -- 嫩化 - Tenderize
    [90098] = true, -- 劈头斧 - Axe to the Head
    [89212] = true, -- 鹰爪 - Eagle Claw
    [87395] = true, -- 锯齿劈斩 - Serrated Slash
    [87337] = true, -- 恶意切割 - Vicious Slice
    [86738] = true, -- 深度瘀伤 - Deep Bruise
    [86604] = true, -- 恶意切割 - Vicious Slice
    [85415] = true, -- 裂伤 - Mangle
    [84642] = true, -- 刺破 - Puncture
    [83783] = true, -- 穿刺 - Impale
    [82766] = true, -- 凿眼 - Eye Gouge
    [82753] = true, -- 血祭 - Ritual of Bloodletting
    [81690] = true, -- 血之气息 - Scent of Blood
    [81569] = true, -- 旋风劈砍 - Spinning Slash
    [81568] = true, -- 旋风劈砍 - Spinning Slash
    [81087] = true, -- 穿刺之伤 - Puncture Wound
    [81043] = true, -- 利刃切割 - Razor Slice
    [80051] = true, -- 重伤 - Grievous Wound
    [80028] = true, -- 岩石钻孔 - Rock Bore
    [79829] = true, -- 割裂 - Rip
    [79828] = true, -- 裂伤 - Mangle
    [79444] = true, -- 穿刺 - Impale
    [78859] = true, -- 源质刺盾 - Elementium Spike Shield
    [78842] = true, -- 血肉撕咬 - Carnivorous Bite
    [76594] = true, -- 撕裂 - Rend
    [76524] = true, -- 痛苦旋风 - Grievous Whirl
    [76507] = true, -- 穿刺爪击 - Claw Puncture
    [75930] = true, -- 裂伤 - Mangle
    [75388] = true, -- 钝击 - Rusty Cut
    [75161] = true, -- 旋转掠杀 - Spinning Rake
    [75160] = true, -- 血腥撕裂 - Bloody Rip
    [74846] = true, -- 溢血之伤 - Bleeding Wound
    [71926] = true, -- 割裂 - Rip
    [70278] = true, -- 穿刺之伤 - Puncture Wound
    [69203] = true, -- 恶毒之咬 - Vicious Bite
    [69065] = true, -- 穿刺 - Impaled
    [67280] = true, -- 匕首投掷 - Dagger Throw
    [66620] = true, -- 旧患 - Old Wounds
    [65406] = true, -- 斜掠 - Rake
    [65033] = true, -- 收缩撕裂 - Constricting Rend
    [64666] = true, -- 野蛮突袭 - Savage Pounce
    [64374] = true, -- 野蛮突袭 - Savage Pounce
    [63468] = true, -- 精确瞄准 - Careful Aim
    [62418] = true, -- 穿刺 - Impale
    [62331] = true, -- 穿刺 - Impale
    [62318] = true, -- 倒刺射击 - Barbed Shot
    [61896] = true, -- 割伤 - Lacerate
    [61164] = true, -- 穿刺 - Impale
    [59989] = true, -- 割裂 - Rip
    [59881] = true, -- 斜掠 - Rake
    [59826] = true, -- 刺破 - Puncture
    [59825] = true, -- 旋风劈砍 - Whirling Slash
    [59824] = true, -- 旋风劈砍 - Whirling Slash
    [59691] = true, -- 撕裂 - Rend
    [59682] = true, -- 重伤 - Grievous Wound
    [59444] = true, -- 决断突刺 - Determined Gore
    [59349] = true, -- 投掷 - Dart
    [59343] = true, -- 撕裂 - Rend
    [59269] = true, -- 血肉撕咬 - Carnivorous Bite
    [59268] = true, -- 穿刺 - Impale
    [59264] = true, -- 刺伤 - Gore
    [59262] = true, -- 重伤 - Grievous Wound
    [59256] = true, -- 穿刺 - Impale
    [59239] = true, -- 撕裂 - Rend
    [59023] = true, -- 穿透打击 - Puncturing Strike
    [59007] = true, -- 血肉腐烂 - Flesh Rot
    [58978] = true, -- 穿刺 - Impale
    [58830] = true, -- 致伤打击 - Wounding Strike
    [58517] = true, -- 重伤 - Grievous Wound
    [58459] = true, -- 穿刺 - Impale
    [57661] = true, -- 割裂 - Rip
    [55645] = true, -- 死亡疫病 - Death Plague
    [55622] = true, -- 穿刺 - Impale
    [55604] = true, -- 死亡疫病 - Death Plague
    [55550] = true, -- 裂纹小刀 - Jagged Knife
    [55276] = true, -- 刺破 - Puncture
    [55250] = true, -- 旋风劈砍 - Whirling Slash
    [55249] = true, -- 旋风劈砍 - Whirling Slash
    [55102] = true, -- 决断突刺 - Determined Gore
    [54708] = true, -- 撕裂 - Rend
    [54703] = true, -- 撕裂 - Rend
    [54668] = true, -- 斜掠 - Rake
    [53602] = true, -- 投掷 - Dart
    [53499] = true, -- 斜掠 - Rake
    [53317] = true, -- 撕裂 - Rend
    [52873] = true, -- 迸裂创伤 - Open Wound
    [52771] = true, -- 致伤打击 - Wounding Strike
    [52504] = true, -- 割伤 - Lacerate
    [52401] = true, -- 重击 - Gut Rip
    [51275] = true, -- 重击 - Gut Rip
    [50871] = true, -- 野蛮撕扯 - Savage Rend
    [50729] = true, -- 血肉撕咬 - Carnivorous Bite
    [49678] = true, -- 血肉腐烂 - Flesh Rot
    [48920] = true, -- 凶残撕咬 - Grievous Bite
    [48880] = true, -- 撕裂 - Rend
    [48374] = true, -- 穿刺之伤 - Puncture Wound
    [48286] = true, -- 凶残挥砍 - Grievous Slash
    [48261] = true, -- 穿刺 - Impale
    [48245] = true, -- 头部挥砍 - Head Slash
    [48130] = true, -- 刺伤 - Gore
    [43937] = true, -- 重伤 - Grievous Wound
    [43931] = true, -- 撕裂 - Rend
    [43246] = true, -- 撕裂 - Rend
    [43153] = true, -- 山猫冲锋 - Lynx Rush
    [43104] = true, -- 重伤 - Deep Wound
    [43093] = true, -- 重伤投掷 - Grievous Throw
    [42658] = true, -- 猛烈攻击！ - Sic'em!
    [42397] = true, -- 撕裂肉体 - Rend Flesh
    [42395] = true, -- 刺裂 - Lacerating Slash
    [41932] = true, -- 血肉撕咬 - Carnivorous Bite
    [41092] = true, -- 血肉撕咬 - Carnivorous Bite
    [40199] = true, -- 撕裂血肉 - Flesh Rip
    [39382] = true, -- 血肉撕咬 - Carnivorous Bite
    [39215] = true, -- 龟裂创伤 - Gushing Wound
    [39198] = true, -- 血肉撕咬 - Carnivorous Bite
    [38848] = true, -- 削弱灵魂 - Diminish Soul
    [38810] = true, -- 血盆大口 - Gaping Maw
    [38801] = true, -- 重伤 - Grievous Wound
    [38772] = true, -- 重伤 - Grievous Wound
    [38363] = true, -- 龟裂创伤 - Gushing Wound
    [38056] = true, -- 撕裂血肉 - Flesh Rip
    [37973] = true, -- 珊瑚切割 - Coral Cut
    [37937] = true, -- 抓伤 - Flayed Flesh
    [37662] = true, -- 撕裂 - Rend
    [37641] = true, -- 旋风斩 - Whirlwind
    [37487] = true, -- 鲜血治疗 - Blood Heal
    [37123] = true, -- 锯齿利刃 - Saw Blade
    [37066] = true, -- 锁喉 - Garrote
    [36991] = true, -- 撕裂 - Rend
    [36965] = true, -- 撕裂 - Rend
    [36789] = true, -- 削弱灵魂 - Diminish Soul
    [36617] = true, -- 血盆大口 - Gaping Maw
    [36590] = true, -- 割裂 - Rip
    [36383] = true, -- 血肉撕咬 - Carnivorous Bite
    [36332] = true, -- 斜掠 - Rake
    [36023] = true, -- 灵界打击 - Deathblow
    [35321] = true, -- 龟裂创伤 - Gushing Wound
    [35318] = true, -- 锯齿利刃 - Saw Blade
    [35144] = true, -- 恶毒撕裂 - Vicious Rend
    [33912] = true, -- 割裂 - Rip
    [33865] = true, -- 残害 - Singe
    [32901] = true, -- 血肉撕咬 - Carnivorous Bite
    [32019] = true, -- 角刺 - Gore
    [31956] = true, -- 重伤 - Grievous Wound
    [31410] = true, -- 珊瑚切割 - Coral Cut
    [31041] = true, -- 裂伤 - Mangle
    [30639] = true, -- 血肉撕咬 - Carnivorous Bite
    [30285] = true, -- 鹰爪 - Eagle Claw
    [29935] = true, -- 血盆大口 - Gaping Maw
    [29906] = true, -- 毁灭 - Ravage
    [29583] = true, -- 穿刺 - Impale
    [29578] = true, -- 撕裂 - Rend
    [29574] = true, -- 撕裂 - Rend
    [28913] = true, -- 血肉腐烂 - Flesh Rot
    [27638] = true, -- 斜掠 - Rake
    [27556] = true, -- 斜掠 - Rake
    [27555] = true, -- 撕碎 - Shred
    [24332] = true, -- 斜掠 - Rake
    [24331] = true, -- 斜掠 - Rake
    [24192] = true, -- 高速切砍 - Speed Slash
    [21949] = true, -- 撕裂 - Rend
    [19771] = true, -- 尖牙撕咬 - Serrated Bite
    [18202] = true, -- 撕裂 - Rend
    [18200] = true, -- 撕裂 - Rend
    [18106] = true, -- 撕裂 - Rend
    [18078] = true, -- 撕裂 - Rend
    [18075] = true, -- 撕裂 - Rend
    [17504] = true, -- 撕裂 - Rend
    [17153] = true, -- 撕裂 - Rend
    [16509] = true, -- 撕裂 - Rend
    [16406] = true, -- 撕裂 - Rend
    [16403] = true, -- 撕裂 - Rend
    [16393] = true, -- 撕裂 - Rend
    [16095] = true, -- 恶毒撕裂 - Vicious Rend
    [15976] = true, -- 刺破 - Puncture
    [15583] = true, -- 割裂 - Rupture
    [14903] = true, -- 割裂 - Rupture
    [14874] = true, -- 割裂 - Rupture
    [14331] = true, -- 恶毒撕裂 - Vicious Rend
    [14118] = true, -- 撕裂 - Rend
    [14087] = true, -- 撕裂 - Rend
    [13738] = true, -- 撕裂 - Rend
    [13445] = true, -- 撕裂 - Rend
    [13443] = true, -- 撕裂 - Rend
    [13318] = true, -- 撕裂 - Rend
    [12054] = true, -- 撕裂 - Rend
    [11977] = true, -- 撕裂 - Rend
    [10266] = true, -- 刺穿肺部 - Lung Puncture
    [8818] = true, -- 锁喉 - Garrote
    [5598] = true, -- 严重致伤 - Serious Wound
    [5597] = true, -- 严重致伤 - Serious Wound
    [3147] = true, -- 撕裂肉体 - Rend Flesh
    [1943] = true, -- 割裂 - Rupture
    [1079] = true, -- 割裂 - Rip
    [703] = true, -- 锁喉 - Garrote
}

Cell.vars.bleedList = bleedList