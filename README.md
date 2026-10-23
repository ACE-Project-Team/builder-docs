# Ask Bob

In-game help for Garry's Mod, backed by the [ACE](https://acegmod.com) wiki, organization wikis and docs, plus any installed [Ponder](https://github.com/ACF-Team/Ponder) tutorials.

## Where to find Bob
- **Spawnmenu tab:** "Ask Bob".
- **Chat:** `!bob <question>` or `!ask <question>`. Server admins can change these, and Bob skips any trigger that ULX already uses.
- **C menu:** right-click an entity, then "Ask Bob about this".
- **"What is this?" key:** set it in Q menu → Options → Utilities → Ask Bob.
- **E2 and Starfall editors:** an "Ask Bob" button in the toolbar. It searches your selection, the word under the caret, or the last error.
- **Console:** `askbob [question]`, `askbob_whatisthis`.

## Convars
| Convar | Realm | Default | |
|---|---|---|---|
| `askbob_scope` | server (replicated) | empty | default filters, e.g. `ace,sf` |
| `askbob_chat_triggers` | server (replicated) | `!bob,!ask` | chat commands |
| `askbob_api_url` | client | `https://acegmod.com` | only acegmod.com or localhost are accepted |
| `askbob_ponder` | client | `1` | include Ponder tutorials |
| `askbob_key` | client | `0` | "what is this?" key |

## Privacy
Bob sends only your question to acegmod.com. No SteamID, name or server address is sent. The site stores questions without who asked them. Responses are shown as text and never run as code.

## For addon developers
When a player asks Bob about one of your entities (C menu "Ask Bob about this", or the "What is this?" key), Bob builds a *chip* for it. Fill it in from your own addon with the `AskBob.Describe` hook. Bob doesn't need to be installed: without it the hook never runs.

```lua
-- client side
hook.Add("AskBob.Describe", "MyAddon", function(ent, chip)
	if chip.class ~= "myaddon_engine" then return end
	chip.name = ent:GetNWString("EngineName")   -- shown on the chip and the card
	chip.query = ent:GetNWString("EngineName")  -- what Bob searches for
	chip.scope = "myorg"                        -- your org's slug: search your wiki first
	chip.description = "A small petrol engine." -- optional, shown on the card
	chip.facts[#chip.facts + 1] = { "Power", ent:GetNWInt("kW") .. " kW" }
	chip.facts[#chip.facts + 1] = { "Torque", ent:GetNWInt("Nm") .. " Nm" }
end)
```

- `chip.class` is already set. `chip.name` starts as the entity's PrintName.
- `facts` and `description` appear as a card above Bob's results. They stay in the game and are never sent to the website, so show as many stats as players need.
- Only `query` and `scope` are sent with the search.
- Return `false` to stop Bob from offering a chip for that entity.

[`lua/askbob/plugins/ace.lua`](lua/askbob/plugins/ace.lua) is the built-in plugin for ACE. It uses only this hook, so it's a working example.

## Development
Symlink this folder into `garrysmod/addons/askbob`, set `askbob_api_url http://localhost:3000`, and run the ACE website dev server.
