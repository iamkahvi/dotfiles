---
name: tldr
description: Summarize an incident Slack channel by reading messages and proposing 3 one-line summaries focused on current status. Uses slack-mcp and incident-dashboard-mcp. Automatically detects channel from context if not provided.
---

# TL;DR - Incident Channel Summarizer

Generate concise one-line summaries of incident Slack channels to quickly communicate the current situation.

## When to Use

- When you need a quick summary of an incident channel
- When preparing status updates for stakeholders
- When catching up on an ongoing incident
- When the user mentions "tldr", "summary", or "incident status"

## Required Information

- **Channel name**: The incident Slack channel (e.g., `#inc-12345-some-issue`)
  - If not provided, infer from the current context (e.g., a Slack URL or recent conversation)

## Instructions

### Step 1: Identify the Channel

1. If a channel name is provided, use it directly
2. If not provided, look for:
   - Slack URLs in the conversation context
   - Recently mentioned incident channel names
   - Any `#inc-*` or `#inv-*` pattern in the context
3. Ask the user if no channel can be inferred

### Step 2: Fetch Channel Messages

Use the `slack-mcp` tools to retrieve channel messages:

```
mcp_slack-mcp_get_messages with action: "channel"
```

- Fetch enough messages to understand the full incident timeline
- Note the channel ID from the channel name

### Step 3: Check for Previous TL;DR

Look for messages from **"Incident Bot"** containing "tldr" or "TL;DR" in the channel:

- If found, note the timestamp of the most recent one
- Focus the summary on events **after** that timestamp (the delta)
- If no previous tldr exists, summarize the entire incident

### Step 4: Gather Additional Context (Optional)

If an incident ID is mentioned or can be extracted from the channel name:

- Use `mcp_incident-dashboard-mcp_get_incident` to fetch incident details
- Cross-reference with Slack messages for accuracy

### Step 5: Generate Summaries

Produce **3 alternative one-line summaries** that:

1. **Focus on current status** - What is happening RIGHT NOW
2. **Are actionable** - Help readers understand what they need to know
3. **Are concise** - Keep each summary to one sentence (under 150 characters ideal)

#### Summary Guidelines

- **Do NOT start summaries with incident status** (e.g., "Mitigated;", "Resolved;", "Active;") - jump straight into the content
- **Do NOT mention action items** - focus on the incident itself, not follow-up tasks
- Use semicolons (`;`) to separate clauses within a summary
- Include the affected system/service if known
- Mention impact scope if significant
- If focusing on delta, highlight what changed since last tldr

#### Output Format

Present the 3 summaries clearly:

```
## TL;DR Options

1. [Summary focusing on technical status]
2. [Summary focusing on impact/user perspective]  
3. [Summary focusing on next steps/actions]
```

If this is a delta summary, indicate:

```
## TL;DR (Updates since [timestamp])

1. ...
2. ...
3. ...
```

## Example

**Input**: "tldr for #inc-98765-checkout-errors"

**Process**:
1. Fetch messages from #inc-98765-checkout-errors
2. Find last Incident Bot tldr at 2:30 PM
3. Read messages after 2:30 PM
4. Generate summaries based on new developments

**Output**:
```
## TL;DR (Updates since 2:30 PM)

1. Checkout errors resolved after deploying hotfix v2.3.1; monitoring for recurrence.
2. All merchants can now process checkouts normally; no further action required.
3. Root cause identified as cache invalidation bug in order processing service.
```

## Notes

- Always read the FULL conversation to avoid missing context
- Pay attention to thread replies which may contain important updates
- If the incident is still active, emphasize what's being done NOW
- Use incident-dashboard-mcp to verify incident state if uncertain
