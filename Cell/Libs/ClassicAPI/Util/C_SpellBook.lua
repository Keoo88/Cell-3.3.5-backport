local _, Private = ...

local _G = _G

local C_SpellBook = C_SpellBook or {}

C_SpellBook.HasPetSpells = HasPetSpells
C_SpellBook.GetSpellLinkFromSpellID = GetSpellLink
C_SpellBook.PickupSpellBookItem = PickupSpell
C_SpellBook.GetSpellBookItemName = GetSpellName

-- Global
_G.C_SpellBook = C_SpellBook
_G.PickupSpellBookItem = C_SpellBook.PickupSpellBookItem
_G.GetSpellBookItemName = C_SpellBook.GetSpellBookItemName