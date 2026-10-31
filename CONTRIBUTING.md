# Contributing

This addon is small and maintained by volunteers from the ACE team, so keep pull requests easy to review.

- Discord: https://discord.gg/Y8aEYU6 (talk to us before starting anything big)
- Issues: https://github.com/ACE-Project-Team/askbob/issues

## Workflow

- Branch off `master` and open PRs against `master`.
- One change, or a closely related set, per PR.
- Say what changed, why, and how you tested it in game, in your own words.
- New editor integrations (like the E2, Starfall and PAC3 ones) must only use hooks and
  guarded lookups. Never overwrite another addon's functions: if their internals change, the
  button should fall back to "open search with the right filter", not error in their editor.

## Running it locally

1. Clone this repo into `garrysmod/addons/` (or symlink it there).
2. Start GMod. The addon talks to the live https://acegmod.com public API by default, so you
   don't need anything else running.
3. `askbob_status` in the console shows which site the client is using.

ACE team members working on the website can point the client at a local dev server with
`askbob_api_url localhost:3000`. Only acegmod.com and localhost are accepted.

## Code style

Follow the [ACE style guide](https://acegmod.com/wiki/general-coding-and-style-guidelines) and
the [CFC GLua guidelines](https://github.com/CFC-Servers/cfc_glua_style_guidelines). Lint rules
live in [`.glualint.json`](.glualint.json) and CI runs them on every PR. Tabs for indentation,
LF line endings, no unrelated whitespace changes.

Player-facing text is neutral and short: describe what happens ("Searching...", "No results"),
don't write it as a character talking.

## AI-assisted contributions

AI-assisted development is welcome. We care about the result and the effort behind it, not
which editor you typed it in. What we ask:

- **It has to be reviewable.** Small, focused PRs that a human can read in one sitting.
  "Rewrite everything" PRs get closed, however they were made.
- **Show the effort.** You understand the change, tested it in game, and can explain and
  defend every line. "Fix everything, make no mistakes" pasted into a chatbot and submitted
  as-is isn't a contribution.
- **Be open about it.** Say if AI tools helped. Nobody gets judged for using them.
- **Talk to us yourself.** PR descriptions and replies to review are your own words.
  Maintainers want to talk to you, not to your toolchain.
- **Fix review comments properly**, rather than re-running the tool and resubmitting.

If you work with a coding agent, point it at [`AGENTS.md`](AGENTS.md).
