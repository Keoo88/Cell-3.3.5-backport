--! Cell: private, trimmed fork of Tsoukie's ClassicAPI.
--! Coexistence rules live in Util/Coexist.lua: never bail out of a file, never
--! overwrite a global somebody else owns (gap-fill only), keep our own copy in the
--! private CellClassicAPI namespace. Names published here are not native to 3.3.5a
--! (verified against milkyway-codex).

local _, Private = ...

local _G = _G

-- Own table: filling a foreign C_SpellBook in place would overwrite its methods.
local C_SpellBook = {}

C_SpellBook.HasPetSpells = HasPetSpells
C_SpellBook.GetSpellLinkFromSpellID = GetSpellLink
C_SpellBook.PickupSpellBookItem = PickupSpell
C_SpellBook.GetSpellBookItemName = GetSpellName

-- Global
Private.Merge("C_SpellBook", C_SpellBook)
Private.Provide("PickupSpellBookItem", C_SpellBook.PickupSpellBookItem)
Private.Provide("GetSpellBookItemName", C_SpellBook.GetSpellBookItemName)
