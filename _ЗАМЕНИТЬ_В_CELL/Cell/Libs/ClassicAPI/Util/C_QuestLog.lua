local GetQuestsCompleted = GetQuestsCompleted
local QueryQuestsCompleted = QueryQuestsCompleted

local C_QuestLog = C_QuestLog or {}

function C_QuestLog.IsQuestFlaggedCompleted(QuestID)
	QueryQuestsCompleted()
	return GetQuestsCompleted()[QuestID] == true
end

-- Global
_G.C_QuestLog = C_QuestLog