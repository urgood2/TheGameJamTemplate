#!/usr/bin/env python3
"""
Skill Suggestion Hook for Claude Code
Analyzes user prompts and suggests relevant skills/commands based on keywords and patterns.

This hook is triggered on UserPromptSubmit and provides contextual suggestions
aligned with skills and commands referenced in this repository.
"""

import json
import sys
import re

# Skill patterns: keyword triggers and suggestions
SKILL_PATTERNS = {
    "codebase-teacher": {
        "keywords": [
            "how does",
            "where is",
            "explain",
            "understand",
            "walk me through",
            "debug",
            "error",
            "crash",
            "not working",
            "doesn't work",
            "why isn't",
            "bug",
        ],
        "regex": r"(how (does|do|is)|where (is|are)|explain|walk me through|why (isn't|doesn't|won't|can't)|doesn't work|not working|error|crash|bug)",
        "priority": 1,
        "suggestion": "Consider using /codebase-teacher to locate and explain relevant code paths",
    },
    "superpowers:write-plan": {
        "keywords": [
            "write a plan",
            "plan this",
            "break down",
            "step by step",
            "specification",
            "implementation plan",
            "new feature",
            "add a new",
            "outline",
            "approach",
            "roadmap",
            "plan for",
        ],
        "regex": r"(write (a )?plan|implementation plan|break (it|this) down|step[- ]by[- ]step|\bspec(ification)?\b|\boutline\b|\broadmap\b|\bapproach\b|plan for)",
        "priority": 2,
        "suggestion": "Consider using /superpowers:write-plan to turn this into a concrete plan",
    },
    "superpowers:executing-plans": {
        "keywords": [
            "execute plan",
            "execute the plan",
            "follow the plan",
            "implement the plan",
            "task by task",
        ],
        "regex": r"(execute|follow|implement) (the )?plan|task[- ]by[- ]task",
        "priority": 3,
        "suggestion": "If a plan already exists, use /superpowers:executing-plans to implement it step-by-step",
    },
    "demo-mentor": {
        "keywords": [
            "priority",
            "prioritize",
            "what next",
            "what should i",
            "decision",
            "stuck",
            "scope",
            "demo",
        ],
        "regex": r"(what should i|what's next|priorit|stuck|decision|scope|demo|\bship\b)",
        "priority": 4,
        "suggestion": "Consider using /demo-mentor for priority and scope decisions",
    },
    "superpowers:requesting-code-review": {
        "keywords": [
            "code review",
            "pr review",
            "review pr",
            "review this pr",
            "review the pr",
        ],
        "regex": r"\b(code review|pr review|review (this|the)? ?pr)\b",
        "priority": 5,
        "suggestion": "For code/PR reviews, dispatch /superpowers:requesting-code-review to get a review agent",
    },
}

# File pattern associations
FILE_PATTERNS = {
    r"\.(lua|cpp|hpp|h)$": ["codebase-teacher"],  # Code files -> codebase exploration
}


def analyze_prompt(prompt: str) -> list[tuple[str, str, int]]:
    """
    Analyze a prompt and return matching skills with their suggestions.
    Returns list of (skill_name, suggestion, priority) tuples.
    """
    prompt_lower = prompt.lower()
    matches = []

    for skill, config in SKILL_PATTERNS.items():
        score = 0

        # Check keywords
        keyword_matches = sum(1 for kw in config["keywords"] if kw in prompt_lower)
        if keyword_matches > 0:
            score += keyword_matches * 2

        # Check regex patterns
        if config.get("regex"):
            if re.search(config["regex"], prompt_lower):
                score += 3

        # Check file patterns in prompt
        for file_pattern, skills in FILE_PATTERNS.items():
            if re.search(file_pattern, prompt_lower) and skill in skills:
                score += 1

        if score > 0:
            matches.append((skill, config["suggestion"], config["priority"], score))

    # Sort by score (descending) then priority (ascending)
    matches.sort(key=lambda x: (-x[3], x[2]))

    return [(m[0], m[1], m[2]) for m in matches]


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    prompt = input_data.get("prompt", "")
    if not prompt:
        sys.exit(0)

    matches = analyze_prompt(prompt)

    if matches:
        # Take top 2 suggestions maximum
        suggestions = [m[1] for m in matches[:2]]
        feedback = "\n".join(suggestions)

        output = {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "feedback": feedback
            }
        }
        print(json.dumps(output))

    sys.exit(0)


if __name__ == "__main__":
    main()
