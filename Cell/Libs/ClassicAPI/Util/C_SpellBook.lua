--! Cell: this is a private, trimmed fork of Tsoukie's ClassicAPI.
--! If the standalone !!!ClassicAPI addon is installed (Gladdy requires it), it
--! loads first and owns these globals. Overwriting them with this older subset
--! mixes two incompatible halves of the same library, so bail out instead.
if IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI") then return end

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