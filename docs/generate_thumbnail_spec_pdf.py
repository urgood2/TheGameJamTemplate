#!/usr/bin/env python3
"""Generate thumbnail spec PDF with embedded images using fpdf2."""

from fpdf import FPDF
from pathlib import Path
import glob

def find_screenshot(pattern):
    """Find screenshot with Unicode narrow no-break space in filename."""
    matches = glob.glob(pattern)
    if matches:
        return matches[0]
    return None

# Image paths - use glob patterns to handle Unicode spaces
REFERENCE_IMAGE = find_screenshot("/Users/joshuashin/Downloads/Screenshot 2026-01-19 at 7.58*")
SCREENSHOT_1 = find_screenshot("/Users/joshuashin/Downloads/Screenshot 2026-01-14 at 6.54*")
SCREENSHOT_2 = find_screenshot("/Users/joshuashin/Downloads/Screenshot 2026-01-19 at 9.10*")
SCREENSHOT_3 = find_screenshot("/Users/joshuashin/Downloads/Screenshot 2026-01-19 at 9.11*")

print(f"Reference: {REFERENCE_IMAGE}")
print(f"Screenshot 1: {SCREENSHOT_1}")
print(f"Screenshot 2: {SCREENSHOT_2}")
print(f"Screenshot 3: {SCREENSHOT_3}")

# Color definitions (from resurrect-64)
PURPLE_DARK = (46, 34, 47)
PURPLE = (107, 62, 117)
PINK = (162, 75, 111)
TEAL = (14, 175, 155)
WHITE = (255, 255, 255)
GRAY = (100, 100, 100)
BLACK = (0, 0, 0)

class ThumbnailSpecPDF(FPDF):
    def header(self):
        if self.page_no() > 1:
            self.set_font('Helvetica', 'I', 9)
            self.set_text_color(*GRAY)
            self.cell(0, 10, 'Trigger Survivors - Thumbnail Art Spec', align='R')
            self.ln(15)

    def footer(self):
        self.set_y(-15)
        self.set_font('Helvetica', 'I', 8)
        self.set_text_color(*GRAY)
        self.cell(0, 10, f'Page {self.page_no()}/{{nb}}', align='C')

    def title_section(self, text):
        self.set_font('Helvetica', 'B', 18)
        self.set_text_color(*PURPLE)
        self.cell(0, 12, text, ln=True)
        self.set_draw_color(*PINK)
        self.set_line_width(0.8)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(8)

    def heading(self, text):
        self.ln(5)
        self.set_font('Helvetica', 'B', 14)
        self.set_text_color(*PURPLE_DARK)
        self.cell(0, 10, text, ln=True)
        self.set_draw_color(200, 200, 200)
        self.set_line_width(0.3)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(3)

    def subheading(self, text):
        self.ln(3)
        self.set_font('Helvetica', 'B', 12)
        self.set_text_color(*PURPLE)
        self.cell(0, 8, text, ln=True)

    def body_text(self, text):
        self.set_font('Helvetica', '', 10)
        self.set_text_color(*BLACK)
        self.set_x(10)  # Reset to left margin
        self.multi_cell(0, 6, text)
        self.ln(2)

    def bullet_point(self, text, bold_prefix=""):
        self.set_font('Helvetica', '', 10)
        self.set_text_color(*BLACK)
        self.set_x(10)  # Reset to left margin
        bullet_text = f"  - {text}"
        self.multi_cell(0, 6, bullet_text)

    def highlight_box(self, text):
        self.set_fill_color(255, 243, 205)
        self.set_draw_color(249, 194, 43)
        self.set_line_width(0.5)
        y_start = self.get_y()
        self.set_xy(10, y_start)
        # Draw background
        self.rect(10, y_start, 190, 12, 'DF')
        # Draw left accent
        self.set_fill_color(249, 194, 43)
        self.rect(10, y_start, 3, 12, 'F')
        # Text
        self.set_xy(16, y_start + 3)
        self.set_font('Helvetica', 'B', 10)
        self.set_text_color(*BLACK)
        self.multi_cell(180, 6, text)
        self.ln(5)

    def color_sample(self, hex_color, name, usage, x_offset=0):
        # Convert hex to RGB
        hex_color = hex_color.lstrip('#')
        r, g, b = tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

        y = self.get_y()
        # Color box
        self.set_fill_color(r, g, b)
        self.set_draw_color(50, 50, 50)
        self.rect(10 + x_offset, y, 8, 8, 'DF')
        # Text
        self.set_xy(20 + x_offset, y)
        self.set_font('Helvetica', 'B', 9)
        self.set_text_color(*BLACK)
        self.cell(30, 8, name, ln=False)
        self.set_font('Courier', '', 8)
        self.set_text_color(*GRAY)
        self.cell(25, 8, f'#{hex_color}', ln=False)
        self.set_font('Helvetica', '', 9)
        self.set_text_color(*BLACK)
        self.cell(0, 8, usage, ln=True)


def create_spec_pdf():
    pdf = ThumbnailSpecPDF()
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=True, margin=20)

    # Page 1: Title and Overview
    pdf.add_page()

    # Main title
    pdf.set_font('Helvetica', 'B', 28)
    pdf.set_text_color(*PURPLE)
    pdf.cell(0, 20, 'Thumbnail Art Spec', ln=True, align='C')
    pdf.set_font('Helvetica', 'B', 22)
    pdf.set_text_color(*PINK)
    pdf.cell(0, 12, 'Trigger Survivors', ln=True, align='C')
    pdf.ln(10)

    # Header info box
    pdf.set_fill_color(245, 240, 247)
    pdf.rect(10, pdf.get_y(), 190, 30, 'F')
    pdf.set_xy(15, pdf.get_y() + 5)
    pdf.set_font('Helvetica', '', 10)
    pdf.set_text_color(*BLACK)
    pdf.cell(60, 6, 'Document Version: 1.0', ln=False)
    pdf.cell(60, 6, 'Date: January 19, 2026', ln=False)
    pdf.cell(0, 6, 'Status: Ready for Artist', ln=True)
    pdf.set_xy(15, pdf.get_y() + 2)
    pdf.ln(20)

    # Project Overview
    pdf.heading('Project Overview')

    # Info table
    pdf.set_font('Helvetica', 'B', 10)
    pdf.set_fill_color(69, 41, 63)
    pdf.set_text_color(*WHITE)
    pdf.cell(50, 8, 'Field', border=1, fill=True)
    pdf.cell(140, 8, 'Value', border=1, fill=True, ln=True)

    pdf.set_font('Helvetica', '', 10)
    pdf.set_text_color(*BLACK)
    pdf.set_fill_color(249, 249, 249)
    rows = [
        ('Game Title', 'Trigger Survivors (working title)'),
        ('Genre', 'Survivors-like with Wand Crafting'),
        ('Art Style', 'Pixel Art'),
        ('Color Palette', 'Resurrect-64 (Lospec)')
    ]
    for i, (field, value) in enumerate(rows):
        fill = i % 2 == 1
        pdf.cell(50, 7, field, border=1, fill=fill)
        pdf.set_font('Helvetica', 'B' if i == 0 else '', 10)
        pdf.cell(140, 7, value, border=1, fill=fill, ln=True)
        pdf.set_font('Helvetica', '', 10)

    pdf.ln(5)

    pdf.subheading('Brief Description')
    pdf.body_text('Trigger Survivors is a wave-based survival game where players fight hordes of enemies while collecting and combining unique equipment. The core mechanic involves crafting custom wands by stacking spell effects together - similar to Noita\'s wand-building system but in a survivors-style gameplay loop.')

    pdf.subheading('Key Gameplay Elements')
    pdf.bullet_point('Wave-based survival against enemy hordes')
    pdf.bullet_point('Modular wand crafting system (Triggers > Actions > Modifiers)')
    pdf.bullet_point('Equipment collection and synergies')
    pdf.bullet_point('Pixel art aesthetic with vibrant colors')

    # Deliverables
    pdf.heading('Deliverables')
    pdf.highlight_box('Creative Freedom: The artist has creative freedom on composition and style within these guidelines.')

    pdf.subheading('Required Sizes')

    # Sizes table
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_fill_color(69, 41, 63)
    pdf.set_text_color(*WHITE)
    pdf.cell(50, 7, 'Platform', border=1, fill=True)
    pdf.cell(35, 7, 'Dimensions', border=1, fill=True)
    pdf.cell(30, 7, 'Aspect Ratio', border=1, fill=True)
    pdf.cell(75, 7, 'Notes', border=1, fill=True, ln=True)

    pdf.set_font('Helvetica', '', 9)
    pdf.set_text_color(*BLACK)
    sizes = [
        ('Steam Header Capsule', '460 x 215', '~2.14:1', 'Primary store listing'),
        ('Steam Small Capsule', '231 x 87', '~2.66:1', 'Browse/search results'),
        ('Itch.io Cover', '630 x 500', '1.26:1', 'Game page header'),
        ('Itch.io Thumbnail', '315 x 250', '1.26:1', 'Browse grid'),
    ]
    for i, row in enumerate(sizes):
        fill = i % 2 == 1
        pdf.set_fill_color(249, 249, 249)
        for j, cell in enumerate(row):
            w = [50, 35, 30, 75][j]
            pdf.cell(w, 6, cell, border=1, fill=fill)
        pdf.ln()

    pdf.ln(3)
    pdf.set_font('Helvetica', 'I', 9)
    pdf.body_text('Recommendation: Design for the largest size first (Itch.io 630x500), then create cropped/adapted versions for Steam capsules.')

    # Page 2: Visual Identity
    pdf.add_page()
    pdf.heading('Visual Identity')

    pdf.subheading('Color Palette: Resurrect-64')
    pdf.body_text('The game uses the Resurrect-64 palette from Lospec. Key colors from our game:')

    pdf.ln(3)
    colors = [
        ('2e222f', 'Deep Purple', 'Dark backgrounds'),
        ('6b3e75', 'Purple', 'UI panels, shadows'),
        ('a24b6f', 'Magenta/Pink', 'Highlights, accents'),
        ('0eaf9b', 'Teal', 'Magic effects, spells'),
        ('f79617', 'Orange', 'Fire, energy'),
        ('ea4f36', 'Red', 'Enemies, danger'),
    ]
    for hex_col, name, usage in colors:
        pdf.color_sample(hex_col, name, usage)

    pdf.ln(3)
    pdf.set_font('Helvetica', '', 9)
    pdf.cell(0, 6, 'Full palette: https://lospec.com/palette-list/resurrect-64', ln=True)

    # Full palette grid
    pdf.ln(3)
    pdf.subheading('Full Resurrect-64 Palette')
    palette = [
        '#2e222f', '#3e3546', '#625565', '#966c6c', '#ab947a', '#694f62', '#7f708a', '#9babb2',
        '#c7dcd0', '#ffffff', '#6e2727', '#b33831', '#ea4f36', '#f57d4a', '#ae2334', '#e83b3b',
        '#fb6b1d', '#f79617', '#f9c22b', '#7a3045', '#9e4539', '#cd683d', '#e6904e', '#fbb954',
        '#4c3e24', '#676633', '#a2a947', '#d5e04b', '#fbff86', '#165a4c', '#239063', '#1ebc73',
        '#91db69', '#cddf6c', '#313638', '#374e4a', '#547e64', '#92a984', '#b2ba90', '#0b5e65',
        '#0b8a8f', '#0eaf9b', '#30e1b9', '#8ff8e2', '#323353', '#484a77', '#4d65b4', '#4d9be6',
        '#8fd3ff', '#45293f', '#6b3e75', '#905ea9', '#a884f3', '#eaaded', '#753c54', '#a24b6f',
        '#cf657f', '#ed8099', '#831c5d', '#c32454', '#f04f78', '#f68181', '#fca790', '#fdcbb0',
    ]

    box_size = 10
    cols = 16
    x_start = 10
    y_start = pdf.get_y()

    for i, hex_col in enumerate(palette):
        col = i % cols
        row = i // cols
        x = x_start + col * (box_size + 1)
        y = y_start + row * (box_size + 1)

        hex_col = hex_col.lstrip('#')
        r, g, b = tuple(int(hex_col[i:i+2], 16) for i in (0, 2, 4))
        pdf.set_fill_color(r, g, b)
        pdf.set_draw_color(50, 50, 50)
        pdf.rect(x, y, box_size, box_size, 'DF')

    pdf.set_y(y_start + 5 * (box_size + 1) + 5)

    pdf.subheading('Visual Themes')
    pdf.bullet_point('Vibrant & Colorful - Not grimdark; magical and energetic')
    pdf.bullet_point('Chunky Pixel Art - Readable at small sizes, detailed icons')
    pdf.bullet_point('Magic/Spell Emphasis - Projectiles, glowing effects, arcane energy')
    pdf.bullet_point('Action-Oriented - Convey the chaos of fighting hordes')

    # Suggested Elements
    pdf.heading('Suggested Visual Elements')
    pdf.body_text('These are suggestions only - the artist has creative freedom to interpret the game\'s identity.')

    pdf.subheading('Potential Focal Points (pick one or combine)')
    pdf.bullet_point('1. Wand Crafting - Show spell cards/icons combining into a powerful wand')
    pdf.bullet_point('2. Horde Combat - Player character surrounded by enemies, casting spells')
    pdf.bullet_point('3. Spell Effects - Showcase the variety of colorful projectiles/abilities')
    pdf.bullet_point('4. Item Collection - Feature the diverse equipment icons')

    pdf.subheading('Must Include')
    pdf.bullet_point('Game Title: "Trigger Survivors" (or abbreviated if space is tight)')
    pdf.bullet_point('Readable at thumbnail size - Title must be legible at 231x87')

    pdf.subheading('Avoid')
    pdf.bullet_point('Generic "survivor" tropes without the wand-crafting identity')
    pdf.bullet_point('Dark/muddy colors that don\'t represent the vibrant palette')
    pdf.bullet_point('Overly busy compositions that become unreadable at small sizes')

    # Page 3: Reference Images - Text first, then image on next page
    pdf.add_page()
    pdf.heading('Reference Thumbnails')
    pdf.body_text('These references show the quality bar and style range we\'re looking for. The artist can interpret freely within this range.')

    # Reference table FIRST (before image)
    pdf.ln(3)
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_fill_color(69, 41, 63)
    pdf.set_text_color(*WHITE)
    pdf.cell(45, 7, 'Reference', border=1, fill=True)
    pdf.cell(145, 7, 'What We Like About It', border=1, fill=True, ln=True)

    pdf.set_font('Helvetica', '', 9)
    pdf.set_text_color(*BLACK)
    refs = [
        ('Path of Achra', 'Moody silhouette, readable title on dark background'),
        ('Rift Wizard', 'Pixel art sprite showcase, clean black background'),
        ('SNKRX', 'Ultra-minimalist, bold title readability'),
        ('Magicraft', 'Character-centric, magical glow effects'),
        ('Vampire Survivors', 'Dynamic action pose, genre-appropriate energy'),
    ]
    for i, (name, desc) in enumerate(refs):
        fill = i % 2 == 1
        pdf.set_fill_color(249, 249, 249)
        pdf.cell(45, 6, name, border=1, fill=fill)
        pdf.cell(145, 6, desc, border=1, fill=fill, ln=True)

    pdf.ln(5)
    pdf.highlight_box('Style Freedom: Artist may choose anywhere on the spectrum from minimalist (SNKRX) to detailed (Magicraft).')

    # Add reference image on its own page
    pdf.add_page()
    pdf.subheading('Reference Thumbnails Image')
    try:
        if REFERENCE_IMAGE:
            pdf.image(REFERENCE_IMAGE, x=10, y=pdf.get_y() + 5, w=190)
    except Exception as e:
        pdf.body_text(f'[Reference image: {REFERENCE_IMAGE}]')

    # Page 4+: Game Screenshots - Each on its own page
    pdf.add_page()
    pdf.heading('Game Screenshots')
    pdf.body_text('These screenshots show the actual game visuals for reference.')

    # Screenshot 1
    pdf.add_page()
    pdf.subheading('1. Wand Crafting UI')
    pdf.body_text('Shows spell cards, "Delayed Spell" mechanics, action slots')
    try:
        if SCREENSHOT_1:
            pdf.image(SCREENSHOT_1, x=10, y=pdf.get_y() + 3, w=190)
    except Exception as e:
        pdf.body_text(f'[Screenshot: {SCREENSHOT_1}]')

    # Screenshot 2
    pdf.add_page()
    pdf.subheading('2. Inventory System')
    pdf.body_text('Equipment, Wands, Triggers, Actions, Modifiers tabs with pixel art icons')
    try:
        if SCREENSHOT_2:
            pdf.image(SCREENSHOT_2, x=10, y=pdf.get_y() + 3, w=190)
    except Exception as e:
        pdf.body_text(f'[Screenshot: {SCREENSHOT_2}]')

    # Screenshot 3
    pdf.add_page()
    pdf.subheading('3. Gameplay')
    pdf.body_text('Wave-based combat, player character, enemies, colorful backgrounds')
    try:
        if SCREENSHOT_3:
            pdf.image(SCREENSHOT_3, x=10, y=pdf.get_y() + 3, w=190)
    except Exception as e:
        pdf.body_text(f'[Screenshot: {SCREENSHOT_3}]')

    # Final page: Technical Requirements
    pdf.add_page()
    pdf.heading('Technical Requirements')
    pdf.bullet_point('Format: PNG (final), PSD/ASE with layers (source file)')
    pdf.bullet_point('Resolution: Native pixel art resolution with clean scaling (no anti-aliasing on pixel edges)')
    pdf.bullet_point('Transparency: Not required (solid backgrounds preferred)')

    pdf.heading('Timeline & Communication')
    pdf.bullet_point('Revisions: Up to 2 rounds of revisions included')
    pdf.bullet_point('Sketches First: Please provide rough composition sketches before final pixel art')
    pdf.bullet_point('Questions Welcome: Reach out for any clarification on game mechanics or visual direction')

    pdf.heading('Contact')
    pdf.body_text('[Your contact information here]')

    pdf.ln(20)
    pdf.set_font('Helvetica', 'I', 9)
    pdf.set_text_color(*GRAY)
    pdf.cell(0, 10, 'Document generated for artist commission - Trigger Survivors thumbnail art', align='C')

    # Output
    output_path = Path('/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/Trigger_Survivors_Thumbnail_Spec.pdf')
    pdf.output(output_path)
    print(f'PDF created: {output_path}')
    return output_path

if __name__ == '__main__':
    create_spec_pdf()
