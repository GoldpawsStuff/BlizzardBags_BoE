--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
-- Retrive addon folder name, and our local, private namespace.
local Addon, Private = ...

-- Lua API
local _G = _G
local ipairs = ipairs
local string_find = string.find
local tonumber = tonumber

-- WoW API
local CreateFrame = CreateFrame
local GetContainerItemInfo = GetContainerItemInfo
local GetItemInfo = GetItemInfo

-- WoW Strings
local S_ITEM_BOUND1 = ITEM_SOULBOUND
local S_ITEM_BOUND2 = ITEM_ACCOUNTBOUND
local S_ITEM_BOUND3 = ITEM_BNETACCOUNTBOUND

-- WoW10 API
local C_Container_GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo

-- Tooltip used for scanning.
-- Let's keep this name for all scanner addons.
local _SCANNER = "GP_ScannerTooltip"
local Scanner = _G[_SCANNER] or CreateFrame("GameTooltip", _SCANNER, WorldFrame, "GameTooltipTemplate")

-- Cache of information objects,
-- globally available so addons can share it.
local Cache = GP_ItemButtonInfoFrameCache or {}
GP_ItemButtonInfoFrameCache = Cache

-- Localization.
-- *Just enUS so far.
local L = {
	["BoE"] = "BoE", -- Bind on Equip
	["BoU"] = "BoU"  -- Bind on Use
}

-- Quality/Rarity colors for faster lookups
local colors = {
	[0] = { 157/255, 157/255, 157/255 }, -- Poor
	[1] = { 240/255, 240/255, 240/255 }, -- Common
	[2] = { 30/255, 178/255, 0/255 }, -- Uncommon
	[3] = { 0/255, 112/255, 221/255 }, -- Rare
	[4] = { 163/255, 53/255, 238/255 }, -- Epic
	[5] = { 225/255, 96/255, 0/255 }, -- Legendary
	[6] = { 229/255, 204/255, 127/255 }, -- Artifact
	[7] = { 79/255, 196/255, 225/255 }, -- Heirloom
	[8] = { 79/255, 196/255, 225/255 } -- Blizzard
}

-- Callbacks
-----------------------------------------------------------
-- Update an itembutton's bind status
local Update = function(self, bag, slot)
	local message, rarity, mult, itemLink, isBound, _
	local r, g, b = 240/255, 240/255, 240/255
	if (C_Container_GetContainerItemInfo) then
		local containerInfo = C_Container_GetContainerItemInfo(bag,slot)
		if (containerInfo) then
			isBound = containerInfo.isBound
			itemLink = containerInfo.hyperlink
		end
	else
		_, _, _, _, _, _, itemLink, _, _, _, isBound = GetContainerItemInfo(bag, slot)
	end
	if (itemLink) then
		local _, _, itemQuality, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(itemLink)

		-- *in retail, all items can bind now thanks to transmogs
		if (itemQuality and ((Private.IsRetail and itemQuality >= 0) or itemQuality > 1)) and (bindType == 2 or bindType == 3) then

			-- If the item is bound,
			-- the bind type is irrelevant.
			local showStatus = true
			if (isBound) then
				showStatus = nil
			end

			-- GetContainerItemInfo isn't returning 'isBound' in the classics,
			-- so we need to scan the tooltip the old way here.
			if (showStatus and not Private.IsRetail) then
				Scanner.owner = self
				Scanner.bag = bag
				Scanner.slot = slot
				Scanner:SetOwner(self, "ANCHOR_NONE")
				Scanner:SetBagItem(bag,slot)
				for i = 2,6 do
					local line = _G[_SCANNER.."TextLeft"..i]
					if (not line) then
						break
					end
					local msg = line:GetText()
					if (msg) then
						if (string_find(msg, S_ITEM_BOUND1) or string_find(msg, S_ITEM_BOUND2) or string_find(msg, S_ITEM_BOUND3)) then
							showStatus = nil -- item is bound, don't show the bind type.
							break
						end
					end
				end
			end

			if (showStatus) then
				message = (bindType == 3) and L["BoU"] or L["BoE"]
				rarity = itemQuality
				mult = (itemRarity ~= 3 and itemRarity ~= 4) and 4/5
			end
		end
	end

	if (message) then

		-- Retrieve or create the button's info container.
		local container = Cache[self]
		if (not container) then
			container = CreateFrame("Frame", nil, self)
			container:SetFrameLevel(self:GetFrameLevel() + 5)
			container:SetAllPoints()
			Cache[self] = container
		end

		-- Retrieve of create the bind status fontstring
		if (not container.bind) then
			container.bind = container:CreateFontString()
			container.bind:SetDrawLayer("ARTWORK", 1)
			container.bind:SetPoint("BOTTOMLEFT", 2, 2)
			container.bind:SetFontObject(NumberFont_Outline_Med or NumberFontNormal)
			container.bind:SetShadowOffset(1, -1)
			container.bind:SetShadowColor(0, 0, 0, .5)
		end

		-- Move conflicting upgrade icons
		local upgrade = self.UpgradeIcon
		if (upgrade) then
			upgrade:ClearAllPoints()
			upgrade:SetPoint("BOTTOMRIGHT", 2, 0)
		end

		-- Colorize.
		if (rarity and colors[rarity]) then
			local col = colors[rarity]
			r, g, b = col[1], col[2], col[3]
		end

		-- Tadaa!
		if (mult) then
			container.bind:SetTextColor(r * mult, g * mult, b * mult)
		else
			container.bind:SetTextColor(r, g, b)
		end
		container.bind:SetText(message)

	else
		local cache = Cache[self]
		if (cache and cache.bind) then
			cache.bind:SetText("")
		end
	end

end

-- Parse a container
local UpdateContainer = function(self)
	local bag = self:GetID()
	local name = self:GetName()
	local id = 1
	local button = _G[name.."Item"..id]
	while (button) do
		if (button.hasItem) then
			Update(button, bag, button:GetID())
		else
			local cache = Cache[button]
			if (cache and cache.bind) then
				cache.bind:SetText("")
			end
		end
		id = id + 1
		button = _G[name.."Item"..id]
	end
end

-- Parse combined container
local UpdateCombinedContainer = function(self)
	if (self.EnumerateValidItems) then
		for id,button in self:EnumerateValidItems() do
			if (button.hasItem) then
				-- The buttons retain their original bagID
				Update(button, button:GetBagID(), button:GetID())
			else
				local cache = Cache[button]
				if (cache and cache.bind) then
					cache.bind:SetText("")
				end
			end
		end
	elseif (self.Items) then
		for id,button in ipairs(self.Items) do
			if (button.hasItem) then
				-- The buttons retain their original bagID
				Update(button, button:GetBagID(), button:GetID())
			else
				local cache = Cache[button]
				if (cache and cache.bind) then
					cache.bind:SetText("")
				end
			end
		end
	end
end

-- Parse the main bankframe
local UpdateBank = function()
	local BankSlotsFrame = BankSlotsFrame
	local bag = BankSlotsFrame:GetID()
	for id = 1, NUM_BANKGENERIC_SLOTS do
		local button = BankSlotsFrame["Item"..id]
		if (button and not button.isBag) then
			if (button.hasItem) then
				Update(button, bag, button:GetID())
			else
				local cache = Cache[button]
				if (cache and cache.bind) then
					cache.bind:SetText("")
				end
			end
		end
	end
end

-- Update a single bank button, needed for classics
local UpdateBankButton = function(self)
	if (self and not self.isBag) then
		-- Always run a full update here,
		-- as the .hasItem flag might not have been set yet.
		Update(self, BankSlotsFrame:GetID(), self:GetID())
	else
		local cache = Cache[button]
		if (cache and cache.bind) then
			cache.bind:SetText("")
		end
	end
end

-- Addon Core
-----------------------------------------------------------
-- Your event handler.
-- Any events you add should be handled here.
-- @input event <string> The name of the event that fired.
-- @input ... <misc> Any payloads passed by the event handlers.
Private.OnEvent = function(self, event, ...)
	if (event == "PLAYERBANKSLOTS_CHANGED") then
		local slot = ...
		if (slot <= NUM_BANKGENERIC_SLOTS) then
			local button = BankSlotsFrame["Item"..slot]
			if (button and not button.isBag) then
				-- Always run a full update here,
				-- as the .hasItem flag might not have been set yet.
				Update(button, BankSlotsFrame:GetID(), button:GetID())
			end
		end
	end
end

-- Enabling.
-- This fires when most of the user interface has been loaded
-- and most data is available to the user.
Private.OnEnable = function(self)

	-- All the Classics
	if (ContainerFrame_Update) then
		hooksecurefunc("ContainerFrame_Update", UpdateContainer)
	else
		-- Dragonflight and up
		local id = 1
		local frame = _G["ContainerFrame"..id]
		while (frame and frame.Update) do
			hooksecurefunc(frame, "Update", UpdateContainer)
			id = id + 1
			frame = _G["ContainerFrame"..id]
		end
	end

	-- Dragonflight and up
	if (ContainerFrameCombinedBags) then
		hooksecurefunc(ContainerFrameCombinedBags, "Update", UpdateCombinedContainer)
	end

	-- Shadowlands and up
	if (BankFrame_UpdateItems) then
		hooksecurefunc("BankFrame_UpdateItems", UpdateBank)

	-- Classics
	elseif (BankFrameItemButton_UpdateLocked) then
		-- This is called from within BankFrameItemButton_Update,
		-- and thus works as an update for both.
		hooksecurefunc("BankFrameItemButton_UpdateLocked", UpdateBankButton)
	end

	-- For single item changes
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

end

-- Setup the environment
-----------------------------------------------------------
(function(self)
	-- Private Default API
	-- This mostly contains methods we always want available
	-----------------------------------------------------------

	-- Addon version
	-- *Keyword substitution requires the packager,
	-- and does not affect direct GitHub repo pulls.
	local version = "@project-version@"
	if (version:find("project%-version")) then
		version = "Development"
	end

	-- WoW Client versions
	local patch, build, date, tocversion = GetBuildInfo()
	local major, minor, micro = string.split(".", patch)

	-- WoW 11.0.x
	local GetAddOnEnableState = GetAddOnEnableState or function(character, name) return C_AddOns.GetAddOnEnableState(name, character) end
	local GetAddOnInfo = GetAddOnInfo or C_AddOns.GetAddOnInfo
	local GetNumAddOns = GetNumAddOns or C_AddOns.GetNumAddOns

	-- Simple flags for client version checks
	Private.IsRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
	Private.IsClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
	Private.IsTBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
	Private.IsWrath = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)
	--Private.IsCata = WOW_PROJECT_ID == (WOW_PROJECT_CATA_CLASSIC or 99) -- NYI in first build
	Private.IsCata = (tocversion >= 40400) and (tocversion < 50000)
	Private.WoW10 = tocversion >= 100000

	Private.ClientVersion = tocversion
	Private.ClientDate = date
	Private.ClientPatch = patch
	Private.ClientMajor = tonumber(major)
	Private.ClientMinor = tonumber(minor)
	Private.ClientMicro = tonumber(micro)
	Private.ClientBuild = tonumber(build)

	-- Should mostly be used for debugging
	Private.Print = function(self, ...)
		print("|cff33ff99:|r", ...)
	end

	Private.GetAddOnInfo = function(self, index)
		local name, title, notes, loadable, reason, security, newVersion = GetAddOnInfo(index)
		local enabled = not(GetAddOnEnableState(UnitName("player"), index) == 0)
		return name, title, notes, enabled, loadable, reason, security
	end

	-- Check if an addon exists in the addon listing and loadable on demand
	Private.IsAddOnLoadable = function(self, target, ignoreLoD)
		local target = string.lower(target)
		for i = 1,GetNumAddOns() do
			local name, title, notes, enabled, loadable, reason, security = self:GetAddOnInfo(i)
			if string.lower(name) == target then
				if loadable or ignoreLoD then
					return true
				end
			end
		end
	end

	-- This method lets you check if an addon WILL be loaded regardless of whether or not it currently is.
	-- This is useful if you want to check if an addon interacting with yours is enabled.
	-- My philosophy is that it's best to avoid addon dependencies in the toc file,
	-- unless your addon is a plugin to another addon, that is.
	Private.IsAddOnEnabled = function(self, target)
		local target = string.lower(target)
		for i = 1,GetNumAddOns() do
			local name, title, notes, enabled, loadable, reason, security = self:GetAddOnInfo(i)
			if string.lower(name) == target then
				if enabled and loadable then
					return true
				end
			end
		end
	end

	-- Event API
	-----------------------------------------------------------
	-- Proxy event registering to the addon namespace.
	-- The 'self' within these should refer to our proxy frame,
	-- which has been passed to this environment method as the 'self'.
	Private.RegisterEvent = function(_, ...) self:RegisterEvent(...) end
	Private.RegisterUnitEvent = function(_, ...) self:RegisterUnitEvent(...) end
	Private.UnregisterEvent = function(_, ...) self:UnregisterEvent(...) end
	Private.UnregisterAllEvents = function(_, ...) self:UnregisterAllEvents(...) end
	Private.IsEventRegistered = function(_, ...) self:IsEventRegistered(...) end

	-- Event Dispatcher and Initialization Handler
	-----------------------------------------------------------
	-- Assign our event script handler,
	-- which runs our initialization methods,
	-- and dispatches event to the addon namespace.
	self:RegisterEvent("ADDON_LOADED")
	self:SetScript("OnEvent", function(self, event, ...)
		if (event == "ADDON_LOADED") then
			-- Nothing happens before this has fired for your addon.
			-- When it fires, we remove the event listener
			-- and call our initialization method.
			if ((...) == Addon) then
				-- Delete our initial registration of this event.
				-- Note that you are free to re-register it in any of the
				-- addon namespace methods.
				self:UnregisterEvent("ADDON_LOADED")
				-- Call the initialization method.
				if (Private.OnInit) then
					Private:OnInit()
				end
				-- If this was a load-on-demand addon,
				-- then we might be logged in already.
				-- If that is the case, directly run
				-- the enabling method.
				if (IsLoggedIn()) then
					if (Private.OnEnable) then
						Private:OnEnable()
					end
				else
					-- If this is a regular always-load addon,
					-- we're not yet logged in, and must listen for this.
					self:RegisterEvent("PLAYER_LOGIN")
				end
				-- Return. We do not wish to forward the loading event
				-- for our own addon to the namespace event handler.
				-- That is what the initialization method exists for.
				return
			end
		elseif (event == "PLAYER_LOGIN") then
			-- This event only ever fires once on a reload,
			-- and anything you wish done at this event,
			-- should be put in the namespace enable method.
			self:UnregisterEvent("PLAYER_LOGIN")
			-- Call the enabling method.
			if (Private.OnEnable) then
				Private:OnEnable()
			end
			-- Return. We do not wish to forward this
			-- to the namespace event handler.
			return
		end
		-- Forward other events than our two initialization events
		-- to the addon namespace's event handler.
		-- Note that you can always register more ADDON_LOADED
		-- if you wish to listen for other addons loading.
		if (Private.OnEvent) then
			Private:OnEvent(event, ...)
		end
	end)
end)((function() return CreateFrame("Frame", nil, WorldFrame) end)())
