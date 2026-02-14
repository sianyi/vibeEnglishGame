# VibeGame Development Tasks (AI Optimized)

> **Note for AI Agent**: Always refer to `AI_CONTEXT.md` for architecture, tech stack, and coding conventions before implementing features.

## 🎯 Project Goal
Create a Roblox "Vibe" style social word trivia game. Players answer questions from a Teacher NPC by moving to YES/NO zones in independent or multiplayer classrooms.

## 🚀 Current Sprint (High Priority)

### 1. Question System Integration (題庫系統整合)
*Context*: `src/ReplicatedStorage/QuestionData.luau` exists. Needs integration into the game loop.
- [x] **Integrate QuestionData**:
    - Modified `src/server/MultiplayerManager.server.luau` to require `QuestionData`.
    - Updated the question selection logic to pick from `QuestionData`.
    - Questions are now replicated to clients via RemoteEvents.
- [x] **Implement Difficulty Logic**:
    - Added logic to categorize or filter questions by difficulty (Easy/Medium/Hard) in `QuestionData`.
    - Allow `GameSession` (Client) or `MultiplayerManager` (Server) to request specific difficulties.
- [x] **Word Level Challenge (1000-5000 Levels)**:
    - **Data Expansion**: Added datasets for 2000, 3000, 4000, and 5000 most common English words.
    - **Zone-based Selection**: Created different trigger zones in the game world for each level (LevelZone_1000, LevelZone_2000, etc.).
    - **Data Structure**: Tagged questions in `QuestionData` with levels.
    - **Room Isolation**: Each level has its own zone in the lobby, players choose their level by entering the corresponding zone.

### 2. Teacher NPC Behavior (老師 NPC 行為)
*Context*: Teacher is an R15/R6 Rig managed by Server.
- [x] **Emotion Animations**:
    - Imported animations for "Angry" (Wrong Answer) and "Happy" (Correct Answer).
    - Play these animations on the NPC Humanoid in `MultiplayerManager` during the result phase.
- [x] **Idle Behavior**:
    - Implemented a loop in `MultiplayerManager` for the Teacher to wander near the podium when not chasing players.

## ✅ Completed
- [x] **Infrastructure**: Rojo setup, `GameSession` (Client) OOP, Independent Local Classrooms.
- [x] **Core Loop**: Question display (Blackboards), YES/NO zone detection, Punishment (Ragdoll), Game Loop (Start -> Question -> Result -> Reset).
- [x] **QuestionData Structure**: Full module with 50+ questions across 5 levels (1000-5000).
- [x] **Basic NPC**: Chasing and attack logic.
- [x] **Level Selection**: Zone-based level selection (players choose level by entering different zones).
- [x] **Teacher Emotions**: Happy (correct), Angry (wrong), Idle, Walk animations.
- [x] **Teacher Idle**: Wanders near podium when not chasing players.

## 📝 Backlog (Future Tasks)

### UI/UX
- [x] **Countdown UI**: Implemented basic start countdown.
- [ ] **Question UI**: Improve SurfaceGui visuals on blackboards.
- [ ] **Audio**: Add Lo-fi background music and sound effects manager.

### Social & Economy
- [ ] **Spectating**: Allow players in Lobby to watch active games.
- [ ] **Leaderboards**: Global wins/points.
- [ ] **Shop System**: Use currency for Dances, Room Decor, Revives.

### Visuals & Vibe
- [ ] **Custom Rooms**: Player-customizable spaces.
- [ ] **Lighting**: Upgrade to Future Lighting.
- [ ] **Vibe Aesthetics**: Default outfits and accessories.

### Economy
- [ ] **Currency**: Implement Gold/Points system.
- [ ] **Shop Items**: Dances, Poses, Furniture, Revives.

## 🐛 Known Issues / Optimization
- [ ] **NPC Pathfinding**: Current movement is rigid. Implement `PathfindingService` for smoother navigation around desks.
- [ ] **Mobile Controls**: Test and adjust UI touch targets.
