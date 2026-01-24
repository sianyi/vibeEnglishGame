# VibeGame 開發進度表

## 🎯 專案目標
建立一個 Roblox "Vibe" 風格的社交單字問答遊戲。玩家在獨立或多人教室中，根據老師 NPC 的題目移動到 YES/NO 區域作答。

## 🔄 當前開發焦點 (Current Focus)
- [ ] **題庫系統整合**
  - [x] 建立 `QuestionData` 基礎結構 (Commit: 5b8655e)
  - [ ] 將 `QuestionData` 整合進 `MultiplayerManager` 與 `GameSession`
  - [ ] 實作難度分級邏輯 (Easy/Medium/Hard)
  - [ ] **新增單字分級挑戰**: 實作 1000, 2000, 3000, 4000, 5000 單字級別選擇功能
- [ ] **老師 NPC 行為優化**
  - [x] 基礎追逐與攻擊邏輯
  - [ ] 新增老師的情緒動畫 (答錯生氣、答對開心)
  - [ ] 實作老師的 Idle (待機) 動作

## ✅ 已完成 (Done)
- [x] **基礎架構**
  - [x] Rojo 專案初始化
  - [x] 建立 `GameSession` (Client) 物件導向架構
  - [x] 解決多人遊戲狀態干擾 (獨立 Local Classroom)
- [x] **核心玩法 (Core Loop)**
  - [x] 題目顯示 (四面黑板同步)
  - [x] 地板 YES/NO 判定
  - [x] 懲罰機制 (跌倒/Ragdoll)
  - [x] 遊戲循環 (開始 -> 出題 -> 結算 -> 重置)

## 📝 待辦事項 (Backlog)
- [ ] **UI/UX**
  - [ ] 製作更精緻的題目 UI (SurfaceGui 優化)
  - [ ] 加入背景音樂 (Lo-fi Vibe) 與音效管理
- [ ] **社交功能**
  - [ ] 大廳觀戰系統
  - [ ] 排行榜 (Leaderstats)
- [ ] **🎨 美術與氛圍 (Visuals & Vibe)**
  - [ ] **優化角色房間**: 讓玩家擁有可自定義的個人空間/房間
  - [ ] **地圖細節**: 提升教室與大廳的光影 (Future Lighting) 與模型細節
  - [ ] **角色外觀**: 增加 Vibe 風格的預設服裝或配件
- [ ] **💰 經濟系統 (Economy)**
  - [ ] **金幣用途設計**: 商店系統實作
  - [ ] **購買項目**: 
    - [ ] 特殊動作 (Dances/Poses)
    - [ ] 房間裝飾/家具
    - [ ] 復活/免死金牌

## 🐛 已知 Bug / 需優化
- [ ] 老師 NPC 目前移動稍顯生硬，需要加入 PathfindingService 優化。
- [ ] 手機版操作介面需要測試與調整。