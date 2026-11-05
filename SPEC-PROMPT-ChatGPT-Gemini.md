# Spec prompt for ChatGPT / Gemini

Use this if you prefer to think through your idea in another chatbot first.

1. Talk about your idea in Gemini or ChatGPT for as long as you like.
2. When you finish, paste the whole prompt below into the same chat.
   (No conversation yet? Write your idea inside `<<< >>>`, in any language.)
3. Save the answer in your project folder as `SPEC.md`.
4. In Claude Code, type: `relay-plan SPEC.md`

---

```
Now turn our whole conversation above into ONE clear product spec in English Markdown.
If there is no conversation above, use this idea instead:
<<< write your idea here, in any language >>>

I am not a developer. A senior AI architect (Claude Opus) will read your spec and decide the technical design, so focus on WHAT to build, not HOW.

Rules:
- Use only what we actually agreed in the conversation. If we changed our mind, use the final decision.
- Use exactly the section headings below, in this order.
- Be specific and testable. Use examples with real values (inputs and expected outputs).
- Do not invent features. Put nice-to-haves under "Out of scope".
- Do not choose libraries, frameworks, databases or file structure. In technical sections write "Architect decides" and, at most, one short line of my preferences (for example "Windows", "works offline", "free tools only"). If we discussed a technical idea, list it under "Suggestions for the architect" instead.
- If something important is still unclear, list it under "Open questions". Do not guess.
- Keep the whole spec under 900 words. Output only the spec, nothing before or after it.

# SPEC: <project name>
## Idea (user's own words)
(my idea in 1-3 sentences, in my words)
## Goal
## Users
## Must-haves for this batch
(numbered list; each item has 1-3 acceptance examples: "Given ... when ... then ...")
## Out of scope (not in this batch)
## Platform and stack
Architect decides. My preferences: ...
## Data and storage
(what data exists and what must be saved; Architect decides how)
## Modules and interfaces
Architect decides.
## Full test command
Architect decides.
## Hard limits and security
## Edge cases and errors
(wrong input, empty data, duplicates, limits, what the user should see)
## Suggestions for the architect
(technical ideas from our discussion; the architect may accept or reject them)
## Open questions
## Decisions and answers
(leave empty)
```
