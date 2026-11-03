---
name: review
description: Review a pull request or branch changes. Use with no args to review current branch, a PR number to review that PR, or "security" to do a security-focused review. Examples - "/skill:review", "/skill:review 123", "/skill:review security".
---

# Code Review

Review code changes for correctness, quality, performance, test coverage, and security.

## Determine review mode

Parse the arguments:

- If the argument is `security` or `sec`, jump to **Security Review** below.
- If a PR number is provided, use that PR.
- If no PR number is provided, run `gh pr list` to show open PRs and ask which to review, or review the current branch diff if not on a PR.

## Standard Review

1. Get PR details: `gh pr view <number>` (or `git log --oneline origin/HEAD..` for branch review)
2. Get the diff: `gh pr diff <number>` (or `git diff origin/HEAD...`)
3. Analyze the changes and provide a thorough code review:
   - Overview of what the PR/change does
   - Code correctness — logic errors, edge cases, off-by-ones
   - Project conventions — does the code follow existing patterns
   - Performance implications
   - Test coverage — are changes adequately tested
   - Security considerations — anything obvious

Keep the review concise but thorough. Format with clear sections and bullet points. Flag specific lines where possible.

---

## Security Review

You are a senior security engineer conducting a focused security review of the changes on this branch.

### Step 1: Gather context

Run these commands and include their output in your analysis:

```bash
git status
git diff --name-only origin/HEAD...
git log --no-decorate origin/HEAD...
git diff origin/HEAD...
```

### Step 2: Analyze

**Objective:** Identify HIGH-CONFIDENCE security vulnerabilities with real exploitation potential. Focus ONLY on security implications newly added by this change. Do not comment on existing security concerns.

**Critical instructions:**
1. MINIMIZE FALSE POSITIVES: Only flag issues where you're >80% confident of actual exploitability
2. AVOID NOISE: Skip theoretical issues, style concerns, or low-impact findings
3. FOCUS ON IMPACT: Prioritize vulnerabilities that could lead to unauthorized access, data breaches, or system compromise

**Do NOT report:**
- Denial of Service (DOS) vulnerabilities
- Secrets or sensitive data stored on disk (handled by other processes)
- Rate limiting or resource exhaustion issues

**Categories to examine:**

**Input Validation:**
- SQL injection, command injection, XXE, template injection, NoSQL injection, path traversal

**Authentication & Authorization:**
- Auth bypass, privilege escalation, session flaws, JWT vulnerabilities, authz logic bypasses

**Crypto & Secrets:**
- Hardcoded credentials, weak crypto, improper key storage, randomness issues, cert validation bypasses

**Injection & Code Execution:**
- RCE via deserialization, pickle/YAML injection, eval injection, XSS (reflected, stored, DOM-based)

**Data Exposure:**
- Sensitive data logging, PII handling violations, API data leakage, debug info exposure

### Step 3: Validate findings

Use the `subagent` tool to launch parallel validation tasks — one per finding. Each subagent should independently assess whether the finding is a true positive, applying these filters:

**Hard exclusions — automatically drop:**
1. DOS/resource exhaustion
2. Secrets on disk if otherwise secured
3. Rate limiting concerns
4. Memory/CPU exhaustion
5. Input validation on non-security-critical fields without proven impact
6. GitHub Action workflow sanitization unless clearly triggerable via untrusted input
7. Lack of hardening measures (only flag concrete vulnerabilities, not missing best practices)
8. Theoretical race conditions or timing attacks
9. Outdated third-party library vulnerabilities
10. Memory safety issues in memory-safe languages (Rust, Go, etc.)
11. Files that are only unit tests
12. Log spoofing (unsanitized user input in logs is not a vulnerability)
13. SSRF that only controls the path (not host/protocol)
14. User content in AI prompts
15. Regex injection or regex DOS
16. Documentation files
17. Missing audit logs

**Precedents:**
- Logging high-value secrets is a vuln; logging URLs is safe
- UUIDs are unguessable, don't need validation
- Environment variables and CLI flags are trusted values
- Resource management issues (leaks) are not valid
- React/Angular are generally XSS-safe unless using `dangerouslySetInnerHTML` / `bypassSecurityTrustHtml`
- Client-side JS/TS missing permission checks is not a vuln (server handles it)
- Most ipython notebook vulns are not exploitable in practice
- Logging non-PII data is not a vuln
- Command injection in shell scripts is generally not exploitable unless there's a concrete untrusted-input path

Each subagent should assign a confidence score (1-10). Drop any finding with confidence < 8.

### Step 4: Report

Output format for each finding:

```markdown
# Vuln N: <Category>: `file.py:line`

* Severity: High|Medium
* Confidence: N/10
* Description: <what the vulnerability is>
* Exploit Scenario: <concrete attack path>
* Recommendation: <how to fix>
```

**Severity guidelines:**
- **HIGH**: Directly exploitable — RCE, data breach, auth bypass
- **MEDIUM**: Requires specific conditions but significant impact

Only include MEDIUM findings if they are obvious and concrete. If no vulnerabilities are found, say so clearly.
