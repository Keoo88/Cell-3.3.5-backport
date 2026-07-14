local Spell = Spell or {}
local SpellMixin = SpellMixin or {}
local C_Spell = C_Spell

--[[static]] function Spell:CreateFromSpellID(spellID)
	local spell = CreateFromMixins(SpellMixin)
	spell:SetSpellID(spellID)
	return spell
end

function SpellMixin:SetSpellID(spellID)
	self.spellID = spellID
end

function SpellMixin:GetSpellID()
	return self.spellID
end

function SpellMixin:Clear()
	self.spellID = nil
end

function SpellMixin:IsSpellEmpty()
	return not self:GetSpellID()
end

-- Spell API
function SpellMixin:IsSpellDataCached()
	return true
end

function SpellMixin:GetSpellName()
	return (GetSpellInfo(self:GetSpellID()))
end

function SpellMixin:GetSpellTexture() -- Retail
	return C_Spell.GetSpellTexture(self:GetSpellID())
end

function SpellMixin:GetSpellSubtext()
	return C_Spell.GetSpellSubtext(self:GetSpellID())
end

function SpellMixin:GetSpellDescription()
	return C_Spell.GetSpellDescription(self:GetSpellID())
end

-- Add a callback to be executed when spell data is loaded, if the spell data is already loaded then execute it immediately
function SpellMixin:ContinueOnSpellLoad(callbackFunction)
	if type(callbackFunction) ~= "function" or self:IsSpellEmpty() then
		error("Usage: NonEmptySpell:ContinueOnLoad(callbackFunction)", 2)
	end

	SpellEventListener:AddCallback(self:GetSpellID(), callbackFunction)
end

-- Same as ContinueOnSpellLoad, except it returns a function that when called will cancel the continue
function SpellMixin:ContinueWithCancelOnSpellLoad(callbackFunction)
	if type(callbackFunction) ~= "function" or self:IsSpellEmpty() then
		error("Usage: NonEmptySpell:ContinueWithCancelOnSpellLoad(callbackFunction)", 2)
	end

	return SpellEventListener:AddCancelableCallback(self:GetSpellID(), callbackFunction)
end

-- Global
_G.Spell = Spell
_G.SpellMixin = SpellMixin