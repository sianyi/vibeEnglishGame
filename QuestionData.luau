--!strict
-- QuestionData.luau
-- 管理遊戲內的單字題庫與分類

export type Question = {
	Word: string,
	Definition: string, -- 或是中文翻譯
	IsCorrect: boolean, -- 用於產生陷阱題，例如 "Apple: 香蕉" (False)
	Difficulty: number, -- 1: Easy, 2: Medium, 3: Hard
}

local QuestionData = {}

-- 這裡未來可以改為從外部 JSON 或 Google Sheets 匯入
local database: {Question} = {
	{ Word = "Apple", Definition = "蘋果", IsCorrect = true, Difficulty = 1 },
	{ Word = "Banana", Definition = "葡萄", IsCorrect = false, Difficulty = 1 },
	{ Word = "Computer", Definition = "電腦", IsCorrect = true, Difficulty = 1 },
	{ Word = "Algorithm", Definition = "演算法", IsCorrect = true, Difficulty = 2 },
	{ Word = "Polymorphism", Definition = "多型", IsCorrect = true, Difficulty = 3 },
	{ Word = "Ephemeral", Definition = "永恆的", IsCorrect = false, Difficulty = 3 }, -- 陷阱：意思是短暫的
}

-- 取得隨機題目
function QuestionData.GetRandomQuestion(difficultyLevel: number?): Question
	local pool = {}
	
	-- 如果有指定難度，只篩選該難度的題目
	if difficultyLevel then
		for _, q in ipairs(database) do
			if q.Difficulty == difficultyLevel then
				table.insert(pool, q)
			end
		end
	else
		pool = database
	end

	-- 如果該難度沒題目，回傳任意題目避免錯誤
	if #pool == 0 then pool = database end

	return pool[math.random(1, #pool)]
end

return QuestionData