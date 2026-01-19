# Firmware.ai API Hang Issue - Error Report

**Date:** 2026-01-18
**Reporter:** joshuashin
**Issue:** API requests hang (stop responding) after a few messages in conversation

---

## Summary

When using Firmware.ai via OpenCode + OhMyOpenCode plugin, API requests intermittently **hang indefinitely** after 2-5 messages in a conversation. This happens "almost every time" per user report. The issue is **not reproducible** on Firmware.ai's end.

---

## Environment Details

### System
| Component | Value |
|-----------|-------|
| **OS** | macOS Darwin 24.4.0 (arm64 - Apple Silicon M1 Pro) |
| **Kernel** | xnu-11417.101.15~117/RELEASE_ARM64_T6000 |
| **Local IP** | 192.168.0.146 |
| **Region** | Asia/Seoul (South Korea) |

### Software Versions
| Software | Version |
|----------|---------|
| **OpenCode** | 1.1.25 |
| **Node.js** | v25.2.1 |
| **npm** | 11.6.2 |
| **Python** | 3.9.12 |

### API Configuration

**Provider Setup (from `opencode.json`):**
```json
{
  "llm-proxy": {
    "npm": "@ai-sdk/openai-compatible",
    "name": "LLM Proxy (Firmware)",
    "options": {
      "baseURL": "http://127.0.0.1:8000/v1",
      "apiKey": "{env:LLM_PROXY_API_KEY}"
    }
  }
}
```

**Agent Configuration (from `oh-my-opencode.json`):**
- Main agent: `llm-proxy/firmware/claude-opus-4-5` (temperature: 0.2)
- Oracle: `llm-proxy/firmware/gpt-5.2` (temperature: 0.1, reasoning_effort: high)
- Explore/Librarian: `llm-proxy/firmware/grok-code-fast-1` (temperature: 0.3)
- Multiple other agents using various Firmware models

### Network Connectivity

**Direct API Test:**
```
firmware.ai connectivity: HTTP 200, time: 2.518018s
```
- DNS resolution successful
- Resolves to AWS ELB: `appserviceloadb-bbnofkeb-753741921.us-east-1.elb.amazonaws.com`
- Multiple IPs: 100.50.206.107, 3.210.131.69

**Local Proxy Status:**
```
http://127.0.0.1:8000/v1/models → {"detail":"Invalid or missing API Key"}
```
- Local proxy IS running and responding
- Requires API key (expected behavior)

---

## Observed Behavior

### Symptom Pattern
1. **First 1-3 messages:** Work normally
2. **After N messages:** Request hangs indefinitely (no response, no timeout, no error)
3. **Consistency:** Happens "almost every time" per user
4. **Recovery:** Requires session restart or request cancellation

### What "Hang" Means
- Request sent to API
- No streaming response received
- No error returned
- No timeout triggered
- Client waits indefinitely

### Logs During Normal Operation
```
INFO  service=llm providerID=llm-proxy modelID=firmware/claude-opus-4-5 sessionID=ses_xxx stream
```
- Logs show request initiated
- No subsequent completion or error logged when hang occurs

---

## Potential Root Causes

### 1. Context Accumulation (MOST LIKELY)
As conversation progresses:
- Total token count increases
- Request payload size grows
- Server may timeout processing large contexts but not return error

**Evidence:** Issue occurs after multiple messages, not on first request.

### 2. Geographic Latency (South Korea → US-East-1)
- User in South Korea
- Firmware.ai AWS servers in us-east-1
- Round-trip latency: ~2.5 seconds baseline
- Long-running requests more susceptible to connection drops

### 3. Streaming Connection Stability
- OpenCode uses streaming (`stream` in logs)
- Long-lived HTTP connections over high-latency routes may drop silently
- No keep-alive or heartbeat visible in logs

### 4. Rate Limiting (Silent)
- Multiple agents making parallel requests
- `explore`, `librarian`, `oracle` agents may hit rate limits
- Silent rate limiting could manifest as hanging

### 5. Request Size Limits
- Models configured with large context limits (200k-1M tokens)
- Actual API may have lower effective limits
- Large tool outputs (file reads, grep results) inflate context quickly

---

## What Firmware.ai Should Investigate

### Server-Side
1. **Request logs for this user** - Look for requests that started but never completed
2. **Context size at hang point** - What's the token count when requests stop responding?
3. **Geographic routing** - Any issues with Asia → US-East traffic?
4. **Rate limiting status** - Is user hitting any limits silently?
5. **Streaming connection health** - Are SSE connections dropping without error?

### Recommended Server-Side Fixes
1. **Add request timeout** - Return error after N seconds instead of hanging
2. **Add streaming heartbeat** - Send periodic keep-alive during processing
3. **Log incomplete requests** - Track requests that never send response
4. **Explicit rate limit errors** - Return 429 instead of silent hang

---

## Client-Side Workarounds Attempted

| Workaround | Status |
|------------|--------|
| Fresh session start | Temporarily helps |
| Different model | Unknown if helps |
| Shorter prompts | Unknown if helps |
| Different network | Not tested |

---

## Reproduction Steps (For Firmware.ai)

1. Use OpenCode 1.1.25 with OhMyOpenCode plugin
2. Configure `llm-proxy` provider pointing to Firmware.ai
3. Use `claude-opus-4-5` model
4. Start conversation with coding task
5. Send 3-5 messages with tool calls (file reads, greps)
6. Observe: Request hangs on subsequent messages

**Key variables:**
- Context grows with each message
- Tool outputs add significant tokens
- Multiple parallel agent calls possible

---

## Data to Provide Firmware.ai

1. **This report** - Full environment details
2. **Approximate timestamp of hangs** - If you note when it happens
3. **Session ID** - From OpenCode logs (e.g., `ses_42fb92561ffe6eAM6BwcjTXkjD`)
4. **Approximate message count before hang** - Usually 3-5 messages

---

## Recommended Next Steps

### For User (joshuashin)
1. **Enable verbose logging** if available
2. **Note timestamps** when hangs occur
3. **Try with timeout** - Add client-side timeout to confirm it's server not responding
4. **Test with curl directly** - Bypass OpenCode to isolate issue:
   ```bash
   curl -v --max-time 120 -X POST https://api.firmware.ai/v1/chat/completions \
     -H "Authorization: Bearer $LLM_PROXY_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"model":"claude-opus-4-5","messages":[{"role":"user","content":"test"}],"stream":true}'
   ```

### For Firmware.ai Support
1. Review server logs for this user's requests
2. Check if any requests show "started but never completed"
3. Investigate streaming connection handling for high-latency clients
4. Consider adding explicit timeouts and error responses

---

## Contact Information

- **User:** joshuashin
- **OpenCode Config Location:** `~/.config/opencode/`
- **Logs Location:** `~/.local/share/opencode/log/`
- **Timezone:** Asia/Seoul (UTC+9)

---

**Report Generated:** 2026-01-18T19:13 KST
