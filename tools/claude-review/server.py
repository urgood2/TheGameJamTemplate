#!/usr/bin/env python3
"""Claude Code Annotation Review Server"""

import argparse
import http.server
import json
import signal
import socketserver
import sys
import threading
import webbrowser
from pathlib import Path

DEFAULT_PORT = 3456
DEFAULT_REVIEW_DIR = Path.home() / ".claude-review"

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude Code Review</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/vs2015.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/diff@5.1.0/dist/diff.min.js"></script>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #1e1e1e;
            color: #d4d4d4;
            min-height: 100vh;
        }
        .header {
            background: #252526;
            padding: 12px 20px;
            border-bottom: 1px solid #3c3c3c;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header h1 {
            font-size: 14px;
            font-weight: 400;
            color: #cccccc;
        }
        .file-path {
            background: #3c3c3c;
            padding: 4px 10px;
            border-radius: 3px;
            font-family: "SF Mono", Consolas, monospace;
            font-size: 12px;
            color: #e0e0e0;
        }

        /* File tabs for multi-file review */
        .file-tabs {
            display: flex;
            background: #252526;
            border-bottom: 1px solid #3c3c3c;
            padding: 0 12px;
            overflow-x: auto;
            gap: 2px;
        }
        .file-tabs:empty {
            display: none;
        }
        .file-tab {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            background: transparent;
            border: none;
            border-bottom: 2px solid transparent;
            color: #808080;
            font-size: 12px;
            font-family: "SF Mono", Consolas, monospace;
            cursor: pointer;
            white-space: nowrap;
            transition: all 0.15s;
        }
        .file-tab:hover {
            color: #d4d4d4;
            background: rgba(255,255,255,0.05);
        }
        .file-tab.active {
            color: #ffffff;
            border-bottom-color: #0e639c;
            background: rgba(255,255,255,0.05);
        }
        .file-tab .comment-badge {
            background: #f0b429;
            color: #1e1e1e;
            font-size: 10px;
            font-weight: 600;
            padding: 2px 6px;
            border-radius: 10px;
            min-width: 18px;
            text-align: center;
        }
        .file-tab .comment-badge:empty,
        .file-tab .comment-badge[data-count="0"] {
            display: none;
        }
        .file-tab .file-status {
            width: 8px;
            height: 8px;
            border-radius: 50%;
        }
        .file-tab .file-status.modified {
            background: #f0b429;
        }
        .file-tab .file-status.added {
            background: #89d185;
        }
        .file-tab .file-status.removed {
            background: #f85149;
        }
        .view-toggle {
            display: flex;
            gap: 4px;
            background: #3c3c3c;
            padding: 2px;
            border-radius: 4px;
        }
        .view-toggle button {
            background: transparent;
            border: none;
            color: #a0a0a0;
            padding: 6px 12px;
            border-radius: 3px;
            cursor: pointer;
            font-size: 12px;
            transition: all 0.15s;
        }
        .view-toggle button:hover { color: #ffffff; }
        .view-toggle button.active {
            background: #0e639c;
            color: #ffffff;
        }

        /* Main layout */
        .main-container {
            display: flex;
            height: calc(100vh - 110px);
        }

        /* Diff container */
        .diff-container {
            flex: 1;
            overflow: hidden;
            display: flex;
        }
        .diff-container.side-by-side {
            flex-direction: row;
        }
        .diff-container.unified {
            flex-direction: column;
        }
        .diff-container.unified .diff-pane.original {
            display: none;
        }
        .diff-container.unified .diff-pane.proposed {
            border-left: none;
        }

        .diff-pane {
            flex: 1;
            overflow: auto;
            background: #1e1e1e;
        }
        .diff-pane.original {
            border-right: 1px solid #3c3c3c;
        }
        .pane-header {
            position: sticky;
            top: 0;
            background: #252526;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #808080;
            padding: 8px 16px;
            border-bottom: 1px solid #3c3c3c;
            z-index: 10;
        }
        .pane-header.removed { color: #f14c4c; }
        .pane-header.added { color: #89d185; }

        .code-block {
            font-family: "SF Mono", Consolas, "Courier New", monospace;
            font-size: 13px;
            line-height: 20px;
        }

        .line {
            display: flex;
            min-height: 20px;
        }
        .line:hover {
            background: rgba(255,255,255,0.04);
        }
        .line-num {
            color: #6e7681;
            min-width: 50px;
            padding: 0 12px;
            text-align: right;
            user-select: none;
            background: #1e1e1e;
            border-right: 1px solid #3c3c3c;
        }
        .line-indicator {
            width: 20px;
            text-align: center;
            user-select: none;
            font-weight: bold;
        }
        .line-content {
            flex: 1;
            padding: 0 12px;
            white-space: pre-wrap;
            word-break: break-all;
        }

        /* Diff highlighting - VS Code style */
        .line.added {
            background: rgba(35, 134, 54, 0.2);
        }
        .line.added .line-num {
            background: rgba(35, 134, 54, 0.3);
            color: #89d185;
        }
        .line.added .line-indicator {
            color: #89d185;
        }
        .line.removed {
            background: rgba(248, 81, 73, 0.2);
        }
        .line.removed .line-num {
            background: rgba(248, 81, 73, 0.3);
            color: #f85149;
        }
        .line.removed .line-indicator {
            color: #f85149;
        }
        .line.unchanged {
            background: transparent;
        }

        /* Comment popup */
        .comment-popup {
            position: fixed;
            background: #252526;
            border: 1px solid #3c3c3c;
            border-radius: 6px;
            padding: 12px;
            width: 320px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.4);
            z-index: 1000;
            display: none;
        }
        .comment-popup.visible { display: block; }
        .comment-popup textarea {
            width: 100%;
            height: 80px;
            background: #3c3c3c;
            border: 1px solid #4c4c4c;
            border-radius: 4px;
            color: #d4d4d4;
            padding: 8px;
            font-family: inherit;
            font-size: 13px;
            resize: vertical;
        }
        .comment-popup textarea:focus {
            outline: none;
            border-color: #0e639c;
        }
        .comment-popup .hint {
            font-size: 11px;
            color: #808080;
            margin-top: 6px;
        }
        .comment-popup .btn-row {
            display: flex;
            gap: 8px;
            margin-top: 10px;
            justify-content: flex-end;
        }
        .btn {
            background: #3c3c3c;
            border: 1px solid #4c4c4c;
            color: #d4d4d4;
            padding: 6px 14px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
            transition: all 0.15s;
        }
        .btn:hover { background: #4c4c4c; }
        .btn.primary {
            background: #0e639c;
            border-color: #0e639c;
            color: #ffffff;
        }
        .btn.primary:hover { background: #1177bb; }

        ::selection { background: #264f78; }

        /* Footer */
        .footer {
            background: #252526;
            padding: 12px 20px;
            border-top: 1px solid #3c3c3c;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .status-select {
            background: #3c3c3c;
            border: 1px solid #4c4c4c;
            color: #d4d4d4;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 13px;
            cursor: pointer;
        }
        .status-select:focus {
            outline: none;
            border-color: #0e639c;
        }
        .submit-btn {
            background: #0e639c;
            border: none;
            color: white;
            padding: 8px 20px;
            border-radius: 4px;
            font-size: 13px;
            font-weight: 500;
            cursor: pointer;
            transition: background 0.15s;
        }
        .submit-btn:hover { background: #1177bb; }

        /* Comments sidebar */
        .comments-sidebar {
            width: 300px;
            background: #252526;
            border-left: 1px solid #3c3c3c;
            display: flex;
            flex-direction: column;
        }
        .sidebar-header {
            padding: 12px 16px;
            border-bottom: 1px solid #3c3c3c;
            font-size: 12px;
            font-weight: 500;
            color: #cccccc;
        }
        .comments-list {
            flex: 1;
            overflow-y: auto;
            padding: 12px;
        }
        .comment-card {
            background: #1e1e1e;
            border: 1px solid #3c3c3c;
            border-radius: 6px;
            padding: 10px;
            margin-bottom: 10px;
        }
        .comment-card .selection {
            font-family: "SF Mono", Consolas, monospace;
            font-size: 11px;
            color: #6e7681;
            background: #2d2d2d;
            padding: 4px 8px;
            border-radius: 3px;
            margin-bottom: 8px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .comment-card .text {
            font-size: 13px;
            line-height: 1.5;
            color: #d4d4d4;
        }
        .comment-card .delete-btn {
            font-size: 11px;
            color: #f85149;
            cursor: pointer;
            margin-top: 8px;
            opacity: 0.7;
        }
        .comment-card .delete-btn:hover { opacity: 1; }
        .no-comments {
            color: #6e7681;
            font-size: 13px;
            text-align: center;
            padding: 32px 16px;
        }

        .general-comment {
            padding: 12px;
            border-top: 1px solid #3c3c3c;
        }
        .general-comment label {
            font-size: 11px;
            color: #808080;
            display: block;
            margin-bottom: 6px;
        }
        .general-comment textarea {
            width: 100%;
            height: 60px;
            background: #1e1e1e;
            border: 1px solid #3c3c3c;
            border-radius: 4px;
            color: #d4d4d4;
            padding: 8px;
            font-family: inherit;
            font-size: 13px;
            resize: vertical;
        }
        .general-comment textarea:focus {
            outline: none;
            border-color: #0e639c;
        }

        /* Inline comment markers and speech balloons */
        .line {
            position: relative;
        }
        .line.has-comment {
            background: rgba(255, 200, 50, 0.08) !important;
        }
        .line.has-comment .line-num {
            background: rgba(255, 200, 50, 0.15) !important;
        }
        .comment-marker {
            position: absolute;
            right: 8px;
            top: 50%;
            transform: translateY(-50%);
            width: 22px;
            height: 22px;
            background: #f0b429;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
            font-weight: 600;
            color: #1e1e1e;
            cursor: pointer;
            z-index: 5;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
            transition: transform 0.15s, box-shadow 0.15s;
        }
        .comment-marker:hover {
            transform: translateY(-50%) scale(1.1);
            box-shadow: 0 4px 12px rgba(0,0,0,0.4);
        }

        /* Speech balloon */
        .speech-balloon {
            position: absolute;
            right: 40px;
            top: 50%;
            transform: translateY(-50%);
            background: #2d2d2d;
            border: 1px solid #4c4c4c;
            border-radius: 8px;
            padding: 10px 14px;
            max-width: 320px;
            min-width: 180px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.5);
            z-index: 100;
            display: none;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        .speech-balloon.visible {
            display: block;
            animation: balloon-in 0.15s ease-out;
        }
        @keyframes balloon-in {
            from { opacity: 0; transform: translateY(-50%) translateX(10px); }
            to { opacity: 1; transform: translateY(-50%) translateX(0); }
        }
        .speech-balloon::after {
            content: '';
            position: absolute;
            right: -8px;
            top: 50%;
            transform: translateY(-50%);
            border: 8px solid transparent;
            border-left-color: #2d2d2d;
            border-right: none;
        }
        .speech-balloon::before {
            content: '';
            position: absolute;
            right: -9px;
            top: 50%;
            transform: translateY(-50%);
            border: 8px solid transparent;
            border-left-color: #4c4c4c;
            border-right: none;
        }
        .speech-balloon .balloon-header {
            font-size: 11px;
            color: #f0b429;
            margin-bottom: 6px;
            font-weight: 500;
        }
        .speech-balloon .balloon-text {
            font-size: 13px;
            line-height: 1.5;
            color: #e0e0e0;
        }
        .speech-balloon .balloon-selection {
            font-family: "SF Mono", Consolas, monospace;
            font-size: 11px;
            color: #808080;
            background: #1e1e1e;
            padding: 4px 8px;
            border-radius: 4px;
            margin-top: 8px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        /* Highlighted text selection */
        .comment-highlight {
            background: rgba(240, 180, 41, 0.35);
            border-bottom: 2px solid #f0b429;
            border-radius: 2px;
            padding: 1px 0;
            cursor: pointer;
            transition: background 0.15s;
        }
        .comment-highlight:hover {
            background: rgba(240, 180, 41, 0.5);
        }
        .comment-highlight.active {
            background: rgba(240, 180, 41, 0.6);
            box-shadow: 0 0 0 2px rgba(240, 180, 41, 0.3);
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Code Review</h1>
        <span class="file-path" id="filePath">Loading...</span>
        <div class="view-toggle">
            <button class="active" data-view="side">Split</button>
            <button data-view="unified">Unified</button>
        </div>
    </div>

    <div class="file-tabs" id="fileTabs"></div>

    <div class="main-container">
        <div class="diff-container side-by-side" id="diffContainer">
            <div class="diff-pane original">
                <div class="pane-header removed">− Original</div>
                <div class="code-block" id="originalCode"></div>
            </div>
            <div class="diff-pane proposed">
                <div class="pane-header added">+ Proposed</div>
                <div class="code-block" id="proposedCode"></div>
            </div>
        </div>

        <div class="comments-sidebar">
            <div class="sidebar-header">Comments</div>
            <div class="comments-list" id="commentsList">
                <div class="no-comments">Select text to add comments</div>
            </div>
            <div class="general-comment">
                <label>General feedback</label>
                <textarea id="generalComment" placeholder="Overall thoughts..."></textarea>
            </div>
        </div>
    </div>

    <div class="footer">
        <select class="status-select" id="statusSelect">
            <option value="changes_requested">Request Changes</option>
            <option value="approved">Approve</option>
            <option value="rejected">Reject</option>
        </select>
        <button class="submit-btn" id="submitBtn">Submit Feedback</button>
    </div>

    <div class="comment-popup" id="commentPopup">
        <textarea id="commentInput" placeholder="Add your comment..."></textarea>
        <div class="hint">⌘+Enter to save</div>
        <div class="btn-row">
            <button class="btn" id="cancelComment">Cancel</button>
            <button class="btn primary" id="saveComment">Save</button>
        </div>
    </div>

    <script>
        // Multi-file support
        let files = [];           // Array of file objects
        let currentFileIndex = 0; // Currently viewed file
        let commentsByFile = {};  // { filepath: [comments] }
        let currentSelection = null;
        let currentView = 'side';
        let diffResult = null;

        // View toggle
        document.querySelectorAll('.view-toggle button').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.view-toggle button').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                currentView = btn.dataset.view;
                const container = document.getElementById('diffContainer');
                container.className = 'diff-container ' + (currentView === 'side' ? 'side-by-side' : 'unified');
                renderCode();
            });
        });

        async function loadPending() {
            try {
                const res = await fetch('/api/pending');
                const data = await res.json();

                // Support both single-file and multi-file formats
                if (data.files && Array.isArray(data.files)) {
                    files = data.files;
                } else {
                    // Convert single file to array format
                    files = [{
                        file_path: data.file_path,
                        file_type: data.file_type,
                        original_content: data.original_content,
                        proposed_content: data.proposed_content
                    }];
                }

                // Initialize comments for each file
                files.forEach(f => {
                    if (!commentsByFile[f.file_path]) {
                        commentsByFile[f.file_path] = [];
                    }
                });

                renderFileTabs();
                switchToFile(0);
            } catch (e) {
                document.getElementById('filePath').textContent = 'Error loading';
                console.error(e);
            }
        }

        function renderFileTabs() {
            const tabsContainer = document.getElementById('fileTabs');

            // Hide tabs if only one file
            if (files.length <= 1) {
                tabsContainer.innerHTML = '';
                return;
            }

            tabsContainer.innerHTML = files.map((f, i) => {
                const filename = f.file_path.split('/').pop();
                const commentCount = (commentsByFile[f.file_path] || []).length;
                const isNew = !f.original_content || f.original_content.trim() === '';
                const isDeleted = !f.proposed_content || f.proposed_content.trim() === '';
                const statusClass = isNew ? 'added' : (isDeleted ? 'removed' : 'modified');

                return `
                    <button class="file-tab ${i === currentFileIndex ? 'active' : ''}" data-index="${i}">
                        <span class="file-status ${statusClass}"></span>
                        <span class="filename">${filename}</span>
                        <span class="comment-badge" data-count="${commentCount}">${commentCount || ''}</span>
                    </button>
                `;
            }).join('');

            // Add click handlers
            tabsContainer.querySelectorAll('.file-tab').forEach(tab => {
                tab.addEventListener('click', () => {
                    switchToFile(parseInt(tab.dataset.index));
                });
            });
        }

        function switchToFile(index) {
            currentFileIndex = index;
            const file = files[index];

            // Update file path display
            document.getElementById('filePath').textContent = file.file_path;

            // Update tab active state
            document.querySelectorAll('.file-tab').forEach((tab, i) => {
                tab.classList.toggle('active', i === index);
            });

            computeDiff();
            renderCode();
            renderComments();
        }

        function getCurrentFile() {
            return files[currentFileIndex];
        }

        function getCurrentComments() {
            const file = getCurrentFile();
            return commentsByFile[file.file_path] || [];
        }

        function computeDiff() {
            const file = getCurrentFile();
            const origLines = (file.original_content || '').split('\\n');
            const propLines = (file.proposed_content || '').split('\\n');
            diffResult = Diff.diffArrays(origLines, propLines);
        }

        function renderCode() {
            if (currentView === 'side') {
                renderSideBySide();
            } else {
                renderUnified();
            }
            applySyntaxHighlighting();
            renderInlineMarkers();
        }

        function renderSideBySide() {
            const file = getCurrentFile();
            const origLines = (file.original_content || '').split('\\n');
            const propLines = (file.proposed_content || '').split('\\n');

            // Build line-by-line diff info
            let origIdx = 0, propIdx = 0;
            let origHtml = [], propHtml = [];

            for (const part of diffResult) {
                const lines = part.value;
                for (const line of lines) {
                    if (part.removed) {
                        origHtml.push(makeLine(origIdx + 1, line, 'removed', '-'));
                        propHtml.push(makeLine('', '', 'empty', ''));
                        origIdx++;
                    } else if (part.added) {
                        origHtml.push(makeLine('', '', 'empty', ''));
                        propHtml.push(makeLine(propIdx + 1, line, 'added', '+'));
                        propIdx++;
                    } else {
                        origHtml.push(makeLine(origIdx + 1, line, 'unchanged', ''));
                        propHtml.push(makeLine(propIdx + 1, line, 'unchanged', ''));
                        origIdx++;
                        propIdx++;
                    }
                }
            }

            document.getElementById('originalCode').innerHTML = origHtml.join('');
            document.getElementById('proposedCode').innerHTML = propHtml.join('');
        }

        function renderUnified() {
            let html = [];
            let origIdx = 0, propIdx = 0;

            for (const part of diffResult) {
                const lines = part.value;
                for (const line of lines) {
                    if (part.removed) {
                        html.push(makeLine(origIdx + 1, line, 'removed', '-'));
                        origIdx++;
                    } else if (part.added) {
                        html.push(makeLine(propIdx + 1, line, 'added', '+'));
                        propIdx++;
                    } else {
                        html.push(makeLine(propIdx + 1, line, 'unchanged', ' '));
                        origIdx++;
                        propIdx++;
                    }
                }
            }

            document.getElementById('proposedCode').innerHTML = html.join('');
        }

        function makeLine(num, content, type, indicator) {
            return `<div class="line ${type}"><span class="line-num">${num}</span><span class="line-indicator">${indicator}</span><span class="line-content">${escapeHtml(content)}</span></div>`;
        }

        function applySyntaxHighlighting() {
            const file = getCurrentFile();
            const lang = getLanguage(file.file_type);
            if (lang && hljs.getLanguage(lang)) {
                document.querySelectorAll('.line-content').forEach(el => {
                    if (el.textContent.trim()) {
                        el.innerHTML = hljs.highlight(el.textContent, { language: lang }).value;
                    }
                });
            }
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function getLanguage(fileType) {
            const map = {
                'lua': 'lua', 'py': 'python', 'python': 'python',
                'js': 'javascript', 'ts': 'typescript', 'cpp': 'cpp',
                'c': 'c', 'h': 'cpp', 'hpp': 'cpp', 'json': 'json',
                'md': 'markdown', 'html': 'xml', 'css': 'css',
                'rs': 'rust', 'go': 'go', 'java': 'java', 'rb': 'ruby'
            };
            return map[fileType] || fileType;
        }

        // Selection handling - both panes
        document.getElementById('proposedCode').addEventListener('mouseup', handleSelection);
        document.getElementById('originalCode').addEventListener('mouseup', handleSelection);

        function handleSelection(e) {
            const selection = window.getSelection();
            const text = selection.toString().trim();

            if (text.length > 0) {
                const range = selection.getRangeAt(0);
                const startLine = getLineNumber(range.startContainer);
                const endLine = getLineNumber(range.endContainer);

                currentSelection = {
                    start: { line: startLine, col: range.startOffset },
                    end: { line: endLine, col: range.endOffset },
                    text: text
                };

                const rect = range.getBoundingClientRect();
                const popup = document.getElementById('commentPopup');
                popup.style.top = Math.min(rect.bottom + 8, window.innerHeight - 200) + 'px';
                popup.style.left = Math.min(rect.left, window.innerWidth - 340) + 'px';
                popup.classList.add('visible');
                document.getElementById('commentInput').focus();
            }
        }

        function getLineNumber(node) {
            let el = node.nodeType === 3 ? node.parentElement : node;
            while (el && !el.classList.contains('line')) {
                el = el.parentElement;
            }
            if (el) {
                const lineNum = el.querySelector('.line-num');
                return parseInt(lineNum?.textContent || '1');
            }
            return 1;
        }

        // Comment popup - Cancel
        document.getElementById('cancelComment').addEventListener('click', closePopup);

        // Comment popup - Save
        document.getElementById('saveComment').addEventListener('click', saveComment);

        // Cmd+Enter to save comment
        document.getElementById('commentInput').addEventListener('keydown', (e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
                e.preventDefault();
                saveComment();
            }
            if (e.key === 'Escape') {
                closePopup();
            }
        });

        function saveComment() {
            const commentText = document.getElementById('commentInput').value.trim();
            if (commentText && currentSelection) {
                const file = getCurrentFile();
                if (!commentsByFile[file.file_path]) {
                    commentsByFile[file.file_path] = [];
                }
                commentsByFile[file.file_path].push({
                    selection: {
                        start: currentSelection.start,
                        end: currentSelection.end
                    },
                    selected_text: currentSelection.text,
                    comment: commentText
                });
                renderComments();
                renderFileTabs(); // Update comment count badges
            }
            closePopup();
        }

        function closePopup() {
            document.getElementById('commentPopup').classList.remove('visible');
            document.getElementById('commentInput').value = '';
            currentSelection = null;
            window.getSelection().removeAllRanges();
        }

        function renderComments() {
            // Update sidebar
            const container = document.getElementById('commentsList');
            const comments = getCurrentComments();
            if (comments.length === 0) {
                container.innerHTML = '<div class="no-comments">Select text to add comments</div>';
            } else {
                container.innerHTML = comments.map((c, i) => `
                    <div class="comment-card" data-comment-idx="${i}" onmouseenter="highlightLine(${c.selection.start.line})" onmouseleave="unhighlightLine(${c.selection.start.line})">
                        <div class="selection">L${c.selection.start.line}: ${c.selected_text.substring(0, 40)}${c.selected_text.length > 40 ? '...' : ''}</div>
                        <div class="text">${escapeHtml(c.comment)}</div>
                        <div class="delete-btn" onclick="deleteComment(${i})">Delete</div>
                    </div>
                `).join('');
            }

            // Add inline markers to code lines
            renderInlineMarkers();
        }

        function renderInlineMarkers() {
            // Remove existing markers, balloons, and highlights
            document.querySelectorAll('.comment-marker, .speech-balloon').forEach(el => el.remove());
            document.querySelectorAll('.line.has-comment').forEach(el => el.classList.remove('has-comment'));

            // Remove old highlights by unwrapping them
            document.querySelectorAll('.comment-highlight').forEach(el => {
                const parent = el.parentNode;
                while (el.firstChild) {
                    parent.insertBefore(el.firstChild, el);
                }
                parent.removeChild(el);
            });

            // Group comments by line
            const comments = getCurrentComments();
            const commentsByLine = {};
            comments.forEach((c, i) => {
                const line = c.selection.start.line;
                if (!commentsByLine[line]) commentsByLine[line] = [];
                commentsByLine[line].push({ ...c, index: i });
            });

            // Add markers to lines in proposed code pane
            const proposedPane = document.getElementById('proposedCode');
            const lines = proposedPane.querySelectorAll('.line');

            for (const [lineNum, lineComments] of Object.entries(commentsByLine)) {
                const lineEl = Array.from(lines).find(el => {
                    const numEl = el.querySelector('.line-num');
                    return numEl && numEl.textContent === lineNum;
                });

                if (lineEl) {
                    lineEl.classList.add('has-comment');

                    // Highlight selected text for each comment
                    const lineContent = lineEl.querySelector('.line-content');
                    if (lineContent) {
                        lineComments.forEach((c, idx) => {
                            highlightTextInElement(lineContent, c.selected_text, c.index);
                        });
                    }

                    // Create marker
                    const marker = document.createElement('div');
                    marker.className = 'comment-marker';
                    marker.textContent = lineComments.length;
                    marker.dataset.line = lineNum;

                    // Create speech balloon
                    const balloon = document.createElement('div');
                    balloon.className = 'speech-balloon';
                    balloon.innerHTML = lineComments.map(c => `
                        <div class="balloon-comment">
                            <div class="balloon-text">${escapeHtml(c.comment)}</div>
                            <div class="balloon-selection">"${c.selected_text.substring(0, 50)}${c.selected_text.length > 50 ? '...' : ''}"</div>
                        </div>
                    `).join('<hr style="border:none;border-top:1px solid #3c3c3c;margin:10px 0;">');

                    // Toggle balloon on click
                    marker.addEventListener('click', (e) => {
                        e.stopPropagation();
                        // Hide all other balloons
                        document.querySelectorAll('.speech-balloon.visible').forEach(b => {
                            if (b !== balloon) b.classList.remove('visible');
                        });
                        balloon.classList.toggle('visible');
                    });

                    lineEl.appendChild(marker);
                    lineEl.appendChild(balloon);
                }
            }

            // Click outside to close balloons
            document.addEventListener('click', (e) => {
                if (!e.target.closest('.speech-balloon') && !e.target.closest('.comment-marker')) {
                    document.querySelectorAll('.speech-balloon.visible').forEach(b => b.classList.remove('visible'));
                }
            });
        }

        // Highlight specific text within an element (handles syntax-highlighted spans)
        function highlightTextInElement(element, searchText, commentIndex) {
            if (!searchText || searchText.length === 0) return;

            // Get all text nodes
            const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, null, false);
            const textNodes = [];
            let node;
            while (node = walker.nextNode()) {
                textNodes.push(node);
            }

            // Build full text and find match position
            let fullText = '';
            const nodeMap = []; // Maps character index to {node, offset}
            textNodes.forEach(tn => {
                for (let i = 0; i < tn.textContent.length; i++) {
                    nodeMap.push({ node: tn, offset: i });
                }
                fullText += tn.textContent;
            });

            // Find the search text (first occurrence)
            const matchIndex = fullText.indexOf(searchText);
            if (matchIndex === -1) return;

            // Get start and end positions
            const startPos = nodeMap[matchIndex];
            const endPos = nodeMap[matchIndex + searchText.length - 1];
            if (!startPos || !endPos) return;

            // If same node, simple wrap
            if (startPos.node === endPos.node) {
                const textNode = startPos.node;
                const text = textNode.textContent;
                const before = text.substring(0, startPos.offset);
                const match = text.substring(startPos.offset, endPos.offset + 1);
                const after = text.substring(endPos.offset + 1);

                const span = document.createElement('span');
                span.className = 'comment-highlight';
                span.dataset.commentIndex = commentIndex;
                span.textContent = match;
                span.addEventListener('click', (e) => {
                    e.stopPropagation();
                    // Show balloon for this comment
                    const line = span.closest('.line');
                    const balloon = line?.querySelector('.speech-balloon');
                    if (balloon) {
                        document.querySelectorAll('.speech-balloon.visible').forEach(b => b.classList.remove('visible'));
                        balloon.classList.add('visible');
                    }
                });

                const parent = textNode.parentNode;
                if (before) parent.insertBefore(document.createTextNode(before), textNode);
                parent.insertBefore(span, textNode);
                if (after) parent.insertBefore(document.createTextNode(after), textNode);
                parent.removeChild(textNode);
            } else {
                // Multi-node highlight - just highlight the first node's portion for simplicity
                const textNode = startPos.node;
                const text = textNode.textContent;
                const before = text.substring(0, startPos.offset);
                const match = text.substring(startPos.offset);

                const span = document.createElement('span');
                span.className = 'comment-highlight';
                span.dataset.commentIndex = commentIndex;
                span.textContent = match;
                span.addEventListener('click', (e) => {
                    e.stopPropagation();
                    const line = span.closest('.line');
                    const balloon = line?.querySelector('.speech-balloon');
                    if (balloon) {
                        document.querySelectorAll('.speech-balloon.visible').forEach(b => b.classList.remove('visible'));
                        balloon.classList.add('visible');
                    }
                });

                const parent = textNode.parentNode;
                if (before) parent.insertBefore(document.createTextNode(before), textNode);
                parent.insertBefore(span, textNode);
                parent.removeChild(textNode);
            }
        }

        function highlightLine(lineNum) {
            const proposedPane = document.getElementById('proposedCode');
            const lines = proposedPane.querySelectorAll('.line');
            lines.forEach(el => {
                const numEl = el.querySelector('.line-num');
                if (numEl && numEl.textContent === String(lineNum)) {
                    el.style.outline = '2px solid #f0b429';
                    el.style.outlineOffset = '-2px';
                }
            });
        }

        function unhighlightLine(lineNum) {
            const proposedPane = document.getElementById('proposedCode');
            const lines = proposedPane.querySelectorAll('.line');
            lines.forEach(el => {
                const numEl = el.querySelector('.line-num');
                if (numEl && numEl.textContent === String(lineNum)) {
                    el.style.outline = '';
                    el.style.outlineOffset = '';
                }
            });
        }

        function deleteComment(index) {
            const file = getCurrentFile();
            if (commentsByFile[file.file_path]) {
                commentsByFile[file.file_path].splice(index, 1);
            }
            renderComments();
            renderFileTabs();
        }

        document.getElementById('submitBtn').addEventListener('click', async () => {
            // Build feedback for all files
            const filesWithComments = files.map(f => ({
                file: f.file_path,
                file_type: f.file_type,
                comments: commentsByFile[f.file_path] || []
            })).filter(f => f.comments.length > 0);

            // Total comment count
            const totalComments = Object.values(commentsByFile).reduce((sum, arr) => sum + arr.length, 0);

            const feedback = {
                reviewed_at: new Date().toISOString(),
                status: document.getElementById('statusSelect').value,
                general_comment: document.getElementById('generalComment').value.trim(),
                total_files: files.length,
                total_comments: totalComments,
                // Multi-file format
                files: filesWithComments,
                // Legacy single-file format (for backward compatibility, uses first file)
                file: files[0]?.file_path,
                comments: filesWithComments[0]?.comments || []
            };

            try {
                const res = await fetch('/api/feedback', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(feedback)
                });
                if (res.ok) {
                    document.body.innerHTML = `<div style="display:flex;align-items:center;justify-content:center;height:100vh;flex-direction:column;background:#1e1e1e;"><h1 style="color:#89d185;">Feedback Submitted!</h1><p style="color:#6e7681;margin-top:16px;">${totalComments} comment${totalComments !== 1 ? 's' : ''} on ${filesWithComments.length} file${filesWithComments.length !== 1 ? 's' : ''}</p></div>`;
                }
            } catch (e) {
                alert('Error submitting feedback');
            }
        });

        loadPending();
    </script>
</body>
</html>
"""


class ReviewHandler(http.server.BaseHTTPRequestHandler):
    review_dir = DEFAULT_REVIEW_DIR
    shutdown_on_feedback = True

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.serve_index()
        elif self.path == "/api/pending":
            self.serve_pending()
        elif self.path == "/api/diff":
            self.serve_diff()
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/api/feedback":
            self.handle_feedback()
        else:
            self.send_response(404)
            self.end_headers()

    def serve_index(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(HTML_TEMPLATE.encode("utf-8"))

    def serve_pending(self):
        meta_path = self.review_dir / "pending_meta.json"
        if meta_path.exists():
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(meta_path.read_bytes())
        else:
            self.send_response(404)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"error": "No pending changes"}')

    def serve_diff(self):
        diff_path = self.review_dir / "pending.diff"
        if diff_path.exists():
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(diff_path.read_bytes())
        else:
            self.send_response(404)
            self.end_headers()

    def handle_feedback(self):
        content_length = int(self.headers["Content-Length"])
        post_data = self.rfile.read(content_length)
        feedback = json.loads(post_data.decode("utf-8"))

        feedback_path = self.review_dir / "feedback.json"
        feedback_path.write_text(json.dumps(feedback, indent=2))

        history_dir = self.review_dir / "history"
        history_dir.mkdir(exist_ok=True)
        timestamp = feedback["reviewed_at"].replace(":", "-").replace(".", "-")
        filename = Path(feedback["file"]).stem
        archive_path = history_dir / f"{timestamp[:19]}-{filename}.json"
        archive_path.write_text(json.dumps(feedback, indent=2))

        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status": "ok"}')

        if self.shutdown_on_feedback:
            print("\n[server] Feedback received, shutting down...")
            threading.Thread(target=self.server.shutdown).start()

    def log_message(self, format, *args):
        print(f"[server] {args[0]}")


def main():
    parser = argparse.ArgumentParser(description="Claude Code Review Server")
    parser.add_argument(
        "--port", type=int, default=DEFAULT_PORT, help="Port to serve on"
    )
    parser.add_argument(
        "--no-browser", action="store_true", help="Do not open browser automatically"
    )
    parser.add_argument(
        "--no-shutdown",
        action="store_true",
        help="Do not shutdown after feedback (for testing)",
    )
    parser.add_argument(
        "--test-dir", type=str, help="Override review directory (for testing)"
    )
    args = parser.parse_args()

    review_dir = Path(args.test_dir) if args.test_dir else DEFAULT_REVIEW_DIR
    review_dir.mkdir(parents=True, exist_ok=True)

    meta_path = review_dir / "pending_meta.json"
    if not meta_path.exists():
        print("[server] No pending changes to review.")
        print(f"[server] Create {meta_path} with change data first.")
        sys.exit(1)

    ReviewHandler.review_dir = review_dir
    ReviewHandler.shutdown_on_feedback = not args.no_shutdown

    server = socketserver.TCPServer(("", args.port), ReviewHandler)
    server.allow_reuse_address = True

    def signal_handler(sig, frame):
        print("\n[server] Shutting down...")
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    print(f"[server] Review server running at http://localhost:{args.port}")

    if not args.no_browser:
        webbrowser.open(f"http://localhost:{args.port}")

    server.serve_forever()


if __name__ == "__main__":
    main()
