local _, Private = ...

local C_CVar = C_CVar or {}

C_CVar.GetCVar = GetCVar
C_CVar.SetCVar = SetCVar
C_CVar.GetCVarBool = GetCVarBool
C_CVar.GetCVarInfo = GetCVarInfo
C_CVar.GetCVarDefault = GetCVarDefault

C_CVar.RegisterCVar = Private.Void
C_CVar.SetCVarBitfield = Private.Void
C_CVar.GetCVarBitfield = Private.Void
C_CVar.ResetTestCVars = Private.Void
C_CVar.AreCVarsLoaded = Private.Void

-- Global
_G.C_CVar = C_CVar