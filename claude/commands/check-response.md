---
description: Ask Haiku whether the last assistant response should have included a URL
---

Run `/code/llm-settings/claude/scripts/check-response.bb` and show the verdict verbatim. The script auto-detects the current session transcript, extracts the last assistant text message, and asks Haiku (`claude-haiku-4-5-20251001`) to judge whether the response claims a remote artifact that should have been linked. Output is a single line: `OK — …` or `MISSING — …`.

Requires `ANTHROPIC_API_KEY` in the environment. If unset, the script exits with an error and no API call is made.
