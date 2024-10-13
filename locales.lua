local _, ns = ...

local L = setmetatable({}, {
    __index = function(table, key)
        if key then
            table[key] = tostring(key)
        end
        return tostring(key)
    end,
})

ns.L = L

local locale = GetLocale()

if locale == 'enUs' then
	L["DreamsurgeCoalescence"] = "Dreamsurge Coalescence"
	
elseif locale == 'zhCN' then
	L["DreamsurgeCoalescence"] = "梦涌凝珠"
	
end
