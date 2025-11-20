#!/usr/bin/env python3
"""
Download Godot shaders from godotshaders.com
Reads URLs from shader_todo.md and downloads the shader code
"""

import re
import sys
import os
import time
import gzip
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
from html.parser import HTMLParser


class ShaderCodeExtractor(HTMLParser):
    """Extract shader code from godotshaders.com HTML"""

    def __init__(self):
        super().__init__()
        self.in_code_block = False
        self.in_shader_block = False
        self.code_lines = []
        self.current_code = []
        self.current_tag = None

    def handle_starttag(self, tag, attrs):
        # Look for code blocks - godotshaders.com uses pre or code tags
        if tag in ('pre', 'code'):
            self.in_code_block = True
            self.current_code = []
        self.current_tag = tag

    def handle_endtag(self, tag):
        if tag in ('pre', 'code') and self.in_code_block:
            self.in_code_block = False
            # Save this code block if it has shader content
            code_text = ''.join(self.current_code)
            if self._looks_like_shader(code_text):
                self.code_lines.append(code_text)
            self.current_code = []
        self.current_tag = None

    def handle_data(self, data):
        if self.in_code_block:
            self.current_code.append(data)

    def _looks_like_shader(self, text):
        """Check if text looks like shader code"""
        shader_keywords = [
            'shader_type', 'uniform', 'void fragment', 'void vertex',
            'varying', 'precision', 'COLOR', 'UV', 'TEXTURE',
            'vec2', 'vec3', 'vec4', 'sampler2D', 'float'
        ]
        return any(keyword in text for keyword in shader_keywords)

    def get_shader_code(self):
        """Return the extracted shader code (longest block that looks like a shader)"""
        if not self.code_lines:
            return None
        # Return the longest code block (usually the main shader)
        return max(self.code_lines, key=len) if self.code_lines else None


def extract_urls_from_todo(todo_file):
    """Extract all godotshaders.com URLs from the todo markdown file"""
    urls = []

    with open(todo_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all godotshaders.com URLs
    pattern = r'https://godotshaders\.com/shader/[a-zA-Z0-9\-_/%]+'
    urls = re.findall(pattern, content)

    # Remove duplicates and trailing slashes
    urls = list(set(url.rstrip('/') for url in urls))

    return sorted(urls)


def download_shader(url, output_dir, delay=1.5):
    """Download shader code from a godotshaders.com URL"""

    # Extract shader name from URL
    shader_name = url.rstrip('/').split('/')[-1]
    output_file = output_dir / f"{shader_name}.godot"

    # Skip if already downloaded
    if output_file.exists():
        print(f"  ✓ Already exists: {shader_name}")
        return True

    print(f"  Downloading: {shader_name}")

    try:
        # Add headers to avoid being blocked
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
        }
        req = Request(url, headers=headers)

        with urlopen(req, timeout=15) as response:
            data = response.read()

            # Check if response is gzip-compressed
            if data[:2] == b'\x1f\x8b':  # gzip magic number
                data = gzip.decompress(data)

            html = data.decode('utf-8')

        # Extract shader code from HTML
        parser = ShaderCodeExtractor()
        parser.feed(html)
        shader_code = parser.get_shader_code()

        if shader_code and len(shader_code.strip()) > 50:
            # Save to file
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(f"// Source: {url}\n")
                f.write(f"// Shader: {shader_name}\n")
                f.write(f"// Downloaded: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
                f.write(shader_code)
            print(f"    ✓ Saved ({len(shader_code)} chars)")
            return True
        else:
            print(f"    ⚠ No shader code found")
            # Save a note file for manual download
            with open(output_file.with_suffix('.txt'), 'w') as f:
                f.write(f"Failed to extract shader code automatically.\n")
                f.write(f"Please visit manually and copy shader code:\n")
                f.write(f"{url}\n\n")
                f.write(f"Then save as: {output_file}\n")
            return False

    except (URLError, HTTPError) as e:
        print(f"    ✗ Error: {e}")
        return False
    except Exception as e:
        print(f"    ✗ Unexpected error: {e}")
        return False
    finally:
        # Rate limiting - be respectful to the server
        time.sleep(delay)


def main():
    # Setup paths
    script_dir = Path(__file__).parent
    todo_file = script_dir / "shader_todo.md"
    output_dir = script_dir / "godot_sources"

    if not todo_file.exists():
        print(f"Error: {todo_file} not found")
        return 1

    # Create output directory
    output_dir.mkdir(exist_ok=True)

    print("=" * 70)
    print("Godot Shader Downloader")
    print("=" * 70)

    # Extract URLs
    print(f"\nReading URLs from: {todo_file.name}")
    urls = extract_urls_from_todo(todo_file)
    print(f"Found {len(urls)} unique shader URLs\n")

    if len(urls) == 0:
        print("No shader URLs found in todo file!")
        return 1

    # Download each shader
    print(f"Downloading to: {output_dir}/")
    print("-" * 70)

    successful = 0
    failed = 0
    skipped = 0

    for i, url in enumerate(urls, 1):
        print(f"\n[{i}/{len(urls)}]")

        shader_name = url.rstrip('/').split('/')[-1]
        output_file = output_dir / f"{shader_name}.godot"

        if output_file.exists():
            skipped += 1
            print(f"  ⊘ Skipped (already exists): {shader_name}")
            continue

        if download_shader(url, output_dir):
            successful += 1
        else:
            failed += 1

    # Summary
    print("\n" + "=" * 70)
    print("Download Summary:")
    print(f"  ✓ Successfully downloaded: {successful}")
    print(f"  ⊘ Skipped (already exist): {skipped}")
    print(f"  ✗ Failed: {failed}")
    print(f"  📊 Total shaders: {len(urls)}")
    print(f"\nShaders saved to: {output_dir}/")

    if failed > 0:
        print(f"\n⚠  {failed} shaders failed to download automatically.")
        print("   Check the .txt files in the output directory for manual download instructions.")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
