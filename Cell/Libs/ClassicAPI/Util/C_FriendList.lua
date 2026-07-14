local _, Private = ...

local UnitName = UnitName
local AddFriend = AddFriend
local GetNumFriends = GetNumFriends

local C_FriendList = C_FriendList or {}

function C_FriendList.GetNumOnlineFriends()
	local _, Online = GetNumFriends()
	return Online
end

function C_FriendList.GetNumFriends()
	local Total = GetNumFriends()
	return Total
end

function C_FriendList.GetFriendInfo(Name)
	for i=1,C_FriendList.GetNumFriends() do
		local Friend, Level, Class, Area, Connected, Status, Note = C_FriendList.GetFriendInfoByIndex(i)
		if ( Name == Friend ) then
			return Friend, Level, Class, Area, Connected, Status, Note, false
		end
	end
end

function C_FriendList.AddFriend(Name, Notes)
	AddFriend(Name)
	if ( Notes ) then
		C_FriendList.SetFriendNotes(Name, Notes)
	end
end

function C_FriendList.DelIgnoreByIndex(Index)
	local Name = C_FriendList.GetIgnoreName(Index)
	if ( Name ) then
		C_FriendList.DelIgnore(Name)
	end
end

function C_FriendList.IsIgnored(Token)
	for i=1,C_FriendList.GetNumIgnores() do
		local Name = C_FriendList.GetIgnoreName(i)
		if ( Name == Token or Name == UnitName(Token) ) then
			return true
		end
	end
end

C_FriendList.SendWho = SendWho
C_FriendList.AddIgnore = AddIgnore
C_FriendList.DelIgnore = DelIgnore
C_FriendList.GetWhoInfo = GetWhoInfo
C_FriendList.ShowFriends = ShowFriends
C_FriendList.RemoveFriend = RemoveFriend
C_FriendList.GetNumIgnores = GetNumIgnores
C_FriendList.GetIgnoreName = GetIgnoreName
C_FriendList.AddOrDelIgnore = AddOrDelIgnore
C_FriendList.SetFriendNotes = SetFriendNotes
C_FriendList.RemoveFriendByIndex = RemoveFriend
C_FriendList.GetNumWhoResults = GetNumWhoResults
C_FriendList.GetFriendInfoByIndex = GetFriendInfo
C_FriendList.AddOrRemoveFriend = AddOrRemoveFriend
C_FriendList.GetSelectedIgnore = GetSelectedIgnore
C_FriendList.GetSelectedFriend = GetSelectedFriend
C_FriendList.SetFriendNotesByIndex = SetFriendNotes
C_FriendList.SetSelectedFriend = SetSelectedFriend
C_FriendList.SetSelectedIgnore = SetSelectedIgnore
C_FriendList.IsOnIgnoredList = C_FriendList.IsIgnored

C_FriendList.SortWho = Private.Void
C_FriendList.SetWhoToUi = Private.Void

-- Global
_G.C_FriendList = C_FriendList