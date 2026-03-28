-- ShopData.luau
-- 道具商店資料定義（Server + Client 共用）

return {
	{
		Id = "Shield",
		Name = "🛡️ 無敵盾",
		Desc = "3次內不會被老師擊倒",
		Price = 100,
		Uses = 3,
	},
	{
		Id = "Blame",
		Name = "🎯 甩鍋器",
		Desc = "答錯時懲罰轉給其他玩家（3次）",
		Price = 150,
		Uses = 3,
	},
	{
		Id = "Cheat",
		Name = "📖 作弊器",
		Desc = "顯示正確答案（3題）",
		Price = 200,
		Uses = 3,
	},
}
