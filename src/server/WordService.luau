local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WordService = {}

-- 載入單字庫
local Shared = ReplicatedStorage:WaitForChild("Shared")
local fullWordList = require(Shared:WaitForChild("WordList"))

-- 翻譯函數
local function translateText(text)
	local encoded = HttpService:UrlEncode(text)
	local url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=zh-TW&dt=t&q=" .. encoded
	
	local success, result = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if success then
		local data = HttpService:JSONDecode(result)
		if data and data[1] and data[1][1] and data[1][1][1] then
			return data[1][1][1]
		end
	end
	return nil
end

-- 生成題目列表
function WordService.generateQuestions(count)
	count = count or 10
	local validPairs = {}
	local pool = table.clone(fullWordList)
	
	for i = 1, count do
		if #pool == 0 then break end
		local idx = math.random(1, #pool)
		local word = table.remove(pool, idx)
		
		local cn = translateText(word)
		if not cn then cn = "翻譯失敗" end
		
		table.insert(validPairs, {en = word, cn = cn})
		task.wait(0.1)
	end
	
	local gameData = {}
	for i, pair in ipairs(validPairs) do
		local isCorrect = math.random() > 0.5
		local displayCn = pair.cn
		
		if not isCorrect and #validPairs > 1 then
			local wrongIdx = math.random(1, #validPairs)
			while wrongIdx == i do wrongIdx = math.random(1, #validPairs) end
			displayCn = validPairs[wrongIdx].cn
		end
		
		table.insert(gameData, {en = pair.en, displayCn = displayCn, isCorrect = isCorrect})
	end
	
	return gameData
end

return WordService