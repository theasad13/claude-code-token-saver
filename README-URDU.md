# Relay Kit: Urdu guide (Roman Urdu)

[English README](README.md)

Claude (Opus) plan aur review karta hai. Kaam ek **worker** karta hai:
- **Sonnet mode (automatic):** Claude khud Sonnet subagent se kaam karwata hai. Aapko copy-paste nahi karna.
- **Codex mode (automatic):** Claude khud Codex CLI se kaam karwata hai (safe sandbox mein), phir khud check aur commit karta hai.
- **Qwen mode (manual):** aap Qwen Code (ya Kimi Code) khud khol kar ek message dete hain.

---

## 1. Naye PC par zaroori cheezein

PowerShell mein check karein (har command ke baad version aana chahiye):
```
git --version
node --version
claude --version
```
- Git na ho: git-scm.com se install karein.
- Node na ho: nodejs.org se LTS install karein.
- Claude Code na ho: `npm install -g @anthropic-ai/claude-code`, phir `claude` chala kar login karein.
- Python projects ke liye: `python --version` (na ho to python.org).
- Codex mode chahiye to: `npm install -g @openai/codex`, phir `codex login` (ChatGPT account se).
- Qwen mode chahiye to: `npm install -g @qwen-code/qwen-code@latest`, phir `qwen` mein `/auth` se Token Plan key lagayein.

## 2. Kit install (sirf ek baar)

1. Is repo ko download karein: GitHub par **Code → Download ZIP**, phir extract karein. Ya: `git clone https://github.com/theasad13/claude-code-relay-kit.git`
2. PowerShell mein, us folder ke andar:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File .\INSTALL.ps1
   ```
3. Claude Code band karke dobara kholein. Check karein: `/skills` mein relay-init, relay-plan, relay-run, relay-review, aur `/agents` mein relay-worker nazar aaye.

Installer kuch delete nahi karta. Pehle se maujood file badalni ho to uska backup `~/.claude/backups/relay-kit-<time>/` mein bana deta hai.

## 3. Har naye project ke liye

```
mkdir C:\dev\mera-project
cd C:\dev\mera-project
git init
claude
```
Claude mein:

| Step | Likhein |
|---|---|
| 1 | `relay-init` |
| 2 | `relay-plan <apna idea>` ya `relay-plan SPEC.md` |
| 3a Sonnet mode | `relay-run` → Claude Sonnet se saare tasks karwa ke khud review karega |
| 3c Codex mode | `relay-run codex` → Codex saare tasks karta aur commit karta hai (risky cheezein Auto-review se), Claude check aur review karta hai. Sakht mode: `relay-run codex strict` |
| 3b Qwen mode | Naye terminal mein `qwen` → `Do all pending tasks in relay/STATUS.md` → wapas Claude mein `review` |
| 4 | Sab theek ho to Claude poochega "merge karun?" → aap haan/na |

`/clear` kab: `relay-plan` ke baad (relay-run se pehle), aur batch merge hone ke baad. Claude khud yaad dilayega.

Spec ChatGPT/Gemini se banwani ho to `SPEC-PROMPT-ChatGPT-Gemini.md` wala prompt use karein. Woh sirf "kya banana hai" likhta hai; "kaise banana hai" Opus khud decide karta hai.

## 4. Sonnet mode ke baare mein

- Worker ka model `~/.claude/agents/relay-worker.md` mein `model: sonnet` hai. Iska matlab hai latest Sonnet.
- Koi purana Sonnet pin karna ho to wahan poora model ID likh dein (jaise `claude-sonnet-4-5`). Pehle `/model` mein dekh lein ke aapke plan mein woh available hai.
- Sonnet ka kaam bhi **aapke Claude plan ke usage** se katta hai, lekin Opus se kam.
- Claude Code commands (tests, git commit) ke liye permission maangega. Bar bar na poochhe, is liye "Yes, don't ask again" choose kar sakte hain, sirf in commands ke liye: `relay/verify.ps1`, `git add`, `git commit`, `git status`, `git restore`, aur project ka test command.

## 4a. Codex mode ke baare mein

- Claude Codex ko sirf `~/.claude/relay-kit/codex-worker.ps1` ke zariye chalata hai, ek waqt mein ek task.
- **Auto mode (default, `relay-run codex`)**: bilkul waise jaise interactive Codex mein "sirf risky ho to poocho".
  - Codex sandbox mein kaam karta hai. Jab use zyada chahiye (git commit, internet, web search), woh ijazat maangta hai, aur **Codex Auto-review** (ek automatic reviewer) faisla karta hai: kam/darmiyana risk = ijazat, critical risk = mana.
  - Codex ko prompt mein saaf policy di jaati hai: sirf apne task ki files ka commit aur internet se padhna. Folder se bahar likhna/delete, packages install, `git push` mana hai. Aisa kaam chahiye to task BLOCKED.
  - Codex task ka commit khud karta hai (Sonnet ki tarah). Claude phir har commit check karta hai.
- **Strict mode (`relay-run codex strict`)**: internet band, koi ijazat nahi, Codex commit nahi kar sakta. Claude check kar ke commit karta hai. Bahut sensitive project ke liye.
- Dono modes mein aakhri hifazat same hai: `verify.ps1` (sirf allowed files + tests) aur Claude ka review.
- Codex ka kaam aapke **ChatGPT plan** ki usage se katta hai (Claude plan se nahi).
- Har task ka Codex log: project ke andar `.git/relay-logs/` (commit nahi hota).
- Installer khud `~/.claude/settings.json` mein **sirf** Codex worker command ki permission add kar deta hai, is liye Claude Code har task par nahi poochta. Baqi har command par pehle ki tarah poochega. (Purani settings ka backup `~/.claude/backups/` mein.)

## 4b. Kaunsa model kya karta hai
- `relay-plan`, `relay-review`, `relay-run`: **Opus** (skill khud Opus par switch karti hai, chahe aapka `/model` kuch bhi ho).
- `relay-worker` (task ka code): **Sonnet**.
- `relay-run codex` (task ka code): **Codex** (model aapke `~/.codex/config.toml` wala).
- Agar aapke plan mein Opus nahi, ya Opus ki limit khatam ho gayi, to skill aapke current model par chalegi. `/status` se dekh sakte hain.

## 5. Kuch bigar jaye

- Claude se kahein: **"last batch wapas le lo"**. Har batch alag branch (`relay/<naam>`) par hota hai, main branch safe rehti hai.
- Ek task bar bar fail ho: Claude review mein bata dega. Aksar task ka description behtar karna hota hai.
- `verify.ps1` "Files changed outside targets" bole: worker ne ghalat file chhui. Review mein Claude usko revert karega.

## Kit mein kya hai

```
INSTALL.ps1                         installer
claude/agents/relay-worker.md       Sonnet worker subagent
claude/relay-kit/codex-worker.ps1   Codex worker (safe settings, ek task)
claude/relay-kit/VERSION            kit ka version
claude/skills/relay-init|plan|run|review/SKILL.md
claude/relay-kit/relay-init.ps1     project mein kit copy karta hai
claude/relay-kit/templates/SPEC.md
claude/relay-kit/templates/project/ har project mein jaane wali files:
    QWEN.md, AGENTS.md              worker ko WORKER.md parhne ka kehte hain
    relay/WORKER.md                 worker ke rules
    relay/STATUS.md                 tasks ki list
    relay/verify.ps1                tests + allowed-files check (koi AI call nahi)
    relay/tasks/_TEMPLATE.md, relay/reports/_TEMPLATE.md, relay/feedback/
claude/CLAUDE-relay-section.md      ~/.claude/CLAUDE.md mein add hota hai
```
