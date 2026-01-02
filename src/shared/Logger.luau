local Logger = {}
Logger.__index = Logger

-- Build flag: 設為 false 即可關閉所有 debug log (建議在發布前關閉)
Logger.BUILD_DEBUG = true

function Logger.new(context)
	local self = setmetatable({}, Logger)
	self.context = context or "Global"
	return self
end

function Logger:debug(...)
	if Logger.BUILD_DEBUG then
		print(string.format(">>> [DEBUG] [%s]", self.context), ...)
	end
end

function Logger:warn(...)
	warn(string.format(">>> [WARN] [%s]", self.context), ...)
end

return Logger