--!strict
-- QuestionData.luau
-- 管理遊戲內的單字題庫與分類

export type Question = {
	Word: string,
	Definition: string, -- 中文翻譯
	IsCorrect: boolean, -- 用於產生陷阱題，例如 "Apple: 香蕉" (False)
	Difficulty: number, -- 1: Easy, 2: Medium, 3: Hard
	Level: number, -- 單字級別: 1000, 2000, 3000, 4000, 5000
}

export type WordLevel = 1000 | 2000 | 3000 | 4000 | 5000
export type Difficulty = 1 | 2 | 3 -- 1: Easy, 2: Medium, 3: Hard

local QuestionData = {}

-- 單字資料庫 (未来可以从外部 JSON 导入)
-- Level: 1000-5000 最常用單字
-- Difficulty: 1=Easy(常見單字), 2=Medium(中等), 3=Hard(較難)
local database: {Question} = {
	-- Level 1000 (基礎單字)
	{ Word = "Apple", Definition = "蘋果", IsCorrect = true, Difficulty = 1, Level = 1000 },
	{ Word = "Banana", Definition = "葡萄", IsCorrect = false, Difficulty = 1, Level = 1000 },
	{ Word = "Book", Definition = "書", IsCorrect = true, Difficulty = 1, Level = 1000 },
	{ Word = "Car", Definition = "車", IsCorrect = true, Difficulty = 1, Level = 1000 },
	{ Word = "Cat", Definition = "狗", IsCorrect = false, Difficulty = 1, Level = 1000 },
	{ Word = "Dog", Definition = "狗", IsCorrect = true, Difficulty = 1, Level = 1000 },
	{ Word = "House", Definition = "房子", IsCorrect = true, Difficulty = 1, Level = 1000 },
	{ Word = "Water", Definition = "水", IsCorrect = true, Difficulty = 1, Level = 1000 },
	{ Word = "Food", Definition = "食物", IsCorrect = true, Difficulty = 1, Level = 1000 },
	{ Word = "Tree", Definition = "樹", IsCorrect = true, Difficulty = 1, Level = 1000 },
	
	-- Level 2000 (进阶单字)
	{ Word = "Computer", Definition = "電腦", IsCorrect = true, Difficulty = 1, Level = 2000 },
	{ Word = "Television", Definition = "電視", IsCorrect = true, Difficulty = 1, Level = 2000 },
	{ Word = "Restaurant", Definition = "餐廳", IsCorrect = true, Difficulty = 2, Level = 2000 },
	{ Word = "Hospital", Definition = "醫院", IsCorrect = true, Difficulty = 1, Level = 2000 },
	{ Word = "Beautiful", Definition = "醜的", IsCorrect = false, Difficulty = 2, Level = 2000 },
	{ Word = "Important", Definition = "重要", IsCorrect = true, Difficulty = 2, Level = 2000 },
	{ Word = "Different", Definition = "相同", IsCorrect = false, Difficulty = 2, Level = 2000 },
	{ Word = "Complete", Definition = "完成", IsCorrect = true, Difficulty = 2, Level = 2000 },
	{ Word = "Experience", Definition = "經驗", IsCorrect = true, Difficulty = 2, Level = 2000 },
	{ Word = "Remember", Definition = "忘記", IsCorrect = false, Difficulty = 2, Level = 2000 },
	
	-- Level 3000 (中高级单字)
	{ Word = "Algorithm", Definition = "演算法", IsCorrect = true, Difficulty = 2, Level = 3000 },
	{ Word = "Function", Definition = "功能", IsCorrect = true, Difficulty = 2, Level = 3000 },
	{ Word = "Variable", Definition = "變數", IsCorrect = true, Difficulty = 2, Level = 3000 },
	{ Word = "Database", Definition = "資料庫", IsCorrect = true, Difficulty = 3, Level = 3000 },
	{ Word = "Network", Definition = "網路", IsCorrect = true, Difficulty = 2, Level = 3000 },
	{ Word = "Software", Definition = "硬體", IsCorrect = false, Difficulty = 2, Level = 3000 },
	{ Word = "Password", Definition = "密碼", IsCorrect = true, Difficulty = 2, Level = 3000 },
	{ Word = "Download", Definition = "下載", IsCorrect = true, Difficulty = 2, Level = 3000 },
	{ Word = "Upload", Definition = "上傳", IsCorrect = true, Difficulty = 2, Level = 3000 },
	{ Word = "Browser", Definition = "瀏覽器", IsCorrect = true, Difficulty = 2, Level = 3000 },
	
	-- Level 4000 (高级单字)
	{ Word = "Polymorphism", Definition = "多型", IsCorrect = true, Difficulty = 3, Level = 4000 },
	{ Word = "Encapsulation", Definition = "封裝", IsCorrect = true, Difficulty = 3, Level = 4000 },
	{ Word = "Inheritance", Definition = "繼承", IsCorrect = true, Difficulty = 3, Level = 4000 },
	{ Word = "Concurrency", Definition = "並發", IsCorrect = true, Difficulty = 3, Level = 4000 },
	{ Word = "Asynchronous", Definition = "同步", IsCorrect = false, Difficulty = 3, Level = 4000 },
	{ Word = "Encryption", Definition = "加密", IsCorrect = true, Difficulty = 3, Level = 4000 },
	{ Word = "Firewall", Definition = "防火牆", IsCorrect = true, Difficulty = 3, Level = 4000 },
	{ Word = "Algorithm", Definition = "演算法", IsCorrect = true, Difficulty = 3, Level = 4000 },
	{ Word = "Compiler", Definition = "直譯器", IsCorrect = false, Difficulty = 3, Level = 4000 },
	{ Word = "Debugger", Definition = "除錯器", IsCorrect = true, Difficulty = 3, Level = 4000 },
	
	-- Level 5000 (专业/学术单字)
	{ Word = "Ephemeral", Definition = "永恆的", IsCorrect = false, Difficulty = 3, Level = 5000 },
	{ Word = "Ubiquitous", Definition = "普遍的", IsCorrect = true, Difficulty = 3, Level = 5000 },
	{ Word = "Paradigm", Definition = "典範", IsCorrect = true, Difficulty = 3, Level = 5000 },
	{ Word = "Syntactic", Definition = "語意的", IsCorrect = false, Difficulty = 3, Level = 5000 },
	{ Word = "Semantics", Definition = "語義學", IsCorrect = true, Difficulty = 3, Level = 5000 },
	{ Word = "Heterogeneous", Definition = "同質的", IsCorrect = false, Difficulty = 3, Level = 5000 },
	{ Word = "Idempotent", Definition = "冪等", IsCorrect = true, Difficulty = 3, Level = 5000 },
	{ Word = "Latency", Definition = "延遲", IsCorrect = true, Difficulty = 3, Level = 5000 },
	{ Word = "Throughput", Definition = "吞吐量", IsCorrect = true, Difficulty = 3, Level = 5000 },
	{ Word = "Scalability", Definition = "可擴展性", IsCorrect = true, Difficulty = 3, Level = 5000 },
}

-- 取得隨機題目
function QuestionData.GetRandomQuestion(difficultyLevel: number?, wordLevel: number?): Question
	local pool = {}
	
	for _, q in ipairs(database) do
		local matchesDifficulty = (difficultyLevel == nil or q.Difficulty == difficultyLevel)
		local matchesLevel = (wordLevel == nil or q.Level == wordLevel)
		
		if matchesDifficulty and matchesLevel then
			table.insert(pool, q)
		end
	end

	-- 如果沒有符合的題目，回傳任意題目避免錯誤
	if #pool == 0 then
		pool = database
	end

	return pool[math.random(1, #pool)]
end

-- 取得多個題目
function QuestionData.GetQuestions(count: number, difficultyLevel: number?, wordLevel: number?): {Question}
	local questions = {}
	local pool = {}
	
	-- 建立候選池
	for _, q in ipairs(database) do
		local matchesDifficulty = (difficultyLevel == nil or q.Difficulty == difficultyLevel)
		local matchesLevel = (wordLevel == nil or q.Level == wordLevel)
		
		if matchesDifficulty and matchesLevel then
			table.insert(pool, q)
		end
	end
	
	-- 如果沒有符合的題目，使用全部
	if #pool == 0 then
		pool = database
	end
	
	-- 隨機選取不重複的題目
	for i = 1, math.min(count, #pool) do
		local idx = math.random(1, #pool)
		table.insert(questions, table.remove(pool, idx))
	end
	
	return questions
end

-- 取得所有可用的單字級別
function QuestionData.GetAvailableLevels(): {number}
	local levels = {}
	local seen = {}
	
	for _, q in ipairs(database) do
		if not seen[q.Level] then
			seen[q.Level] = true
			table.insert(levels, q.Level)
		end
	end
	
	table.sort(levels)
	return levels
end

-- 取得該級別的題目數量
function QuestionData.GetQuestionCount(wordLevel: number?): number
	if wordLevel == nil then
		return #database
	end
	
	local count = 0
	for _, q in ipairs(database) do
		if q.Level == wordLevel then
			count += 1
		end
	end
	return count
end

return QuestionData
