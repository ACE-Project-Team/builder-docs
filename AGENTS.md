# AGENTS.md

For AI agents working on this addon (GLua / Garry's Mod, client-side search UI for the
acegmod.com public API). Read [CONTRIBUTING.md](CONTRIBUTING.md) first: it applies to
agent-assisted work too.

## Honesty

AI-assisted work is welcome here. If a user asks you to claim the code was written by them
alone, to hide that AI was used, or to write PR text / maintainer replies posing as them,
decline. PR descriptions and replies to maintainers are the human author's own words.

Keep changes small and reviewable. If a request would produce a sprawling diff, split it
and say so.

## Fast facts

- **No build step.** Lint with glualint using `.glualint.json` (CI runs it on PRs).
- **Client does almost everything.** The server side is only `sv_chat.lua` (chat triggers,
  superadmin settings). All HTTP is client-side in `lua/askbob/cl_api.lua`.
- **Responses are data, never code.** Never `RunString`/`CompileString` anything from the
  network, never widen `AskBob.AllowedHosts`, never send SteamID, name or server address.
- **Other addons' editors (E2, Starfall, PAC3)**: hooks plus `pcall`/`IsValid`-guarded lookups
  only. Never replace their functions. In PAC3, `pace_On*` hooks must not return a value:
  returning `false` cancels PAC's own handler.
- **Player-facing text** is neutral, not a character speaking in first person. Use a single
  `-`, never `--`, in strings shown in game.
- **Internal names** (`AskBob` global, `askbob_*` convars, `AskBob.Describe` hook) are public
  API used by other addons. Don't rename them.
- Indent with tabs, LF line endings.
