--! Cell: this is a private, trimmed fork of Tsoukie's ClassicAPI.
--! If the standalone !!!ClassicAPI addon is installed (Gladdy requires it), it
--! loads first and owns these globals. Overwriting them with this older subset
--! mixes two incompatible halves of the same library, so bail out instead.
if IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI") then return end

--! WotLK fix: heal prediction, incoming resurrection, and shield-absorb
--! tracking were removed from this compatibility layer. Cell consumes
--! LibHealComm privately in its unit-button module, LibResComm privately in
--! Indicators/StatusIcon.lua, and its own CLEU/aura absorb tracker privately.
--! It no longer creates UnitGetIncomingHeals, UnitHasIncomingResurrection,
--! UnitGetTotalAbsorbs, UnitGetTotalHealAbsorbs, UNIT_HEAL_PREDICTION, or
--! INCOMING_RESURRECT_CHANGED.
