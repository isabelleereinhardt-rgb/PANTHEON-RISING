# Pantheon Rising: HONORIS — Audit 01 (Documents Only)

**Date:** 2026-10-17
**Sources read in full:**
- *Pantheon Rising [HONORIS]: Master Document* (21 pages)
- *PANTHEON RISING [HONORIS] — Development Bible & Enhanced Prompt* (42 pages, v1.0, Jan 2026)
- Your Master Development Prompt (sections 1–29)
- Two reference images (inspiration only, see section 7)

> **Main limitation:** this audit did **not** look at your Roblox place. Studio was not reachable
> from the cloud session (see `CONNECT-ROBLOX-STUDIO.md`). Each finding below is labeled:
> **[VERIFIED-DOC]** means it was checked against the documents. **[UNVERIFIED-PROJECT]** means it
> still needs checking in Studio. **[PROPOSAL]** means it is a suggestion that needs your approval.

---

## 1. Project inventory

**[UNVERIFIED-PROJECT]** Not done yet. It needs `tools/StudioInventory.lua` output from your place.
The Git repository was empty before this audit, so there is no code here to inspect.

The inventory script reports on:
- every script and module
- every RemoteEvent and RemoteFunction
- Teams, SpawnLocations and GUIs
- part and effect counts
- **free-model backdoor patterns** such as `require(<asset id>)`, `loadstring` and `getfenv`

The backdoor check matters most. Backdoors are common in Toolbox models, and the Bible recommends Toolbox assets.

## 2. Documentation alignment

The two documents mostly agree. The Bible is the more detailed of the two.

| Topic | Master Doc | Dev Bible | Your Master Prompt | Status |
|---|---|---|---|---|
| Players / teams | 16 max, 8 to start, 1-min countdown | Same; 4 teams × 4 | Same, plus queues and smaller casual matches | Prompt **extends** the design. Casual small matches are new |
| Game tone | "casual game" | Battle royale | Adds **Ranked** queue | Ranked is a **new addition** that needs your approval |
| Lives | Not stated | 3 per match; Battle Circle deaths count; 0 = spectate | 3 lives | Agree |
| Downed / revive | **None** | **None** | Rescues/Revives leaderboard, anti-camping of downed players | **Conflict**: no revive mechanic exists in canon (see 3.2) |
| Assists | None | None | Damage shortly before elimination | New stat, needs a data-schema addition |
| Leaderboards | "global leaderboards" | GlobalWins, SeasonWins, WeeklyWins, TotalKills + podium | Wins, **Level**, Assists, Rescues | **Conflict**: no Level/XP exists in the Bible schema |
| Currency | Cosmetic **loot boxes**, VIP | Drachmas (free) + Olympian_Coins (premium) | Don't add currencies without approval | See 3.5 (loot-box policy risk) |
| Places | Hub + portals to S1–S4 places | Same | Lobby + matchmaking | Matchmaking across servers needs TeleportService/MemoryStore |
| Points | Kills, relics, flags | Full table + **Power Shrine 8** | Table without Power Shrine | Power Shrine is missing from the Bible's quick reference too. Check it is intended |
| Class stats | Abilities only | HP/Speed/Dmg table + ability numbers | Same table | Agree |

## 3. Critical issues (most serious first)

### 3.1 Security bug in the Bible's sample `QuizSystem` [VERIFIED-DOC]

This applies **only if that sample code was copied into your place**. Check this first.
- **Score inflation:** `RecordAnswer` *adds* points on every call. A cheater can fire
  `QuizEvents` 1000 times for question 1, answer D, and gets Cyclops +10,000. The `answers`
  table is overwritten, but `scores` keeps growing.
- **No input validation:** a bad `questionIndex`/`answerIndex` (nil, string, 999) makes the
  handler error. Out-of-range or non-integer values are never rejected.
- **Crash when all classes are full:** `math.random(#available)` with an empty table throws an error.
- **Memory leak:** `playerAnswers` is never cleared when a player leaves.

**Fix (small, safe):**
- Validate the indexes.
- Accept each question only once.
- Compute the scores from the stored answers when the class is assigned, not as answers arrive.
- Handle the "all full" case.
- Clear the data on `PlayerRemoving`.

### 3.2 Rescues/Revives leaderboard has no canon mechanic [VERIFIED-DOC]

Neither document has a downed state or revives. Death simply costs a life and you respawn at the safe zone.
Your prompt picks Rescues/Revives as leaderboard #4 and asks for downed-player anti-camping.
**Decision needed** (section 9).

### 3.3 Quiz weighting heavily favors Cyclops [VERIFIED-DOC, design note — not changed]

The highest-score fallback uses +10/+5/+4/+1 weights. As a result:
- **One** Cyclops answer can beat two answers for another class. For example, Chimera, Chimera,
  Siren, Siren, Cyclops gives Cyclops 10, Siren 8, Chimera 2, so the player is assigned Cyclops.
- **Chimera can almost never win** without 3 of the 5 answers.
- Ties (e.g. 2× Minotaur = 10 vs 1× Cyclops = 10) are broken by `table.sort`, which is not stable,
  so the result is effectively random.

This is canon, so it is preserved. You should still confirm it is intentional, because it affects team balance.

### 3.4 Movement anti-cheat must allow canon abilities [VERIFIED-DOC]

Several abilities move players in ways that look like cheating to a simple speed check:
- Bull Rush: a 30-stud charge
- Siren Water Dash: an *instant 25-stud teleport*
- Rock Throw: knockback
- Battle Circle teleports and respawns

The anti-cheat must whitelist these as server-approved moves. Otherwise it will flag legitimate Minotaur and Siren players.

Cyclops "headshots 1.5x" must be decided by the **server's** raycast, never by the client.

### 3.5 Paid loot boxes [VERIFIED-DOC, policy risk]

The Master Doc lists "cosmetic loot boxes", and the Bible adds a premium currency.
On Roblox, paid random items carry extra policy requirements, such as showing the odds and following
regional rules. Read Roblox's current Paid Random Items policy before building this.
**Recommendation:** use direct-purchase cosmetics instead, which keeps the canon's "no pay-to-win" rule.

### 3.6 Quest reward farming [VERIFIED-DOC]

Each NPC quest pays **12 team points** and has a retry cooldown. The documents do not say whether a quest can be completed:
- once per player per match
- once per team per match
- repeatedly

If repeat completions are allowed, a team of 4 could farm 48+ points from one NPC (100 points wins).
**Proposal:** once per player per match, enforced by the server.

### 3.7 Battle Circle disconnects are undefined [VERIFIED-DOC]

"Fleeing: cannot escape" is defined, but disconnecting is not.
A player who quits to avoid losing a life is a likely exploit.
**Proposal:** treat a disconnect as a forfeit (loss of a life), like a loss.

## 4. Smaller content issues found in the documents

- **Meratai quiz Q10** quotes the line *"Drag you under"*, which **is not in the song lyrics**. Fix the
  question or add the line. Lore owner decides.
- **The Crow:** "Words appear on screen one at a time" and then the player types them. If the word is
  shown, the test is trivial. Should it be spoken audio, scrambled, or shown briefly and then hidden?
- **Hypnotic Song** inverts controls for 4 s. This is an accessibility concern, and some games cap or soften it.
  Keep it, but consider a setting.
- Master Doc sections 1–8 of the task list ("Story and Narrative Development"…) are **duplicated** word for word. This is harmless.
- **Bull Rush:** `ClassData` uses `DamageBase = 25 + 0.5/stud`, while the stats table says "Base Damage 20".
  These are probably different things (ability damage vs basic attack). Confirm.
- **Battle Circle speed priority:** abilities resolve by Speed stat, so the Siren (18) always acts first
  and the Minotaur (14) always acts last. Watch this during balance testing.

## 5. Preservation list (do not replace casually)

- the 4 classes and their abilities and patrons
- the quiz text and weights
- all NPC names, dialogue, branches and cooldowns
- the song lyrics
- the 36 lore pieces
- the season names and arc
- the point values
- the 3 lives rule
- the 10-min / 100-pt victory order
- the team colours (#DC143C, #FF6B35, #1E90FF, #FFD700, UI #1a1a2e / #d4af37)
- the map's compass layout (Cyclops N, Siren W, Minotaur E, Chimera S, Olympus centre)
- once inventoried: **every existing script and asset in your place**

## 6. Plan

**Priority order** (from your prompt, adjusted by the findings above):

| Priority | Item |
|---|---|
| Critical | Back up the place (`.rbxl`), run the inventory, scan for backdoors, fix the Quiz remote if the sample code is used |
| High | Stable lobby → quiz → team spawn → combat → score → end → lobby loop. Server-side validation of every remote |
| Medium | Queues (needs Hub/Match place decision), anti-camping, assists, admin panel |
| Low | Lobby art, leaderboards, cosmetics, seasons 2–4 |

**Next small steps:**
1. You: connect Studio MCP on your laptop (or run the inventory by hand) and save a backup `.rbxl`.
2. Claude: fill in section 1 from the real output, and check whether the sample `QuizSystem` is in use.
3. Claude: produce a remote-by-remote validation table (who can call it, which arguments, which checks are missing).
4. Only then: the first code change, which is the smallest fix for the most serious real issue found.

**Testing:** every change is tested in Studio with **Test > Clients and Servers**, using 2–4 local players. Results are reported, and failures are written down.

## 7. Reference images

These are notes on art direction only. Nothing here is canon.

- **Image 1** (a blue-glowing fighter versus a giant sand/stone colossus in ruins) fits the mood of a
  future *Season 3 Titan Raid* boss. **[PROPOSAL — NOT ESTABLISHED CANON]**
- **Image 2** (a stylized horned brute with a fur-trimmed armour and an axe) is a useful silhouette and
  proportion reference for the **Minotaur**. Recolour it to Crimson (#DC143C) to match canon.
- Both images look like art from existing games or artists. Use them **only as inspiration**. Do not upload them as Roblox assets.

## 8. Questions only you can answer

1. **Revives:** Add a downed/revive state (a canon change), or should leaderboard #4 count something
   that already exists? The Rescues/Revives pick needs a revive mechanic to count.
2. **Level/XP:** The Bible has no XP or levels. Add an XP system (a new progression system), or replace
   the "Level" leaderboard with something that exists (e.g. Total Kills from the Bible)?
3. **Ranked:** Add a ranked mode to a game the Master Doc calls "casual"?
4. **Places:** One place with lobby + match, or the documented Hub + separate Season places?
5. **Owner UserId:** Needed before admin tools can be enabled. Find it on your Roblox profile URL. Only the number is needed.
6. Are the Meratai Q10, Crow spelling display, and quest-repeat questions (sections 3.6 and 4) answered somewhere I haven't seen?
