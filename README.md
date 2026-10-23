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

## Development
Symlink this folder into `garrysmod/addons/askbob`, set `askbob_api_url http://localhost:3000`, and run the ACE website dev server.
