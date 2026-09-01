# Customer agent skills

No installer is provided in v1.

1. Clone `rootcause-embassy` and `rootcause-embassy-<language>` next to your app.
2. Add these three lines to the app's `AGENTS.md`:

```md
For ReplyPen embedded chat, read ../rootcause-embassy/skills/embassy-chat/SKILL.md.
For ReplyPen actions, read ../rootcause-embassy/skills/embassy-actions/SKILL.md.
For language code and framework mounting, read ../rootcause-embassy-<language>/README.md.
```

3. Keep both clones on reviewed tagged versions. Do not copy the skill prose into the app; one linked
   source avoids drift.
