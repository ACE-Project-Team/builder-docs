# Builder Docs (aka Ask Bob)

In-game search for Garry's Mod builders. It searches the [ACE](https://acegmod.com) wiki, partner
wikis (Wiremod, Starfall, PAC3 and more) and their docs, plus any installed
[Ponder](https://github.com/ACF-Team/Ponder) tutorials, and shows the pages without leaving the game.

Every result is a page from years of knowledge collected and written by players. Nothing is
generated unless you press the optional **AI** button. [How the search works](#how-the-search-works-on-the-website) explains exactly what the
website does with your question.

## Where to find it
- **Spawnmenu tab** in the Q menu.
- **Chat:** `!docs`, `!ask` or `!search`, then your question. `!bob` also works. Server admins can
  change these, and any trigger that ULX already uses is skipped.
- **C menu:** right-click an entity, then "Look this up".
- **"What is this?" key:** set it in Q menu → Options → Utilities.
- **E2 and Starfall editors:** a "Search docs" button in the toolbar. It offers your selection, the
  word under the caret, or the last error; with none of those it opens on the Wiremod or Starfall
  filter. It's for how-to questions; E2Helper and SFHelper are quicker for what one function does.
- **PAC3 editor:** a "docs" menu in the editor's menu bar. It offers the selected part's type (and
  the event type for event parts), searching the PAC3 wiki. PAC3's own part help (F1) is quicker for
  what one setting does.
- **Console:** `askbob [question]`, `askbob_whatisthis`, `askbob_status`.

## Filters and AI answers
The buttons under the search box come from the website, so they match what the site holds: ACE,
Starfall, Wiremod, PAC3 and other libraries, plus "Other" for the remaining org wikis. Each library
button covers its docs and its partner org's wiki.

When the chosen filter's org has AI answers turned on, an **AI** button appears. It asks for a
written answer about that project instead of a list of pages, and the answer is labelled as
AI-generated. Typing `+ai` in the box does the same.

## Convars
| Convar | Realm | Default | |
|---|---|---|---|
| `askbob_scope` | server (replicated) | empty | default filters, e.g. `ace,sf` |
| `askbob_chat_triggers` | server (replicated) | `!docs,!ask,!search,!bob` | chat commands; the first three are shown to players |
| `askbob_api_url` | client | `https://acegmod.com` | only acegmod.com or localhost are accepted |
| `askbob_ponder` | client | `1` | include Ponder tutorials |
| `askbob_key` | client | `0` | "what is this?" key |

## How the search works on the website
The website's code isn't public (see [below](#whats-open-and-what-isnt)), so here is what happens to
a question, step by step:

1. **Rate limit.** Each IP gets a limited number of searches per minute (see [Privacy](#privacy-and-security)
   for how). Requests are plain GET with no login.
2. **Small talk.** "hi", "thanks", "help" and similar get a fixed reply from a short list, the same
   one the ACE Discord bot uses. Nothing is searched.
3. **Keyword search.** Postgres full-text search plus fuzzy matching (so typos still match), over
   published wiki pages, articles, docs, builds and site pages. Forum posts, tasks and user profiles
   are never searched from the game.
4. **Meaning match (only with no filter picked).** A small embedding model,
   [all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2),
   turns your question into a list of 384 numbers that describes its meaning. Every page, and every
   section of a page, was turned into the same kind of list when it was saved. Pages whose lists
   are close to your question's are found even when they share no words with it, e.g. "make my
   tank steer" finds the gearbox page. The model only measures how similar two pieces of text are.
   It can't write text and never does. It runs on the ACE server itself, with no external API.
   When you pick a filter (the editor buttons do this for you), this step is skipped and results
   are keyword-only.
5. **Quick answer.** If the top page has a section that directly answers the question, that section
   is cut out and shown as the "Answer" card, word for word, with a link to the page.
6. **GMod wiki (only with the GMod wiki filter).** The question is also sent from the website to
   [CFC's gmodwiki search](https://github.com/CFC-Servers/gmodwiki) (`mcp.gmodwiki.com`). The editor
   buttons pick this filter automatically for GMod API names like `ents.Create`.
7. **Log.** The question text is saved with the result count, the top result's link and how long
   the search took. No IP, SteamID or name is saved with it. The ACE team uses this list to see
   which questions have no page yet, so they get written.

Results are cached briefly, so the same question asked twice in a row may not reach the search
again.

**The AI button** is separate and only runs when you press it. The website passes your question to
[DeepWiki](https://deepwiki.com), a third-party service, which writes an answer from that project's
public GitHub repo. It has much tighter per-minute and per-day limits than search, repeated
questions are answered from a cache, and each answer is labelled as AI-generated with a link to its source. Your game never
contacts DeepWiki directly. Each org decides whether its filter offers AI at all.

## Privacy and security
**What's sent:** your question and the filter you picked, to acegmod.com only. With an entity chip,
its name and class are sent too; its stats stay in the game. No SteamID, name or server address is
sent. Like any web request, the site sees your IP. It is never stored with your question. The
rate limiter keeps a separate per-IP counter for each time window (IP, endpoint, window, count),
and going over a limit is logged with the IP as a security event, to spot abuse.

**What comes back:** JSON only. Search results, article text and AI answers are shown as plain text
and never compiled or run. Bodies over 512 KB are refused. Links open through Steam's "leaving the
game" prompt, and only `http(s)` links are opened.

**Where it can connect:** the client only talks to the hosts in `AskBob.AllowedHosts`
([`sh_config.lua`](lua/askbob/sh_config.lua)): acegmod.com, plus localhost for development. Like any
GMod addon, a server you join can send its own clientside Lua, so this list protects against a bad
convar value, not against a server that replaces the addon.

### What's open and what isn't
This repository is the whole addon: everything that runs in your game. The acegmod.com website and
its search engine are **not** open source. The addon only uses these public, unauthenticated GET
endpoints, all in [`cl_api.lua`](lua/askbob/cl_api.lua), so you can check the traffic yourself:

| Endpoint | Parameters | Returns |
|---|---|---|
| `/api/public/search` | `q`, `scope` | `{ query, quickAnswer, results[], hint, scope, reply }` |
| `/api/public/search-scopes` | none | `{ filters[], orgs[] }`: the filter buttons |
| `/api/public/ask` | `q`, `scope` | `{ answer, answerer, repo, label, sourceUrl, aiGenerated }`, only when you press AI |
| `/api/public/wiki/articles/<slug>` | none | `{ title, body, organization, category, author, truncated }` |

Besides the headers GMod's `HTTP()` always sends, requests carry only an `X-AskBob-Version` header.

## For addon developers
When a player looks up one of your entities (C menu "Look this up", or the "What is this?" key), the
addon builds a *chip* for it. Fill it in from your own addon with the `AskBob.Describe` hook. This
addon doesn't need to be installed: without it the hook never runs.

```lua
-- client side
hook.Add("AskBob.Describe", "MyAddon", function(ent, chip)
	if chip.class ~= "myaddon_engine" then return end
	chip.name = ent:GetNWString("EngineName")   -- shown on the chip and the card
	chip.query = ent:GetNWString("EngineName")  -- what gets searched
	chip.scope = "myorg"                        -- your org's slug: search your wiki first
	chip.description = "A small petrol engine." -- optional, shown on the card
	chip.facts[#chip.facts + 1] = { "Power", ent:GetNWInt("kW") .. " kW" }
	chip.facts[#chip.facts + 1] = { "Torque", ent:GetNWInt("Nm") .. " Nm" }
end)
```

- `chip.class` is already set. `chip.name` starts as the entity's PrintName.
- `facts` and `description` appear as a card above the results. They stay in the game and are never
  sent to the website, so show as many stats as players need.
- Only `query` and `scope` are sent with the search.
- Return `false` to stop the addon from offering a chip for that entity.

[`lua/askbob/plugins/ace.lua`](lua/askbob/plugins/ace.lua) is the built-in plugin for ACE. It uses
only this hook, so it's a working example.

## Contributing
Clone or symlink this folder into `garrysmod/addons/` and start the game: it uses the live
acegmod.com API, so nothing else needs to run. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
workflow, code style and our stance on AI-assisted contributions (welcome, if reviewable).

## License
[MIT](LICENSE.md)
