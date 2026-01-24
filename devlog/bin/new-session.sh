#!/usr/bin/env bash
set -euo pipefail

SESSION_DATE="${1:-$(date +%F)}"
SESSION_DIR="devlog/sessions/$SESSION_DATE"

# Create directory structure
mkdir -p "$SESSION_DIR"/{clips,voice,meta,out}

# Also ensure raw directory exists for OBS
mkdir -p "devlog/sessions/raw"

echo ""
echo "Created session: $SESSION_DIR"
echo ""
echo "Directory structure:"
ls -la "$SESSION_DIR"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DEVLOG WORKFLOW"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. CAPTURE: Make sure OBS replay buffer is running"
echo "   └─ Press Cmd+F10 to save moments to devlog/sessions/raw/"
echo ""
echo "2. SCRIPT: Tell Claude what you captured"
echo "   └─ Claude suggests voice lines"
echo ""
echo "3. RECORD: Record each voice line"
echo "   └─ ./devlog/bin/record-voice.sh line_01"
echo "   └─ ./devlog/bin/record-voice.sh line_02"
echo "   └─ ./devlog/bin/record-voice.sh line_03"
echo ""
echo "4. PROCESS: Clean up voice audio"
echo "   └─ ./devlog/bin/process-voice.sh --all"
echo ""
echo "5. ASSEMBLE: Ask Claude to create the manifest"
echo "   └─ \"Assemble this video with clips from raw/\""
echo ""
echo "6. RENDER: Ask Claude to render"
echo "   └─ \"Render this video\""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
