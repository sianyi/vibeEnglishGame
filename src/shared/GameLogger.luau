--!strict
-- GameLogger.luau
-- 遊戲日誌系統 - 將日誌寫入檔案

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameLogger = {}
GameLogger.__index = GameLogger

export type LogLevel = "INFO" | "WARN" | "ERROR" | "DEBUG"

-- 日誌緩衝區 (累積後寫入)
local logBuffer = {}
local MAX_BUFFER_SIZE = 50 -- 累積 50 條後寫入一次
local currentSessionId = ""

-- 初始化會話 ID
local function initSession()
	currentSessionId = os.date("%Y%m%d_%H%M%S") .. "_" .. math.random(1000, 9999)
	return currentSessionId
end

function GameLogger.new(source: string): GameLogger
	local self = setmetatable({}, GameLogger)
	self.source = source
	self.sessionId = currentSessionId
	
	-- 初始化會話
	if currentSessionId == "" then
		initSession()
		self.sessionId = currentSessionId
	end
	
	return self
end

-- 格式化日誌訊息
local function formatMessage(level: LogLevel, source: string, message: string): string
	local timestamp = os.date("%H:%M:%S")
	return string.format("[%s] [%s] [%s] %s", timestamp, level, source, message)
end

-- 添加日誌到緩衝區
local function addToBuffer(logEntry: string)
	table.insert(logBuffer, logEntry)
	
	-- 如果緩衝區滿了，就輸出到控制台（Roblox 無法寫入檔案，但我們可以模擬）
	if #logBuffer >= MAX_BUFFER_SIZE then
		flushLogs()
	end
end

-- 刷新緩衝區（輸出所有日誌）
function flushLogs()
	if #logBuffer == 0 then return end
	
	print("=== 📝 Game Log Session " .. currentSessionId .. " ===")
	for _, log in ipairs(logBuffer) do
		print(log)
	end
	print("=== End of Session " .. currentSessionId .. " ===\n")
	
	-- 清空緩衝區
	logBuffer = {}
end

function GameLogger:info(message: string)
	local formatted = formatMessage("INFO", self.source, message)
	print(formatted)
	addToBuffer(formatted)
end

function GameLogger:warn(message: string)
	local formatted = formatMessage("WARN", self.source, message)
	warn(formatted)
	addToBuffer(formatted)
end

function GameLogger:error(message: string)
	local formatted = formatMessage("ERROR", self.source, message)
	warn(formatted)
	addToBuffer(formatted)
end

function GameLogger:debug(message: string)
	-- 調試訊息預設不顯示，除非需要
	local formatted = formatMessage("DEBUG", self.source, message)
	-- print(formatted) -- 註釋掉以減少雜訊
	addToBuffer(formatted)
end

function GameLogger:logAction(action: string, details: string)
	local formatted = formatMessage("ACTION", self.source, action .. " | " .. details)
	print(formatted)
	addToBuffer(formatted)
end

-- 獲取當前會話 ID
function GameLogger.getSessionId(): string
	if currentSessionId == "" then
		initSession()
	end
	return currentSessionId
end

-- 獲取所有緩衝的日誌
function GameLogger.getAllLogs(): {string}
	return logBuffer
end

return GameLogger
