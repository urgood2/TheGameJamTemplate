#!/usr/bin/env python3
"""Convert Claude Code JSONL transcript to readable Markdown."""

import json
import sys
import re
from datetime import datetime

def format_tool_input(tool_name, tool_input):
    """Format tool input for display."""
    if tool_name == "Read":
        return f"({tool_input.get('file_path', '')})"
    elif tool_name == "Write":
        return f"({tool_input.get('file_path', '')})"
    elif tool_name == "Edit":
        return f"({tool_input.get('file_path', '')})"
    elif tool_name == "Bash":
        cmd = tool_input.get('command', '')
        if len(cmd) > 80:
            cmd = cmd[:80] + "..."
        return f"({cmd})"
    elif tool_name == "WebFetch":
        return f"({tool_input.get('url', '')})"
    elif tool_name == "WebSearch":
        return f"({tool_input.get('query', '')})"
    elif tool_name == "Grep":
        return f"({tool_input.get('pattern', '')})"
    elif tool_name == "Glob":
        return f"({tool_input.get('pattern', '')})"
    elif tool_name == "Task":
        return f"({tool_input.get('description', '')})"
    else:
        return ""

def get_fence(content):
    """Get a code fence that won't conflict with content."""
    # Use tildes if content has backticks, otherwise use backticks
    if '```' in content:
        fence = "~~~"
        while fence in content:
            fence += "~"
        return fence
    else:
        return "```"

def html_escape(text):
    """Escape HTML special characters."""
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

def format_tool_result(result, max_lines=30):
    """Format tool result, truncating if needed."""
    if isinstance(result, list):
        result = json.dumps(result, indent=2)
    elif not isinstance(result, str):
        result = str(result)

    # Clean up system reminders
    if '<system-reminder>' in result:
        result = result[:result.find('<system-reminder>')].strip()

    lines = result.split('\n')
    if len(lines) > max_lines:
        result = '\n'.join(lines[:max_lines]) + f"\n... [{len(lines) - max_lines} more lines]"

    return result

def is_system_message(content):
    """Check if a user message is actually internal system output."""
    system_patterns = [
        r'^Caveat:',
        r'<command-name>',
        r'<local-command-stdout>',
        r'<command-message>',
        r'<command-args>',
    ]
    for pattern in system_patterns:
        if re.search(pattern, content):
            return True
    return False

def filter_rewound_messages(messages):
    """Filter out rewound messages by resolving branch points.

    When a user rewinds, multiple messages can share the same parentUuid.
    At each such branch point, we keep only the branch containing the
    last message in file order (the "winning" branch). This handles:
    - Rewinds within a chain (orphaned branches get filtered)
    - Continuations (disconnected chains from --continue are preserved)
    """
    if not messages:
        return messages

    # Build uuid -> message map with file index for ordering
    uuid_map = {}
    uuid_to_index = {}
    for i, msg in enumerate(messages):
        uuid = msg.get('uuid')
        if uuid:
            uuid_map[uuid] = msg
            uuid_to_index[uuid] = i

    # Find branch points: parents with multiple children
    from collections import defaultdict
    children_of = defaultdict(list)
    for msg in messages:
        parent_uuid = msg.get('parentUuid')
        uuid = msg.get('uuid')
        if parent_uuid and uuid:
            children_of[parent_uuid].append(uuid)

    # For each branch point, find which child leads to the latest message
    # Build set of "losing" branches (to be filtered out)
    orphaned = set()

    def get_latest_descendant_index(uuid):
        """Get the highest file index reachable from this uuid."""
        visited = set()
        max_index = uuid_to_index.get(uuid, -1)
        stack = [uuid]
        while stack:
            current = stack.pop()
            if current in visited:
                continue
            visited.add(current)
            idx = uuid_to_index.get(current, -1)
            if idx > max_index:
                max_index = idx
            # Add all children
            for child in children_of.get(current, []):
                stack.append(child)
        return max_index

    def mark_orphaned(uuid):
        """Mark this uuid and all descendants as orphaned."""
        stack = [uuid]
        while stack:
            current = stack.pop()
            if current in orphaned:
                continue
            orphaned.add(current)
            for child in children_of.get(current, []):
                stack.append(child)

    for parent_uuid, children in children_of.items():
        if len(children) > 1:
            # Branch point - find which child leads to the latest message
            best_child = None
            best_index = -1
            for child in children:
                latest = get_latest_descendant_index(child)
                if latest > best_index:
                    best_index = latest
                    best_child = child
            # Mark all other children as orphaned
            for child in children:
                if child != best_child:
                    mark_orphaned(child)

    # Filter messages: keep those not orphaned OR without uuid (system messages)
    filtered = []
    for msg in messages:
        uuid = msg.get('uuid')
        if uuid is None or uuid not in orphaned:
            filtered.append(msg)

    return filtered

def convert_jsonl_to_markdown(jsonl_path, output_path=None):
    """Convert JSONL transcript to Markdown."""

    messages = []
    with open(jsonl_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
                messages.append(msg)
            except json.JSONDecodeError:
                continue

    # Filter out rewound messages
    messages = filter_rewound_messages(messages)

    # Extract session start time
    start_time = None
    for msg in messages:
        if msg.get('timestamp') and not start_time:
            start_time = msg['timestamp']
            break

    # Format header
    if start_time:
        dt = datetime.fromisoformat(start_time.replace('Z', '+00:00'))
        header = f"# Session {dt.strftime('%Y-%m-%d %H:%M')}\n\n---\n\n"
    else:
        header = "# Session\n\n---\n\n"

    output = header
    pending_tools = {}  # tool_id -> (tool_name, formatted_input)

    for msg in messages:
        msg_type = msg.get('type')
        content = msg.get('message', {}).get('content')

        if not content:
            continue

        # User message (plain text)
        if msg_type == 'user' and isinstance(content, str):
            # Check if it's internal system output
            if is_system_message(content):
                fence = get_fence(content)
                output += f"{fence}\n{content}\n{fence}\n\n"
            # Check if it's HTML content (pasted HTML)
            elif content.strip().startswith('<') and re.search(r'<(p|div|details|pre|blockquote|h[1-6]|ul|ol|table)\b', content):
                # Put HTML content in a collapsible details block
                escaped = html_escape(content)
                output += f"<details>\n<summary><code>[Pasted HTML content]</code></summary>\n\n"
                output += f"<pre><code>{escaped}</code></pre>\n\n"
                output += "</details>\n\n"
            else:
                # Prefix every line with > for proper blockquote
                lines = content.split('\n')
                quoted = '\n'.join(f"> {line}" for line in lines)
                output += f"{quoted}\n\n"

        # User message (tool results)
        elif msg_type == 'user' and isinstance(content, list):
            for item in content:
                if item.get('type') == 'tool_result':
                    tool_id = item.get('tool_use_id')
                    result = item.get('content', '')

                    # Get the pending tool info
                    tool_info = pending_tools.pop(tool_id, None)

                    if tool_info:
                        tool_name, formatted_input = tool_info
                        result_text = format_tool_result(result)

                        if result_text:
                            # Use HTML pre/code since markdown isn't processed inside HTML blocks
                            escaped = html_escape(result_text)
                            output += f"<details>\n<summary><code>{tool_name} {formatted_input}</code></summary>\n\n"
                            output += f"<pre><code>{escaped}</code></pre>\n\n"
                            output += "</details>\n\n"
                        else:
                            # No result, just show command in blockquoted code block
                            output += f"> `{tool_name} {formatted_input}`\n\n"

        # Assistant message
        elif msg_type == 'assistant' and isinstance(content, list):
            for item in content:
                item_type = item.get('type')

                if item_type == 'text':
                    text = item.get('text', '')
                    if text:
                        output += f"{text}\n\n"

                elif item_type == 'tool_use':
                    tool_name = item.get('name', 'Unknown')
                    tool_input = item.get('input', {})
                    tool_id = item.get('id')

                    formatted_input = format_tool_input(tool_name, tool_input)

                    # Store for matching with result
                    if tool_id:
                        pending_tools[tool_id] = (tool_name, formatted_input)

    if output_path:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(output)
        print(f"Written to {output_path}")
    else:
        print(output)

    return output

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: jsonl-to-markdown.py <input.jsonl> [output.md]")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None

    convert_jsonl_to_markdown(input_path, output_path)
