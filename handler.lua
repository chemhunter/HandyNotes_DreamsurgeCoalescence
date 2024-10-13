local addonname, ns = ...

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")
local HL = LibStub("AceAddon-3.0"):NewAddon(addonname, "AceEvent-3.0")
ns.HL = HL
L = ns.L 
local label = L['DreamsurgeCoalescence']
local model = {	label = label, item = 207026, note = label,	}
local recordPoint = CreateFrame("Frame")
local function OnEvent(self, event, ...)
    if event == "CHAT_MSG_LOOT" then
        local message = ...
        if (message:find("207026")) then -- item
			local mapID = C_Map.GetBestMapForUnit("player")
			if mapID then
				local position = C_Map.GetPlayerMapPosition(mapID, "player")
				if position then
					local x, y = position:GetXY()
					local coord = math.floor(x * 10000 + 0.5) * 10000 + math.floor(y * 10000 + 0.5)
					ns.points = ns.points or {}
					ns.points[mapID] = ns.points[mapID] or {}
					local is_duplicate = false
					for existing_coord, point in pairs(ns.points[mapID]) do
						local existing_x = math.floor(existing_coord / 10000) / 10000
						local existing_y = (existing_coord % 10000) / 10000
						local distance = math.sqrt((x - existing_x) ^ 2 + (y - existing_y) ^ 2) * 100
						if distance <= 1 then
							is_duplicate = true
							break
						end
					end
					if not is_duplicate then
						ns.points[mapID][coord] = model
						ns.db.points[mapID] = ns.db.points[mapID] or {}
						ns.db.points[mapID][coord] = true
						HL:Refresh()
					end
				end
			end

        end
    end
end

recordPoint:RegisterEvent("CHAT_MSG_LOOT")
recordPoint:SetScript("OnEvent", OnEvent)

local next = next
local GameTooltip = GameTooltip
local WorldMapTooltip = WorldMapTooltip
local HandyNotes = HandyNotes

-- Retrieve and set map icons
local function work_out_texture(point)
    if not default_texture then
		local info = C_Texture.GetAtlasInfo("VignetteLoot")
        default_texture = {
            icon = info.file,
            tCoordLeft = info.leftTexCoord,
            tCoordRight = info.rightTexCoord,
            tCoordTop = info.topTexCoord,
            tCoordBottom = info.bottomTexCoord,
        }
    end
    return default_texture
end
local get_point_info = function(point)
    if point then
        local icon = 132858
        local category = "treasure"
        return label, icon, category, point.quest, point.faction
    end
end
local get_point_info_by_coord = function(uiMapID, coord)
    return get_point_info(ns.points[uiMapID] and ns.points[uiMapID][coord])
end

-- Create tooltip structure
local function handle_tooltip(tooltip, point)
    if point then
        -- major:
        if point.label then
            tooltip:AddLine(point.label)
        elseif point.item then
            if ns.db.tooltip_item or IsLeftShiftKeyDown() then
                tooltip:SetHyperlink(("item:%d"):format(point.item))
            else
                local link = select(2, GetItemInfo(point.item))
                tooltip:AddLine(link)
            end
        end
        if point.note then
            tooltip:AddLine(point.note, 255, 255, 255, true)
        end
    else
        tooltip:SetText(UNKNOWN)
    end
    tooltip:Show()
end
local handle_tooltip_by_coord = function(tooltip, uiMapID, coord)
    return handle_tooltip(tooltip, ns.points[uiMapID] and ns.points[uiMapID][coord])
end

---------------------------------------------------------
-- Plugin Handlers to HandyNotes
local HLHandler = {}
local info = {}

function HLHandler:OnEnter(uiMapID, coord)
    local tooltip = self:GetParent() == WorldMapButton and WorldMapTooltip or GameTooltip
    if ( self:GetCenter() > UIParent:GetCenter() ) then
        tooltip:SetOwner(self, "ANCHOR_LEFT")
    else
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
    end
    handle_tooltip_by_coord(tooltip, uiMapID, coord)
end

local function createWaypoint(button, uiMapID, coord)
    if TomTom then
        local x, y = HandyNotes:getXY(coord)
        TomTom:AddWaypoint(uiMapID, x, y, {
            title = get_point_info_by_coord(uiMapID, coord),
            persistent = nil,
            minimap = true,
            world = true
        })
    end
end

local function closeAllDropdowns()
    CloseDropDownMenus(1)
end

do
    local currentZone, currentCoord
    local function generateMenu(button, level)
        if (not level) then return end
        wipe(info)
		if TomTom then
			if (level == 1) then
				-- Create the title of the menu
				info.isTitle      = 1
				info.text         = "HandyNotes - " .. addonname:gsub("HandyNotes_", "")
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)
				wipe(info)

				
				-- Waypoint menu item
				info.text = "Create waypoint"
				info.notCheckable = 1
				info.func = createWaypoint
				info.arg1 = currentZone
				info.arg2 = currentCoord
				UIDropDownMenu_AddButton(info, level)
				wipe(info)

			-- Close menu item
				info.text         = "Close"
				info.func         = closeAllDropdowns
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)
				wipe(info)
			end
		end
    end
    local HL_Dropdown = CreateFrame("Frame", addonname.."DropdownMenu")
    HL_Dropdown.displayMode = "MENU"
    HL_Dropdown.initialize = generateMenu

    function HLHandler:OnClick(button, down, uiMapID, coord)
        if button == "RightButton" and not down then
			currentZone = uiMapID
            currentCoord = coord
            ToggleDropDownMenu(1, nil, HL_Dropdown, self, 0, 0)
        end
    end
end

function HLHandler:OnLeave(uiMapID, coord)
    if self:GetParent() == WorldMapButton then
        WorldMapTooltip:Hide()
    else
        GameTooltip:Hide()
    end
end

do
    -- This is a custom iterator we use to iterate over every node in a given zone
    local function iter(t, prestate)
        if not t then return nil end
        local state, value = next(t, prestate)
        while state do -- Have we reached the end of this zone?
            if value then
                local label, icon = get_point_info(value)
                return state, nil, icon, ns.db.icon_scale, ns.db.icon_alpha
            end
            state, value = next(t, state) -- Get next data
        end
        return nil, nil, nil, nil
    end
    function HLHandler:GetNodes2(uiMapID, minimap)
        return iter, ns.points[uiMapID], nil
    end
end

---------------------------------------------------------
-- Addon initialization, enabling and disabling

function HL:OnInitialize()
    -- Set up our database
    self.db = LibStub("AceDB-3.0"):New(addonname.."DB", ns.defaults)
    ns.db = self.db.profile
    HandyNotes_DreamsurgeCoalescenceDB = HandyNotes_DreamsurgeCoalescenceDB or {}
    HandyNotes_DreamsurgeCoalescenceDB.points = HandyNotes_DreamsurgeCoalescenceDB.points or {}
	ns.db.points = HandyNotes_DreamsurgeCoalescenceDB.points

    ns.points = ns.points or {}
	for mapID, coords in pairs(ns.points) do
		ns.points[mapID] = ns.points[mapID] or {}
		for coord, point in pairs(coords) do
			ns.points[mapID][coord] = model
		end
	end
	
	--import db
    if ns.db.points  then
        for mapID, coords in pairs(ns.db.points) do
            ns.points[mapID] = ns.points[mapID] or {}
            for coord, point in pairs(coords) do
                ns.points[mapID][coord] = model
            end
        end
    end
    
    -- Initialize our database with HandyNotes
    HandyNotes:RegisterPluginDB(addonname:gsub("HandyNotes_", ""), HLHandler, ns.options)

end

function HL:Refresh()
    self:SendMessage("HandyNotes_NotifyUpdate", addonname:gsub("HandyNotes_", ""))
end
