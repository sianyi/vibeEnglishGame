--!strict
-- QuestionData.luau
-- 從 VocabTrainer API 動態載入單字題庫 (10,844 個單字，A1~C2)

local HttpService = game:GetService("HttpService")

export type Question = {
	Word: string,
	Definition: string,
	IsCorrect: boolean,
	Difficulty: number, -- 1: Easy, 2: Medium, 3: Hard
	Level: number,      -- 1000, 2000, 3000, 4000, 5000
}

export type WordLevel = number  -- 1000, 2000, 3000, 4000, or 5000
export type Difficulty = number -- 1, 2, or 3

local QuestionData = {}

local BASE_URL = "https://vocab.kubahuang.synology.me"
local token: string? = nil

-- game Level → API difficulty range (1=A1 … 6=C2)
local LEVEL_TO_DIFF: {[number]: {min: number, max: number}} = {
	[1000] = { min = 1, max = 2 }, -- A1~A2
	[2000] = { min = 2, max = 3 }, -- A2~B1
	[3000] = { min = 3, max = 4 }, -- B1~B2
	[4000] = { min = 4, max = 5 }, -- B2~C1
	[5000] = { min = 5, max = 6 }, -- C1~C2
}

-- game Difficulty (1/2/3) → API difficulty range
local GAME_DIFF_TO_API: {[number]: {min: number, max: number}} = {
	[1] = { min = 1, max = 2 },
	[2] = { min = 3, max = 4 },
	[3] = { min = 5, max = 6 },
}

-- API cefr level (1~6) → game Level
local CEFR_TO_LEVEL: {[number]: number} = {
	[1] = 1000,
	[2] = 2000,
	[3] = 3000,
	[4] = 4000,
	[5] = 5000,
	[6] = 5000,
}

-- API cefr level (1~6) → game Difficulty (1/2/3)
local CEFR_TO_DIFFICULTY: {[number]: number} = {
	[1] = 1, [2] = 1,
	[3] = 2, [4] = 2,
	[5] = 3, [6] = 3,
}

-- 靜態後備題庫（API 不可用時）
local FALLBACK: {Question} = {
	{ Word = "Hello",    Definition = "你好",   IsCorrect = true,  Difficulty = 1, Level = 1000 },
	{ Word = "Computer", Definition = "電腦",   IsCorrect = true,  Difficulty = 1, Level = 2000 },
	{ Word = "Ephemeral",Definition = "永恆的", IsCorrect = false, Difficulty = 3, Level = 5000 },
}

local function login(): boolean
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url    = BASE_URL .. "/api/auth/login",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
			Body   = "username=guest&password=",
		})
	end)
	if ok and res.StatusCode == 200 then
		local data = HttpService:JSONDecode(res.Body)
		token = data.access_token
		return true
	end
	warn("[QuestionData] 登入失敗")
	return false
end

local function fetchFromAPI(diffMin: number, diffMax: number, count: number): {Question}
	if not token then
		if not login() then return {} end
	end

	local url = string.format(
		"%s/api/quiz/questions?difficulty_min=%d&difficulty_max=%d&count=%d&mode=random",
		BASE_URL, diffMin, diffMax, count
	)

	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url    = url,
			Method = "GET",
			Headers = { Authorization = "Bearer " .. (token :: string) },
		})
	end)

	if not ok then
		warn("[QuestionData] 請求失敗")
		return {}
	end

	-- Token 過期，重新登入一次
	if res.StatusCode == 401 then
		if not login() then return {} end
		ok, res = pcall(function()
			return HttpService:RequestAsync({
				Url    = url,
				Method = "GET",
				Headers = { Authorization = "Bearer " .. (token :: string) },
			})
		end)
		if not ok or res.StatusCode ~= 200 then return {} end
	end

	if res.StatusCode ~= 200 then return {} end

	local data = HttpService:JSONDecode(res.Body)
	local questions: {Question} = {}

	for _, q in ipairs(data.questions) do
		local cefrNum: number = (q.level :: number?) or 3
		local gameLevel = CEFR_TO_LEVEL[cefrNum] or 3000
		local gameDiff  = CEFR_TO_DIFFICULTY[cefrNum] or 2

		-- 50% 顯示正確答案、50% 顯示錯誤選項，製造判斷題效果
		local isCorrect = (math.random(0, 1) == 1)
		local displayDef: string

		if isCorrect then
			displayDef = q.correct_answer :: string
		else
			local wrong: {string} = {}
			for _, opt in ipairs(q.options :: {string}) do
				if opt ~= q.correct_answer then
					table.insert(wrong, opt)
				end
			end
			if #wrong > 0 then
				displayDef = wrong[math.random(1, #wrong)]
			else
				displayDef = q.correct_answer :: string
				isCorrect  = true
			end
		end

		table.insert(questions, {
			Word       = q.word :: string,
			Definition = displayDef,
			IsCorrect  = isCorrect,
			Difficulty = gameDiff,
			Level      = gameLevel,
		})
	end

	return questions
end

-- 取得隨機題目
function QuestionData.GetRandomQuestion(difficultyLevel: number?, wordLevel: number?): Question
	local questions = QuestionData.GetQuestions(1, difficultyLevel, wordLevel)
	return questions[1]
end

-- 取得多個題目
function QuestionData.GetQuestions(count: number, difficultyLevel: number?, wordLevel: number?): {Question}
	local diffMin, diffMax = 1, 6

	if wordLevel then
		local range = LEVEL_TO_DIFF[wordLevel]
		if range then
			diffMin = range.min
			diffMax = range.max
		end
	elseif difficultyLevel then
		local range = GAME_DIFF_TO_API[difficultyLevel]
		if range then
			diffMin = range.min
			diffMax = range.max
		end
	end

	local questions = fetchFromAPI(diffMin, diffMax, count)

	if #questions == 0 then
		warn("[QuestionData] API 無回應，使用後備題庫")
		return { FALLBACK[math.random(1, #FALLBACK)] }
	end

	return questions
end

-- 取得所有可用的單字級別
function QuestionData.GetAvailableLevels(): {number}
	return {1000, 2000, 3000, 4000, 5000}
end

-- 取得該級別的題目數量（API 統計數字）
function QuestionData.GetQuestionCount(wordLevel: number?): number
	if wordLevel == nil then return 10844 end
	local counts: {[number]: number} = {
		[1000] = 732,
		[2000] = 1002,
		[3000] = 4630,
		[4000] = 3093,
		[5000] = 1387,
	}
	return counts[wordLevel] or 0
end

return QuestionData
