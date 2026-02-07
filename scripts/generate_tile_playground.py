#!/usr/bin/env python3
"""
Generate an interactive HTML playground for reviewing and renaming
dungeon-mode and dungeon-437 tileset tiles.
"""

from PIL import Image
import base64
import io
import json
import html

# =============================================================================
# DUNGEON MODE NAME MAPPING (256 tiles)
# Based on dungeon-mode.char and visual inspection
# =============================================================================
DM_NAMES = {
    # Row 0: Basic symbols (0-15)
    # .char: ` ⚉•♥♦♣♠∙♂♀⬚⭦→←↑↓`
    0: "blank",
    1: "icon_target_circle",
    2: "bullet_medium",
    3: "icon_heart_filled",
    4: "icon_diamond_filled",
    5: "icon_club_filled",
    6: "icon_spade_filled",
    7: "bullet_small",
    8: "icon_male",
    9: "icon_female",
    10: "icon_square_dotted",
    11: "arrow_nw",
    12: "arrow_e",
    13: "arrow_w",
    14: "arrow_n",
    15: "arrow_s",

    # Row 1: More symbols (16-31)
    # .char: `█✕∘♡◇⩌⸙…♪♫⸬☝►◄▲▼`
    16: "block_full",
    17: "cross_x_thin",
    18: "circle_small_hollow",
    19: "icon_heart_hollow",
    20: "icon_diamond_hollow",
    21: "icon_union_plus",
    22: "icon_flower",
    23: "ellipsis",
    24: "icon_note_single",
    25: "icon_note_double",
    26: "icon_dots_cross",
    27: "icon_hand_pointing_up",
    28: "triangle_e_filled",
    29: "triangle_w_filled",
    30: "triangle_n_filled",
    31: "triangle_s_filled",

    # Row 2: Punctuation (32-47)
    # .char: `.,!?-+/\()*:[_]^`
    32: "punct_period",
    33: "punct_comma",
    34: "punct_exclamation",
    35: "punct_question",
    36: "punct_hyphen",
    37: "punct_plus",
    38: "punct_slash",
    39: "punct_backslash",
    40: "punct_paren_open",
    41: "punct_paren_close",
    42: "punct_asterisk",
    43: "punct_colon",
    44: "punct_bracket_open",
    45: "punct_underscore",
    46: "punct_bracket_close",
    47: "punct_caret",

    # Row 3: Digits + symbols (48-63)
    # .char: `0123456789⒑;<=>%`
    48: "digit_0", 49: "digit_1", 50: "digit_2", 51: "digit_3",
    52: "digit_4", 53: "digit_5", 54: "digit_6", 55: "digit_7",
    56: "digit_8", 57: "digit_9",
    58: "digit_10_circled",
    59: "punct_semicolon",
    60: "punct_less_than",
    61: "punct_equals",
    62: "punct_greater_than",
    63: "punct_percent",

    # Row 4: @ + Uppercase A-O (64-79)
    # .char: `@ABCDEFGHIJKLMNO`
    64: "punct_at",
    65: "letter_A", 66: "letter_B", 67: "letter_C", 68: "letter_D",
    69: "letter_E", 70: "letter_F", 71: "letter_G", 72: "letter_H",
    73: "letter_I", 74: "letter_J", 75: "letter_K", 76: "letter_L",
    77: "letter_M", 78: "letter_N", 79: "letter_O",

    # Row 5: Uppercase P-Z + symbols (80-95)
    # .char: `PQRSTUVWXYZ'⁈~$&`
    80: "letter_P", 81: "letter_Q", 82: "letter_R", 83: "letter_S",
    84: "letter_T", 85: "letter_U", 86: "letter_V", 87: "letter_W",
    88: "letter_X", 89: "letter_Y", 90: "letter_Z",
    91: "punct_apostrophe",
    92: "punct_interrobang",
    93: "punct_tilde",
    94: "punct_dollar",
    95: "punct_ampersand",

    # Row 6: # + lowercase a-o (96-111)
    # .char: `#abcdefghijklmno`
    96: "punct_hash",
    97: "letter_a", 98: "letter_b", 99: "letter_c", 100: "letter_d",
    101: "letter_e", 102: "letter_f", 103: "letter_g", 104: "letter_h",
    105: "letter_i", 106: "letter_j", 107: "letter_k", 108: "letter_l",
    109: "letter_m", 110: "letter_n", 111: "letter_o",

    # Row 7: lowercase p-z + symbols (112-127)
    # .char: `pqrstuvwxyz"⁉️≈₲Ŀ`
    112: "letter_p", 113: "letter_q", 114: "letter_r", 115: "letter_s",
    116: "letter_t", 117: "letter_u", 118: "letter_v", 119: "letter_w",
    120: "letter_x", 121: "letter_y", 122: "letter_z",
    123: "punct_quote_double",
    124: "punct_interrobang_inv",
    125: "punct_approx",
    126: "icon_guarani_currency",
    127: "icon_L_stroke",

    # =========================================================================
    # Row 8: Single walls + quadrants + slopes + icons (128-143)
    # .char: `│─▗▖╱╲🭋🭀🭊🬿⌂♖□⩀⟏⟎`
    # =========================================================================
    128: "wall1_ns",          # │ vertical single wall (connects N-S)
    129: "wall1_ew",          # ─ horizontal single wall (connects E-W)
    130: "quadrant_se",       # ▗ filled lower-right quadrant
    131: "quadrant_sw",       # ▖ filled lower-left quadrant
    132: "diagonal_ne_sw",    # ╱ forward diagonal line
    133: "diagonal_nw_se",    # ╲ backward diagonal line
    134: "slope_rise_e_small",  # 🭋 smooth slope rising east (small)
    135: "slope_rise_e_med",    # 🭀 smooth slope rising east (medium)
    136: "slope_rise_e_large",  # 🭊 smooth slope rising east (large)
    137: "slope_rise_w_large",  # 🬿 smooth slope rising west (large)
    138: "icon_house",          # ⌂ house/home
    139: "icon_castle_rook",    # ♖ chess rook / castle tower
    140: "icon_square_hollow",  # □ empty square outline
    141: "icon_circle_bar",     # ⩀ circle with horizontal bar
    142: "icon_fishtail_e",     # ⟏ right-facing fish tail / bracket
    143: "icon_fishtail_w",     # ⟎ left-facing fish tail / bracket

    # =========================================================================
    # Row 9: Double walls + quadrants + slopes + icons (144-159)
    # .char: `║═▝▘⋱⋰🭅🭐🭈🭆🭑🬽†⛨☥⚱`
    # =========================================================================
    144: "wall2_ns",            # ║ vertical double wall (connects N-S)
    145: "wall2_ew",            # ═ horizontal double wall (connects E-W)
    146: "quadrant_ne",         # ▝ filled upper-right quadrant
    147: "quadrant_nw",         # ▘ filled upper-left quadrant
    148: "dots_diagonal_se",    # ⋱ dots descending right
    149: "dots_diagonal_ne",    # ⋰ dots ascending right
    150: "slope_rise_w_small",  # 🭅 smooth slope rising west (small)
    151: "slope_rise_w_med",    # 🭐 smooth slope rising west (medium)
    152: "slope_fall_e_large",  # 🭈 smooth curve/slope variant
    153: "slope_fall_w_large",  # 🭆 smooth curve/slope variant
    154: "slope_fall_w_med",    # 🭑 smooth curve/slope variant
    155: "slope_fall_w_small",  # 🬽 smooth curve/slope variant
    156: "icon_dagger_cross",   # † dagger / cross
    157: "icon_shield_cross",   # ⛨ shield with cross
    158: "icon_ankh",           # ☥ ankh (Egyptian cross)
    159: "icon_urn_funerary",   # ⚱ funeral urn

    # =========================================================================
    # Row 10: Half blocks + single corners + double corners + icons (160-175)
    # .char: `▄▐╳┌┬┐╔╦╗🭽▔🭾⧇⊔⊙⚷`
    # =========================================================================
    160: "block_lower_half",      # ▄ lower half filled
    161: "block_right_half",      # ▐ right half filled
    162: "diagonal_cross_x",      # ╳ X-shaped diagonal cross
    163: "wall1_se",              # ┌ single corner: connects S and E
    164: "wall1_sew",             # ┬ single tee: connects S, E, W
    165: "wall1_sw",              # ┐ single corner: connects S and W
    166: "wall2_se",              # ╔ double corner: connects S and E
    167: "wall2_sew",             # ╦ double tee: connects S, E, W
    168: "wall2_sw",              # ╗ double corner: connects S and W
    169: "edge_wedge_nw",         # 🭽 thin wedge/edge NW
    170: "edge_top_thin",         # ▔ upper 1/8 block (thin top edge)
    171: "edge_wedge_ne",         # 🭾 thin wedge/edge NE
    172: "icon_window_target",    # ⧇ squared small circle (window)
    173: "icon_cup_open_top",     # ⊔ square cup opening up
    174: "icon_bullseye_hollow",  # ⊙ circled dot operator
    175: "icon_key",              # ⚷ key / chiron symbol

    # =========================================================================
    # Row 11: Shades + single tees + double tees + edge bars + icons (176-191)
    # .char: `░▒▓├┼┤╠╬╣▏⛶▕★‸◉⊶`
    # =========================================================================
    176: "shade_light",           # ░ 25% shade fill
    177: "shade_medium",          # ▒ 50% shade fill
    178: "shade_dark",            # ▓ 75% shade fill
    179: "wall1_nse",             # ├ single tee: connects N, S, E
    180: "wall1_nsew",            # ┼ single cross: connects all 4
    181: "wall1_nsw",             # ┤ single tee: connects N, S, W
    182: "wall2_nse",             # ╠ double tee: connects N, S, E
    183: "wall2_nsew",            # ╬ double cross: connects all 4
    184: "wall2_nsw",             # ╣ double tee: connects N, S, W
    185: "edge_left_thin",        # ▏ left 1/8 block (thin left edge)
    186: "icon_target_square",    # ⛶ square four corners
    187: "edge_right_thin",       # ▕ right 1/8 block (thin right edge)
    188: "icon_star_filled",      # ★ filled five-pointed star
    189: "icon_caret_below",      # ‸ caret insertion point
    190: "icon_bullseye_filled",  # ◉ fisheye / filled bullseye
    191: "icon_triple_bar_dot",   # ⊶ circle with three horizontal bars

    # =========================================================================
    # Row 12: 3/4 blocks + single bot corners + double bot corners + icons (192-207)
    # .char: `▛🮎▜└┴┘╚╩╝🭼▁🭿⛼∿🝙🝚`
    # =========================================================================
    192: "block_three_quarter_ne_nw_sw",  # ▛ missing SE quadrant
    193: "diagonal_halftone_se",   # 🮎 diagonal halftone transition
    194: "block_three_quarter_ne_nw_se",  # ▜ missing SW quadrant
    195: "wall1_ne",               # └ single corner: connects N and E
    196: "wall1_new",              # ┴ single tee: connects N, E, W
    197: "wall1_nw",               # ┘ single corner: connects N and W
    198: "wall2_ne",               # ╚ double corner: connects N and E
    199: "wall2_new",              # ╩ double tee: connects N, E, W
    200: "wall2_nw",               # ╝ double corner: connects N and W
    201: "edge_wedge_sw",          # 🭼 thin wedge/edge SW
    202: "edge_bottom_thin",       # ▁ lower 1/8 block (thin bottom edge)
    203: "edge_wedge_se",          # 🭿 thin wedge/edge SE
    204: "icon_hazard_lightning",   # ⛼ headstone / hazard
    205: "icon_wave_sine",          # ∿ sine wave
    206: "icon_alchemy_cross",      # 🝙 alchemical symbol
    207: "icon_alchemy_cup",        # 🝚 alchemical crucible

    # =========================================================================
    # Row 13: Fill patterns + mixed walls top + icons (208-223)
    # .char: `🮌🮕🮍╓╥╖╒╤╕◲◱◨⚇🕱⫙⌤`
    # Mixed: 2v1h = double vertical, single horizontal
    #        1v2h = single vertical, double horizontal
    # =========================================================================
    208: "fill_diagonal_forward",     # 🮌 forward diagonal stripe fill
    209: "fill_checkerboard",          # 🮕 checkerboard fill pattern
    210: "fill_diagonal_backward",     # 🮍 backward diagonal stripe fill
    211: "wall_2v1h_se",   # ╓ mixed corner SE (double vert, single horiz)
    212: "wall_2v1h_sew",  # ╥ mixed tee S (double vert, single horiz)
    213: "wall_2v1h_sw",   # ╖ mixed corner SW (double vert, single horiz)
    214: "wall_1v2h_se",   # ╒ mixed corner SE (single vert, double horiz)
    215: "wall_1v2h_sew",  # ╤ mixed tee S (single vert, double horiz)
    216: "wall_1v2h_sw",   # ╕ mixed corner SW (single vert, double horiz)
    217: "triangle_quadrant_se",   # ◲ white square with lower-right triangle
    218: "triangle_quadrant_ne",   # ◱ white square with upper-right triangle
    219: "block_right_half_black", # ◨ square with right half black
    220: "icon_two_circles",       # ⚇ white circle with two dots
    221: "icon_skull_coffin",      # 🕱 skull and crossbones in coffin
    222: "icon_horiz_bar_square",  # ⫙ double bar in square
    223: "icon_return_enter",      # ⌤ return/enter symbol

    # =========================================================================
    # Row 14: 3/4 blocks + mixed walls mid + icons (224-239)
    # .char: `▙🮏▟╟╫╢╞╪╡◳◰⬓⛑☠⋒⟁`
    # =========================================================================
    224: "block_three_quarter_nw_sw_se",  # ▙ missing NE quadrant
    225: "diagonal_halftone_ne",   # 🮏 diagonal halftone transition
    226: "block_three_quarter_ne_sw_se",  # ▟ missing NW quadrant
    227: "wall_2v1h_nse",  # ╟ mixed tee E (double vert, single horiz)
    228: "wall_2v1h_nsew", # ╫ mixed cross (double vert, single horiz)
    229: "wall_2v1h_nsw",  # ╢ mixed tee W (double vert, single horiz)
    230: "wall_1v2h_nse",  # ╞ mixed tee E (single vert, double horiz)
    231: "wall_1v2h_nsew", # ╪ mixed cross (single vert, double horiz)
    232: "wall_1v2h_nsw",  # ╡ mixed tee W (single vert, double horiz)
    233: "triangle_quadrant_nw",   # ◳ white square with upper-left triangle
    234: "triangle_quadrant_sw",   # ◰ white square with lower-left triangle
    235: "triangle_half_lower",    # ⬓ half-filled triangle
    236: "icon_helmet_rescue",     # ⛑ helmet with cross
    237: "icon_skull_crossbones",  # ☠ skull and crossbones
    238: "icon_arch_intersection", # ⋒ intersection / arch shape
    239: "icon_triangle_with_bar", # ⟁ white triangle with small triangle

    # =========================================================================
    # Row 15: Stripe fills + mixed walls bot + misc symbols (240-255)
    # .char: `▤▥˭╙╨╜╘╧╛⊥⊤⊡¨ˆʺ∵`
    # =========================================================================
    240: "fill_horizontal_stripes",  # ▤ horizontal line fill
    241: "fill_vertical_stripes",    # ▥ vertical line fill
    242: "icon_modifier_equals",     # ˭ modifier equals
    243: "wall_2v1h_ne",  # ╙ mixed corner NE (double vert, single horiz)
    244: "wall_2v1h_new", # ╨ mixed tee N (double vert, single horiz)
    245: "wall_2v1h_nw",  # ╜ mixed corner NW (double vert, single horiz)
    246: "wall_1v2h_ne",  # ╘ mixed corner NE (single vert, double horiz)
    247: "wall_1v2h_new", # ╧ mixed tee N (single vert, double horiz)
    248: "wall_1v2h_nw",  # ╛ mixed corner NW (single vert, double horiz)
    249: "icon_perpendicular",  # ⊥ up tack / perpendicular
    250: "icon_tack_down",      # ⊤ down tack
    251: "icon_squared_dot",    # ⊡ squared dot operator
    252: "icon_diaeresis",      # ¨ diaeresis / umlaut
    253: "icon_circumflex",     # ˆ modifier circumflex
    254: "icon_double_prime",   # ʺ double prime / ditto
    255: "icon_because_dots",   # ∵ because (three dots triangle)
}

# Unicode character mapping from .char file
DM_CHARS_RAW = [
    " ⚉•♥♦♣♠∙♂♀⬚⭦→←↑↓",
    "█✕∘♡◇⩌⸙…♪♫⸬☝►◄▲▼",
    ".,!?-+/\\()*:[_]^",
    "0123456789⒑;<=>%",
    "@ABCDEFGHIJKLMNO",
    "PQRSTUVWXYZ'⁈~$&",
    "#abcdefghijklmno",
    "pqrstuvwxyz\"⁉️≈₲Ŀ",
    "│─▗▖╱╲🭋🭀🭊🬿⌂♖□⩀⟏⟎",
    "║═▝▘⋱⋰🭅🭐🭈🭆🭑🬽†⛨☥⚱",
    "▄▐╳┌┬┐╔╦╗🭽▔🭾⧇⊔⊙⚷",
    "░▒▓├┼┤╠╬╣▏⛶▕★‸◉⊶",
    "▛🮎▜└┴┘╚╩╝🭼▁🭿⛼∿🝙🝚",
    "🮌🮕🮍╓╥╖╒╤╕◲◱◨⚇🕱⫙⌤",
    "▙🮏▟╟╫╢╞╪╡◳◰⬓⛑☠⋒⟁",
    "▤▥˭╙╨╜╘╧╛⊥⊤⊡¨ˆʺ∵",
]

# =============================================================================
# DUNGEON 437 NAME MAPPING (256 tiles)
# Based on dungeon-437.char (standard CP437)
# =============================================================================
D437_NAMES = {
    # Row 0: Control characters visualized (0-15)
    0: "blank_null",
    1: "icon_smiley",
    2: "icon_smiley_inverse",
    3: "icon_heart_filled",
    4: "icon_diamond_filled",
    5: "icon_club_filled",
    6: "icon_spade_filled",
    7: "bullet_medium",
    8: "bullet_inverse",
    9: "circle_hollow",
    10: "circle_inverse",
    11: "icon_male",
    12: "icon_female",
    13: "icon_note_single",
    14: "icon_note_double",
    15: "icon_sun",

    # Row 1 (16-31)
    16: "triangle_e_filled",
    17: "triangle_w_filled",
    18: "arrow_ns_double",
    19: "punct_double_exclaim",
    20: "icon_paragraph",
    21: "icon_section",
    22: "bar_horizontal_thick",
    23: "arrow_ns_with_base",
    24: "arrow_n",
    25: "arrow_s",
    26: "arrow_e",
    27: "arrow_w",
    28: "icon_right_angle",
    29: "arrow_ew_double",
    30: "triangle_n_filled",
    31: "triangle_s_filled",

    # Row 2: ASCII printable (32-47)
    32: "space",
    33: "punct_exclamation",
    34: "punct_quote_double",
    35: "punct_hash",
    36: "punct_dollar",
    37: "punct_percent",
    38: "punct_ampersand",
    39: "punct_apostrophe",
    40: "punct_paren_open",
    41: "punct_paren_close",
    42: "punct_asterisk",
    43: "punct_plus",
    44: "punct_comma",
    45: "punct_hyphen",
    46: "punct_period",
    47: "punct_slash",

    # Row 3: Digits (48-63)
    48: "digit_0", 49: "digit_1", 50: "digit_2", 51: "digit_3",
    52: "digit_4", 53: "digit_5", 54: "digit_6", 55: "digit_7",
    56: "digit_8", 57: "digit_9",
    58: "punct_colon",
    59: "punct_semicolon",
    60: "punct_less_than",
    61: "punct_equals",
    62: "punct_greater_than",
    63: "punct_question",

    # Row 4: @ + Uppercase (64-79)
    64: "punct_at",
    65: "letter_A", 66: "letter_B", 67: "letter_C", 68: "letter_D",
    69: "letter_E", 70: "letter_F", 71: "letter_G", 72: "letter_H",
    73: "letter_I", 74: "letter_J", 75: "letter_K", 76: "letter_L",
    77: "letter_M", 78: "letter_N", 79: "letter_O",

    # Row 5: Uppercase + symbols (80-95)
    80: "letter_P", 81: "letter_Q", 82: "letter_R", 83: "letter_S",
    84: "letter_T", 85: "letter_U", 86: "letter_V", 87: "letter_W",
    88: "letter_X", 89: "letter_Y", 90: "letter_Z",
    91: "punct_bracket_open",
    92: "punct_backslash",
    93: "punct_bracket_close",
    94: "punct_caret",
    95: "punct_underscore",

    # Row 6: Backtick + lowercase (96-111)
    96: "punct_backtick",
    97: "letter_a", 98: "letter_b", 99: "letter_c", 100: "letter_d",
    101: "letter_e", 102: "letter_f", 103: "letter_g", 104: "letter_h",
    105: "letter_i", 106: "letter_j", 107: "letter_k", 108: "letter_l",
    109: "letter_m", 110: "letter_n", 111: "letter_o",

    # Row 7: lowercase + symbols (112-127)
    112: "letter_p", 113: "letter_q", 114: "letter_r", 115: "letter_s",
    116: "letter_t", 117: "letter_u", 118: "letter_v", 119: "letter_w",
    120: "letter_x", 121: "letter_y", 122: "letter_z",
    123: "punct_brace_open",
    124: "punct_pipe",
    125: "punct_brace_close",
    126: "punct_tilde",
    127: "icon_house",

    # Row 8: Extended Latin upper (128-143)
    128: "accent_C_cedilla",
    129: "accent_u_diaeresis",
    130: "accent_e_acute",
    131: "accent_a_circumflex",
    132: "accent_a_diaeresis",
    133: "accent_a_grave",
    134: "accent_a_ring",
    135: "accent_c_cedilla",
    136: "accent_e_circumflex",
    137: "accent_e_diaeresis",
    138: "accent_e_grave",
    139: "accent_i_diaeresis",
    140: "accent_i_circumflex",
    141: "accent_i_grave",
    142: "accent_A_diaeresis",
    143: "accent_A_ring",

    # Row 9: Extended Latin (144-159)
    144: "accent_E_acute",
    145: "ligature_ae",
    146: "ligature_AE",
    147: "accent_o_circumflex",
    148: "accent_o_diaeresis",
    149: "accent_o_grave",
    150: "accent_u_circumflex",
    151: "accent_u_grave",
    152: "accent_y_diaeresis",
    153: "accent_O_diaeresis",
    154: "accent_U_diaeresis",
    155: "icon_cent",
    156: "icon_pound_sterling",
    157: "icon_yen",
    158: "icon_peseta",
    159: "icon_florin",

    # Row 10: More extended + inverted marks (160-175)
    160: "accent_a_acute",
    161: "accent_i_acute",
    162: "accent_o_acute",
    163: "accent_u_acute",
    164: "accent_n_tilde",
    165: "accent_N_tilde",
    166: "icon_ordinal_fem",
    167: "icon_ordinal_masc",
    168: "punct_question_inverted",
    169: "icon_corner_tl_neg",
    170: "icon_corner_tr_neg",
    171: "icon_fraction_half",
    172: "icon_fraction_quarter",
    173: "punct_exclaim_inverted",
    174: "punct_guillemet_open",
    175: "punct_guillemet_close",

    # Row 11: Shades + box drawing single/mixed (176-191)
    # .char: `░▒▓│┤╡╢╖╕╣║╗╝╜╛┐`
    176: "shade_light",
    177: "shade_medium",
    178: "shade_dark",
    179: "wall1_ns",            # │
    180: "wall1_nsw",           # ┤
    181: "wall_1v2h_nsw",       # ╡ single vert + double horiz left
    182: "wall_2v1h_nsw",       # ╢ double vert + single horiz left
    183: "wall_2v1h_sw",        # ╖
    184: "wall_1v2h_sw",        # ╕
    185: "wall2_nsw",           # ╣
    186: "wall2_ns",            # ║
    187: "wall2_sw",            # ╗
    188: "wall2_nw",            # ╝
    189: "wall_2v1h_nw",        # ╜
    190: "wall_1v2h_nw",        # ╛
    191: "wall1_sw",            # ┐

    # Row 12: Box drawing continued (192-207)
    # .char: `└┴┬├─┼╞╟╚╔╩╦╠═╬╧`
    192: "wall1_ne",            # └
    193: "wall1_new",           # ┴
    194: "wall1_sew",           # ┬
    195: "wall1_nse",           # ├
    196: "wall1_ew",            # ─
    197: "wall1_nsew",          # ┼
    198: "wall_1v2h_nse",       # ╞
    199: "wall_2v1h_nse",       # ╟
    200: "wall2_ne",            # ╚
    201: "wall2_se",            # ╔
    202: "wall2_new",           # ╩
    203: "wall2_sew",           # ╦
    204: "wall2_nse",           # ╠
    205: "wall2_ew",            # ═
    206: "wall2_nsew",          # ╬
    207: "wall_1v2h_new",       # ╧

    # Row 13: Box drawing continued + blocks (208-223)
    # .char: `╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀`
    208: "wall_2v1h_new",       # ╨
    209: "wall_1v2h_sew",       # ╤
    210: "wall_2v1h_sew",       # ╥
    211: "wall_2v1h_ne",        # ╙
    212: "wall_1v2h_ne",        # ╘
    213: "wall_1v2h_se",        # ╒
    214: "wall_2v1h_se",        # ╓
    215: "wall_2v1h_nsew",      # ╫
    216: "wall_1v2h_nsew",      # ╪
    217: "wall1_nw",            # ┘
    218: "wall1_se",            # ┌
    219: "block_full",          # █
    220: "block_lower_half",    # ▄
    221: "block_left_half",     # ▌
    222: "block_right_half",    # ▐
    223: "block_upper_half",    # ▀

    # Row 14: Greek letters (224-239)
    # .char: `αßΓπΣσµτΦΘΩδ∞φε∩`
    224: "greek_alpha",
    225: "greek_beta_sharp_s",
    226: "greek_gamma_upper",
    227: "greek_pi",
    228: "greek_sigma_upper",
    229: "greek_sigma_lower",
    230: "greek_mu",
    231: "greek_tau",
    232: "greek_phi_upper",
    233: "greek_theta",
    234: "greek_omega",
    235: "greek_delta",
    236: "icon_infinity",
    237: "greek_phi_lower",
    238: "greek_epsilon",
    239: "icon_intersection",

    # Row 15: Math symbols (240-255)
    # .char: `≡±≥≤⌠⌡÷≈°∙·√ⁿ²■□`
    240: "icon_triple_bar",
    241: "icon_plus_minus",
    242: "icon_greater_equal",
    243: "icon_less_equal",
    244: "icon_integral_top",
    245: "icon_integral_bottom",
    246: "icon_divide",
    247: "icon_approx",
    248: "icon_degree",
    249: "bullet_small",
    250: "icon_middle_dot",
    251: "icon_sqrt",
    252: "icon_superscript_n",
    253: "icon_superscript_2",
    254: "block_small_filled",
    255: "blank_nbsp",
}

D437_CHARS_RAW = [
    " ☺☻♥♦♣♠•◘○◙♂♀♪♫☼",
    "►◄↕‼¶§▬↨↑↓→←∟↔▲▼",
    ' !"#$%&\'()*+,-./',
    "0123456789:;<=>?",
    "@ABCDEFGHIJKLMNO",
    "PQRSTUVWXYZ[\\]^_",
    "`abcdefghijklmno",
    "pqrstuvwxyz{|}~⌂",
    "ÇüéâäàåçêëèïîìÄÅ",
    "ÉæÆôöòûùÿÖÜ¢£¥₧ƒ",
    "áíóúñÑªº¿⌐¬½¼¡«»",
    "░▒▓│┤╡╢╖╕╣║╗╝╜╛┐",
    "└┴┬├─┼╞╟╚╔╩╦╠═╬╧",
    "╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀",
    "αßΓπΣσµτΦΘΩδ∞φε∩",
    "≡±≥≤⌠⌡÷≈°∙·√ⁿ²■□",
]


# =============================================================================
# Category classification for color-coding in the playground
# =============================================================================
def get_category(name):
    if name.startswith("wall"):
        return "wall"
    elif name.startswith("block") or name.startswith("quadrant"):
        return "block"
    elif name.startswith("shade") or name.startswith("fill"):
        return "shade"
    elif name.startswith("edge") or name.startswith("slope"):
        return "edge"
    elif name.startswith("diagonal"):
        return "diagonal"
    elif name.startswith("letter_") or name.startswith("digit_"):
        return "text"
    elif name.startswith("punct_"):
        return "punct"
    elif name.startswith("arrow") or name.startswith("triangle"):
        return "arrow"
    elif name.startswith("icon_") or name.startswith("accent_") or name.startswith("ligature_") or name.startswith("greek_"):
        return "icon"
    elif name.startswith("blank") or name.startswith("space") or name.startswith("bullet") or name.startswith("circle"):
        return "basic"
    else:
        return "other"


CATEGORY_COLORS = {
    "wall":     "#4488ff",
    "block":    "#44cc66",
    "shade":    "#888888",
    "edge":     "#66cccc",
    "diagonal": "#cc66cc",
    "text":     "#999966",
    "punct":    "#996633",
    "arrow":    "#ff8844",
    "icon":     "#cc4466",
    "basic":    "#666666",
    "other":    "#555555",
}


def parse_char_rows(rows):
    """Parse .char row strings into index->char mapping."""
    chars = {}
    idx = 0
    for row in rows:
        # Handle multi-codepoint characters (emoji with variation selectors)
        i = 0
        col = 0
        while col < 16 and i < len(row):
            ch = row[i]
            i += 1
            # Consume variation selectors and zero-width joiners
            while i < len(row) and ord(row[i]) in (0xFE0F, 0xFE0E, 0x200D, 0x20E3):
                ch += row[i]
                i += 1
            chars[idx] = ch
            idx += 1
            col += 1
    return chars


def tile_to_base64(img, x, y, size=8, make_transparent=True):
    """Extract a tile from the tilesheet and return as base64 PNG."""
    tile = img.crop((x, y, x + size, y + size))
    if make_transparent:
        tile = tile.convert("RGBA")
        pixels = tile.load()
        for py in range(size):
            for px in range(size):
                r, g, b, a = pixels[px, py]
                if r == 0 and g == 0 and b == 0:
                    pixels[px, py] = (0, 0, 0, 0)
    buf = io.BytesIO()
    tile.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode('ascii')


def sheet_to_base64(img):
    """Encode full tilesheet as base64 PNG."""
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode('ascii')


def generate_playground_html():
    # Load tilesheets
    dm_img = Image.open("/Users/joshuashin/Downloads/dungeonmode 2/playscii/charsets/dungeon-mode.png").convert("RGBA")
    d437_img = Image.open("/Users/joshuashin/Downloads/dungeonmode 2/playscii/charsets/dungeon-437.png").convert("RGBA")

    # Parse character mappings
    dm_chars = parse_char_rows(DM_CHARS_RAW)
    d437_chars = parse_char_rows(D437_CHARS_RAW)

    # Generate tile data for both tilesets
    tile_size = 8
    cols = 16

    dm_tiles = []
    for idx in range(256):
        row = idx // cols
        col = idx % cols
        x = col * tile_size
        y = row * tile_size
        name = DM_NAMES.get(idx, f"unknown_{idx}")
        char = dm_chars.get(idx, "?")
        cat = get_category(name)
        b64 = tile_to_base64(dm_img, x, y)
        # Also get the old name from existing files
        dm_tiles.append({
            "idx": idx,
            "row": row,
            "col": col,
            "name": name,
            "char": char,
            "cat": cat,
            "b64": b64,
        })

    d437_tiles = []
    for idx in range(256):
        row = idx // cols
        col = idx % cols
        x = col * tile_size
        y = row * tile_size
        name = D437_NAMES.get(idx, f"unknown_{idx}")
        char = d437_chars.get(idx, "?")
        cat = get_category(name)
        b64 = tile_to_base64(d437_img, x, y)
        d437_tiles.append({
            "idx": idx,
            "row": row,
            "col": col,
            "name": name,
            "char": char,
            "cat": cat,
            "b64": b64,
        })

    # Encode full sheets (without transparency, for display)
    dm_sheet_b64 = sheet_to_base64(dm_img)
    d437_sheet_b64 = sheet_to_base64(d437_img)

    # Generate clean Goblin Tunnels minimap composite (5x5 tiles = 40x40 px)
    import numpy as np
    dm_arr = np.array(dm_img)
    pal_path = "/Users/joshuashin/Downloads/dungeonmode 2/playscii/palettes/dungeon-pal.png"
    pal_arr = np.array(Image.open(pal_path).convert("RGBA"))
    dm_palette = [tuple(pal_arr[0, i]) for i in range(pal_arr.shape[1])]
    scene_path = "/Users/joshuashin/Downloads/dungeonmode 2/playscii/art/goblin-tunnels.psci"
    with open(scene_path) as sf:
        scene_data = json.load(sf)
    scene_w = scene_data["width"]
    scene_tiles = scene_data["frames"][0]["layers"][0]["tiles"]

    def _get_tile_px(char_idx):
        r, c = char_idx // 16, char_idx % 16
        return dm_arr[r*8:(r+1)*8, c*8:(c+1)*8].copy()

    # Name-to-index lookup for minimap composites
    _name_to_idx = {v: int(k) for k, v in DM_NAMES.items()}

    def _render_minimap_composite(grid, fg_color=(255,255,255,255), bg_color=(0,0,0,255), add_door_tips=True):
        """Render a minimap tile grid as a clean composite PNG with edge clipping and door tips."""
        rows = len(grid)
        cols = len(grid[0])
        h, w = rows * 8, cols * 8
        comp = np.zeros((h, w, 4), dtype=np.uint8)
        # Fill background
        for y in range(h):
            for x in range(w):
                comp[y, x] = np.array(bg_color[:4], dtype=np.uint8)

        # Track which pixels are wall
        wall_mask = np.zeros((h, w), dtype=bool)

        for mr in range(rows):
            for mc in range(cols):
                name = grid[mr][mc]
                if not name:
                    continue
                char_idx = _name_to_idx.get(name, -1)
                if char_idx < 0:
                    continue
                tpx = _get_tile_px(char_idx)
                for ty in range(8):
                    for tx in range(8):
                        rv, gv, bv, av = tpx[ty, tx]
                        is_wall = av > 128 and (int(rv)+int(gv)+int(bv)) > 100
                        # Clean edges: rightmost col only left-column, bottom row only top-row
                        if is_wall and mc == cols - 1 and tx > 0:
                            is_wall = False
                        if is_wall and mr == rows - 1 and ty > 0:
                            is_wall = False
                        if is_wall:
                            py, px_ = mr*8+ty, mc*8+tx
                            comp[py, px_] = np.array(fg_color[:4], dtype=np.uint8)
                            wall_mask[py, px_] = True

        # Add perpendicular door tips on outer walls
        if add_door_tips:
            right_x = (cols - 1) * 8  # right wall x coordinate
            bottom_y = (rows - 1) * 8  # bottom wall y coordinate
            # Right wall: scan for gap→wall and wall→gap transitions
            for y in range(1, bottom_y):
                if wall_mask[y, right_x] and not wall_mask[y-1, right_x]:
                    # wall resumes after gap — add tip 1px into room
                    if right_x > 0 and not wall_mask[y, right_x-1]:
                        comp[y, right_x-1] = np.array(fg_color[:4], dtype=np.uint8)
                        wall_mask[y, right_x-1] = True
                if not wall_mask[y, right_x] and wall_mask[y-1, right_x]:
                    # gap starts after wall — add tip on the wall pixel above
                    if right_x > 0 and not wall_mask[y-1, right_x-1]:
                        comp[y-1, right_x-1] = np.array(fg_color[:4], dtype=np.uint8)
                        wall_mask[y-1, right_x-1] = True
            # Left wall: scan for gap→wall and wall→gap transitions
            for y in range(1, bottom_y):
                if wall_mask[y, 0] and not wall_mask[y-1, 0]:
                    if 0 < w-1 and not wall_mask[y, 1]:
                        comp[y, 1] = np.array(fg_color[:4], dtype=np.uint8)
                        wall_mask[y, 1] = True
                if not wall_mask[y, 0] and wall_mask[y-1, 0]:
                    if not wall_mask[y-1, 1]:
                        comp[y-1, 1] = np.array(fg_color[:4], dtype=np.uint8)
                        wall_mask[y-1, 1] = True
            # Bottom wall: scan for gap→wall and wall→gap transitions
            for x in range(1, right_x):
                if wall_mask[bottom_y, x] and not wall_mask[bottom_y, x-1]:
                    if bottom_y > 0 and not wall_mask[bottom_y-1, x]:
                        comp[bottom_y-1, x] = np.array(fg_color[:4], dtype=np.uint8)
                        wall_mask[bottom_y-1, x] = True
                if not wall_mask[bottom_y, x] and wall_mask[bottom_y, x-1]:
                    if not wall_mask[bottom_y-1, x-1]:
                        comp[bottom_y-1, x-1] = np.array(fg_color[:4], dtype=np.uint8)
                        wall_mask[bottom_y-1, x-1] = True
            # Top wall: scan for gap→wall and wall→gap transitions
            for x in range(1, right_x):
                if wall_mask[0, x] and not wall_mask[0, x-1]:
                    if not wall_mask[1, x]:
                        comp[1, x] = np.array(fg_color[:4], dtype=np.uint8)
                        wall_mask[1, x] = True
                if not wall_mask[0, x] and wall_mask[0, x-1]:
                    if not wall_mask[1, x-1]:
                        comp[1, x-1] = np.array(fg_color[:4], dtype=np.uint8)
                        wall_mask[1, x-1] = True

        buf = io.BytesIO()
        Image.fromarray(comp).save(buf, format='PNG')
        return base64.b64encode(buf.getvalue()).decode('ascii'), w, h

    # Generate minimap composites
    minimap_solid_b64, minimap_solid_w, minimap_solid_h = _render_minimap_composite([
        ['edge_wedge_nw', 'edge_top_thin', 'edge_top_thin', 'edge_left_thin'],
        ['edge_left_thin', None, None, 'edge_left_thin'],
        ['edge_left_thin', None, None, 'edge_left_thin'],
        ['edge_top_thin', 'edge_top_thin', 'edge_top_thin', 'edge_wedge_se']
    ])
    minimap_door_b64, minimap_door_w, minimap_door_h = _render_minimap_composite([
        ['edge_wedge_nw', 'edge_top_thin', 'edge_top_thin', 'edge_left_thin'],
        ['edge_left_thin', None, None, 'edge_right_thin'],
        ['edge_left_thin', None, None, 'edge_left_thin'],
        ['edge_top_thin', 'edge_top_thin', 'edge_top_thin', 'edge_wedge_se']
    ])
    minimap_two_b64, minimap_two_w, minimap_two_h = _render_minimap_composite([
        ['edge_wedge_nw', 'edge_top_thin', 'edge_wedge_nw', 'edge_top_thin', 'edge_left_thin'],
        ['edge_left_thin', None, 'edge_right_thin', None, 'edge_left_thin'],
        ['edge_top_thin', 'edge_top_thin', 'edge_top_thin', 'edge_top_thin', 'edge_wedge_se']
    ])

    # Goblin Tunnels composite with dungeon palette colors
    gt_grid = []
    for mr in range(5):
        row = []
        for mc in range(5):
            st = scene_tiles[(mr + 1) * scene_w + (mc + 1)]
            row.append(DM_NAMES.get(st.get("char", 0), None))
        gt_grid.append(row)
    # Use per-cell colors from scene
    gt_h, gt_w = 40, 40
    gt_comp = np.zeros((gt_h, gt_w, 4), dtype=np.uint8)
    gt_wall_mask = np.zeros((gt_h, gt_w), dtype=bool)
    for mr in range(5):
        for mc in range(5):
            st = scene_tiles[(mr + 1) * scene_w + (mc + 1)]
            fg = dm_palette[st.get("fg", 0)] if st.get("fg", 0) < len(dm_palette) else (255,255,255,255)
            bg = dm_palette[st.get("bg", 0)] if st.get("bg", 0) < len(dm_palette) else (0,0,0,255)
            tpx = _get_tile_px(st.get("char", 0))
            for ty in range(8):
                for tx in range(8):
                    rv, gv, bv, av = tpx[ty, tx]
                    is_wall = av > 128 and (int(rv)+int(gv)+int(bv)) > 100
                    if is_wall and mc == 4 and tx > 0:
                        is_wall = False
                    if is_wall and mr == 4 and ty > 0:
                        is_wall = False
                    py, px_ = mr*8+ty, mc*8+tx
                    if is_wall:
                        gt_comp[py, px_] = np.array(fg[:4], dtype=np.uint8)
                        gt_wall_mask[py, px_] = True
                    else:
                        gt_comp[py, px_] = np.array(bg[:4], dtype=np.uint8)
    # Door tips for goblin tunnels (use fg color 14 = olive)
    gt_fg = np.array(dm_palette[14][:4], dtype=np.uint8)
    right_x, bottom_y = 4*8, 4*8
    for y in range(1, bottom_y):
        if gt_wall_mask[y, right_x] and not gt_wall_mask[y-1, right_x]:
            if right_x > 0 and not gt_wall_mask[y, right_x-1]:
                gt_comp[y, right_x-1] = gt_fg; gt_wall_mask[y, right_x-1] = True
        if not gt_wall_mask[y, right_x] and gt_wall_mask[y-1, right_x]:
            if right_x > 0 and not gt_wall_mask[y-1, right_x-1]:
                gt_comp[y-1, right_x-1] = gt_fg; gt_wall_mask[y-1, right_x-1] = True
    for y in range(1, bottom_y):
        if gt_wall_mask[y, 0] and not gt_wall_mask[y-1, 0]:
            if not gt_wall_mask[y, 1]:
                gt_comp[y, 1] = gt_fg; gt_wall_mask[y, 1] = True
        if not gt_wall_mask[y, 0] and gt_wall_mask[y-1, 0]:
            if not gt_wall_mask[y-1, 1]:
                gt_comp[y-1, 1] = gt_fg; gt_wall_mask[y-1, 1] = True
    for x in range(1, right_x):
        if gt_wall_mask[bottom_y, x] and not gt_wall_mask[bottom_y, x-1]:
            if bottom_y > 0 and not gt_wall_mask[bottom_y-1, x]:
                gt_comp[bottom_y-1, x] = gt_fg; gt_wall_mask[bottom_y-1, x] = True
        if not gt_wall_mask[bottom_y, x] and gt_wall_mask[bottom_y, x-1]:
            if not gt_wall_mask[bottom_y-1, x-1]:
                gt_comp[bottom_y-1, x-1] = gt_fg; gt_wall_mask[bottom_y-1, x-1] = True
    for x in range(1, right_x):
        if gt_wall_mask[0, x] and not gt_wall_mask[0, x-1]:
            if not gt_wall_mask[1, x]:
                gt_comp[1, x] = gt_fg; gt_wall_mask[1, x] = True
        if not gt_wall_mask[0, x] and gt_wall_mask[0, x-1]:
            if not gt_wall_mask[1, x-1]:
                gt_comp[1, x-1] = gt_fg; gt_wall_mask[1, x-1] = True
    gt_buf = io.BytesIO()
    Image.fromarray(gt_comp).save(gt_buf, format='PNG')
    minimap_composite_b64 = base64.b64encode(gt_buf.getvalue()).decode('ascii')

    # Also load old filenames for comparison
    import os
    old_dm_files = sorted(os.listdir("/Users/joshuashin/Downloads/dungeonmode 2/cut_files/dungeon_mode/"))
    old_d437_files = sorted(os.listdir("/Users/joshuashin/Downloads/dungeonmode 2/cut_files/dungeon_437/"))

    old_dm_names = {}
    for f in old_dm_files:
        if f.endswith('.png'):
            parts = f.replace('.png','').split('_', 2)
            if len(parts) >= 3:
                try:
                    idx = int(parts[1])
                    old_dm_names[idx] = '_'.join(parts[2:])
                except ValueError:
                    pass

    old_d437_names = {}
    for f in old_d437_files:
        if f.endswith('.png'):
            parts = f.replace('.png','').split('_', 2)
            if len(parts) >= 3:
                try:
                    idx = int(parts[1])
                    old_d437_names[idx] = '_'.join(parts[2:])
                except ValueError:
                    pass

    # Add old names to tile data
    for t in dm_tiles:
        t["old_name"] = old_dm_names.get(t["idx"], "")
    for t in d437_tiles:
        t["old_name"] = old_d437_names.get(t["idx"], "")

    # Build HTML
    tiles_json = json.dumps({"dm": dm_tiles, "d437": d437_tiles})
    cat_colors_json = json.dumps(CATEGORY_COLORS)

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Dungeon Tileset Rename Playground</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{
    background: #1a1a2e; color: #e0e0e0;
    font-family: 'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace;
    font-size: 13px;
}}
.header {{
    background: #16213e; padding: 16px 24px;
    border-bottom: 2px solid #0f3460;
    display: flex; justify-content: space-between; align-items: center;
}}
.header h1 {{ font-size: 18px; color: #e94560; }}
.controls {{
    display: flex; gap: 12px; align-items: center; flex-wrap: wrap;
}}
.controls label {{ color: #aaa; font-size: 12px; }}
.controls select, .controls input {{
    background: #1a1a2e; color: #e0e0e0; border: 1px solid #333;
    padding: 4px 8px; border-radius: 4px; font-family: inherit; font-size: 12px;
}}
.controls button {{
    background: #e94560; color: white; border: none;
    padding: 6px 12px; border-radius: 4px; cursor: pointer;
    font-family: inherit; font-size: 12px;
}}
.controls button:hover {{ background: #d13850; }}
.main {{
    display: flex; height: calc(100vh - 60px);
}}
.tile-grid-container {{
    flex: 1; overflow-y: auto; padding: 16px;
}}
.sidebar {{
    width: 400px; background: #16213e; border-left: 2px solid #0f3460;
    padding: 16px; overflow-y: auto; flex-shrink: 0;
}}
.tab-bar {{
    display: flex; gap: 4px; margin-bottom: 16px;
}}
.tab {{
    padding: 8px 16px; background: #0f3460; border: none; color: #aaa;
    cursor: pointer; border-radius: 6px 6px 0 0; font-family: inherit;
    font-size: 13px;
}}
.tab.active {{ background: #e94560; color: white; }}
.tile-grid {{
    display: grid;
    grid-template-columns: repeat(16, 1fr);
    gap: 2px;
}}
.tile-cell {{
    position: relative; cursor: pointer;
    border: 2px solid transparent; border-radius: 3px;
    display: flex; align-items: center; justify-content: center;
    aspect-ratio: 1;
    transition: border-color 0.15s, transform 0.15s;
    background: #111;
}}
.tile-cell:hover {{
    border-color: #e94560;
    transform: scale(1.15);
    z-index: 10;
}}
.tile-cell.selected {{
    border-color: #ffcc00;
    box-shadow: 0 0 8px rgba(255, 204, 0, 0.5);
}}
.tile-cell.multi-selected {{
    border-color: #4488ff;
    box-shadow: 0 0 8px rgba(68, 136, 255, 0.5);
}}
.tile-cell img {{
    width: 100%; height: 100%;
    image-rendering: pixelated;
    image-rendering: -moz-crisp-edges;
    image-rendering: crisp-edges;
}}
.tile-cell .cat-dot {{
    position: absolute; top: 1px; right: 1px;
    width: 5px; height: 5px; border-radius: 50%;
}}
.tile-cell .edited-dot {{
    position: absolute; top: 1px; left: 1px;
    width: 5px; height: 5px; border-radius: 50%;
    background: #ff8844;
}}
.tile-cell .group-ring {{
    position: absolute; bottom: 1px; left: 1px;
    width: 6px; height: 6px; border-radius: 50%;
    border: 2px solid;
}}

/* Category legend */
.legend {{
    display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 12px;
}}
.legend-item {{
    display: flex; align-items: center; gap: 4px; font-size: 11px;
    cursor: pointer; padding: 2px 6px; border-radius: 3px;
    border: 1px solid transparent;
}}
.legend-item:hover {{ border-color: #555; }}
.legend-item.active {{ border-color: #e94560; background: rgba(233,69,96,0.15); }}
.legend-dot {{
    width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0;
}}

/* Sidebar details */
.detail-section {{ margin-bottom: 16px; }}
.detail-section h3 {{
    color: #e94560; font-size: 14px; margin-bottom: 8px;
    border-bottom: 1px solid #333; padding-bottom: 4px;
}}
.detail-preview {{
    display: flex; gap: 16px; align-items: flex-start;
}}
.detail-tile-large {{
    width: 128px; height: 128px; background: #000;
    border: 1px solid #333; flex-shrink: 0;
    image-rendering: pixelated;
}}
.detail-info {{ flex: 1; }}
.detail-info .label {{ color: #888; font-size: 11px; }}
.detail-info .value {{ color: #e0e0e0; margin-bottom: 6px; word-break: break-all; }}
.detail-info .old-name {{ color: #ff6666; text-decoration: line-through; }}
.detail-info .new-name {{ color: #66ff66; font-weight: bold; }}

/* Name editor */
.name-editor {{
    margin-top: 8px; padding: 8px;
    background: rgba(233,69,96,0.1);
    border: 1px solid #e94560;
    border-radius: 4px;
}}
.name-editor input {{
    width: 100%; background: #1a1a2e; color: #e0e0e0;
    border: 1px solid #333; padding: 6px;
    font-family: inherit; font-size: 12px;
    border-radius: 3px;
}}
.name-editor-buttons {{
    display: flex; gap: 8px; margin-top: 6px;
}}
.name-editor-buttons button {{
    flex: 1; padding: 4px 8px; border-radius: 3px;
    border: none; cursor: pointer; font-family: inherit;
    font-size: 11px;
}}
.name-editor-buttons .save {{ background: #66ff66; color: #000; }}
.name-editor-buttons .cancel {{ background: #666; color: white; }}

/* Groups section */
.groups-section {{
    margin-top: 12px;
}}
.multi-selection-info {{
    padding: 8px; background: rgba(68,136,255,0.1);
    border: 1px solid rgba(68,136,255,0.3);
    border-radius: 4px; margin-bottom: 8px;
    font-size: 11px;
}}
.create-group {{
    display: flex; gap: 4px; margin-bottom: 8px;
}}
.create-group input {{
    flex: 1; background: #1a1a2e; color: #e0e0e0;
    border: 1px solid #333; padding: 4px;
    font-family: inherit; font-size: 11px;
    border-radius: 3px;
}}
.create-group button {{
    background: #4488ff; color: white; border: none;
    padding: 4px 8px; border-radius: 3px; cursor: pointer;
    font-family: inherit; font-size: 11px;
}}
.group-list {{
    display: flex; flex-direction: column; gap: 4px;
}}
.group-item {{
    display: flex; align-items: center; gap: 6px;
    padding: 6px; background: rgba(255,255,255,0.05);
    border-radius: 3px; cursor: pointer;
    border: 1px solid transparent;
    font-size: 11px;
}}
.group-item:hover {{ border-color: #555; }}
.group-color {{
    width: 12px; height: 12px; border-radius: 50%;
    flex-shrink: 0;
}}
.group-name {{ flex: 1; }}
.group-count {{ color: #888; }}
.export-buttons {{
    display: flex; gap: 8px; margin-top: 8px;
}}
.export-buttons button {{
    flex: 1; padding: 6px 8px; background: #0f3460;
    color: white; border: none; border-radius: 3px;
    cursor: pointer; font-family: inherit; font-size: 11px;
}}
.export-buttons button:hover {{ background: #1a4d7a; }}

/* Tilesheet preview */
.sheet-preview {{
    position: relative; display: inline-block;
    margin-top: 8px;
}}
.sheet-preview img {{
    width: 320px; height: 320px;
    image-rendering: pixelated;
    border: 1px solid #333;
}}
.sheet-highlight {{
    position: absolute;
    border: 2px solid #e94560;
    pointer-events: none;
    box-shadow: 0 0 6px rgba(233,69,96,0.7);
}}

/* Wall shape examples */
.wall-shapes {{
    margin-bottom: 24px; padding: 16px;
    background: rgba(68,136,255,0.05);
    border: 1px solid rgba(68,136,255,0.2);
    border-radius: 6px;
}}
.wall-shapes h3 {{
    color: #4488ff; font-size: 16px; margin-bottom: 12px;
}}
.shape-grid {{
    display: grid; gap: 16px;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
}}
.shape-example {{
    padding: 12px; background: rgba(0,0,0,0.3);
    border-radius: 4px;
}}
.shape-example h4 {{
    color: #4488ff; font-size: 13px; margin-bottom: 4px;
}}
.shape-example .shape-desc {{
    color: #888; font-size: 10px; margin-bottom: 8px;
}}
.shape-tiles {{
    display: inline-grid; gap: 1px;
    background: #333;
    padding: 2px;
    border-radius: 3px;
}}

/* Wall group section */
.wall-group {{
    margin-top: 16px; padding: 12px;
    background: rgba(68,136,255,0.1);
    border: 1px solid rgba(68,136,255,0.3);
    border-radius: 6px;
}}
.wall-group h4 {{ color: #4488ff; margin-bottom: 8px; }}
.wall-grid {{
    display: grid; grid-template-columns: repeat(11, 1fr); gap: 4px;
}}
.wall-grid .tile-cell {{
    border-color: rgba(68,136,255,0.3);
}}
.wall-label {{
    font-size: 9px; color: #4488ff; text-align: center;
    overflow: hidden; white-space: nowrap;
}}

/* Search highlight */
.tile-cell.search-match {{
    border-color: #ffcc00;
}}
.tile-cell.search-hidden {{
    opacity: 0.15;
}}

/* Row labels */
.row-label {{
    font-size: 10px; color: #666; text-align: center;
    padding: 2px;
}}
</style>
</head>
<body>
<div class="header">
    <h1>Dungeon Tileset Rename Playground</h1>
    <div class="controls">
        <label>Search: <input type="text" id="search" placeholder="wall, icon, shade..."></label>
        <label>Filter:
            <select id="catFilter">
                <option value="">All Categories</option>
                <option value="wall">Walls</option>
                <option value="block">Blocks</option>
                <option value="shade">Shades/Fills</option>
                <option value="edge">Edges/Slopes</option>
                <option value="diagonal">Diagonals</option>
                <option value="text">Letters/Digits</option>
                <option value="punct">Punctuation</option>
                <option value="arrow">Arrows/Triangles</option>
                <option value="icon">Icons/Symbols</option>
                <option value="basic">Basic</option>
            </select>
        </label>
        <label>Zoom:
            <select id="zoomLevel">
                <option value="32">4x</option>
                <option value="40" selected>5x</option>
                <option value="48">6x</option>
                <option value="64">8x</option>
            </select>
        </label>
        <button id="exportNamesBtn" style="display:none;">Export Names JSON</button>
        <button id="exportGroupsBtn" style="display:none;">Export Groups JSON</button>
    </div>
</div>
<div class="main">
    <div class="tile-grid-container">
        <div class="tab-bar">
            <button class="tab active" data-set="dm">Dungeon Mode</button>
            <button class="tab" data-set="d437">Dungeon 437 (CP437)</button>
            <button class="tab" data-set="walls">Wall Tiles Comparison</button>
        </div>
        <div class="legend" id="legend"></div>
        <div id="gridArea"></div>
    </div>
    <div class="sidebar">
        <div class="detail-section">
            <h3>Tile Details</h3>
            <div id="detailContent">
                <p style="color:#666;">Hover over a tile to see details.<br>Click to lock selection.<br>Double-click (DM mode) to edit name.<br>Shift+click to multi-select.</p>
            </div>
        </div>
        <div class="detail-section" id="groupsSection" style="display:none;">
            <h3>Groups</h3>
            <div class="groups-section">
                <div class="multi-selection-info" id="multiSelectInfo">
                    No tiles selected
                </div>
                <div class="create-group">
                    <input type="text" id="groupNameInput" placeholder="Group name...">
                    <button id="createGroupBtn">Create Group</button>
                </div>
                <div class="group-list" id="groupList"></div>
                <div class="export-buttons">
                    <button id="exportGroupsBtn2">Export Groups JSON</button>
                </div>
            </div>
        </div>
        <div class="detail-section">
            <h3>Position on Tilesheet</h3>
            <div class="sheet-preview" id="sheetPreview">
                <img id="sheetImg" src="" alt="tilesheet">
                <div class="sheet-highlight" id="sheetHighlight" style="display:none;"></div>
            </div>
        </div>
    </div>
</div>

<script>
const DATA = {tiles_json};
const CAT_COLORS = {cat_colors_json};
const MINIMAP_SOLID_B64 = "{minimap_solid_b64}";
const MINIMAP_SOLID_W = {minimap_solid_w};
const MINIMAP_SOLID_H = {minimap_solid_h};
const MINIMAP_DOOR_B64 = "{minimap_door_b64}";
const MINIMAP_DOOR_W = {minimap_door_w};
const MINIMAP_DOOR_H = {minimap_door_h};
const MINIMAP_TWO_B64 = "{minimap_two_b64}";
const MINIMAP_TWO_W = {minimap_two_w};
const MINIMAP_TWO_H = {minimap_two_h};
const MINIMAP_GT_B64 = "{minimap_composite_b64}";
const SHEETS = {{
    dm: "data:image/png;base64,{dm_sheet_b64}",
    d437: "data:image/png;base64,{d437_sheet_b64}"
}};

let currentSet = "dm";
let selectedTile = null;
let lockedTile = null;
let editingTile = null;

// Feature 2: Name overrides
let nameOverrides = {{}};

// Feature 3: Multi-select and groups
let multiSelection = new Set();
let groups = {{}};
const pastelColors = [
    '#ffb3ba', '#baffc9', '#bae1ff', '#ffffba', '#ffdfba',
    '#e0bbff', '#ffc9de', '#c9ffec', '#ffd9b3', '#d4c5f9'
];
let colorIndex = 0;

// Initialize
function init() {{
    buildLegend();
    renderGrid();
    setupEvents();
    document.getElementById('sheetImg').src = SHEETS.dm;
    // Default tab is dm — show DM-only UI on load
    document.getElementById('groupsSection').style.display = 'block';
    document.getElementById('exportNamesBtn').style.display = 'inline-block';
    document.getElementById('exportGroupsBtn').style.display = 'inline-block';
}}

function buildLegend() {{
    const legend = document.getElementById('legend');
    legend.innerHTML = '';
    for (const [cat, color] of Object.entries(CAT_COLORS)) {{
        const item = document.createElement('div');
        item.className = 'legend-item';
        item.dataset.cat = cat;
        item.innerHTML = `<span class="legend-dot" style="background:${{color}}"></span>${{cat}}`;
        item.addEventListener('click', () => {{
            document.getElementById('catFilter').value = cat;
            applyFilters();
        }});
        legend.appendChild(item);
    }}
}}

function getTileName(tile) {{
    return nameOverrides[tile.idx] || tile.name;
}}

function renderGrid() {{
    const area = document.getElementById('gridArea');
    const zoom = parseInt(document.getElementById('zoomLevel').value);

    if (currentSet === 'walls') {{
        renderWallComparison(area, zoom);
        return;
    }}

    const tiles = DATA[currentSet];
    area.innerHTML = '';

    const grid = document.createElement('div');
    grid.className = 'tile-grid';
    grid.style.gridTemplateColumns = `repeat(16, ${{zoom}}px)`;

    for (const tile of tiles) {{
        const cell = document.createElement('div');
        cell.className = 'tile-cell';
        cell.style.width = zoom + 'px';
        cell.style.height = zoom + 'px';
        cell.dataset.idx = tile.idx;
        cell.dataset.cat = tile.cat;
        cell.dataset.name = getTileName(tile);

        if (multiSelection.has(tile.idx)) {{
            cell.classList.add('multi-selected');
        }}

        const img = document.createElement('img');
        img.src = `data:image/png;base64,${{tile.b64}}`;
        img.alt = getTileName(tile);
        cell.appendChild(img);

        // Category dot
        const dot = document.createElement('span');
        dot.className = 'cat-dot';
        dot.style.background = CAT_COLORS[tile.cat] || '#555';
        cell.appendChild(dot);

        // Edited indicator
        if (nameOverrides[tile.idx]) {{
            const editDot = document.createElement('span');
            editDot.className = 'edited-dot';
            cell.appendChild(editDot);
        }}

        // Group ring
        const tileGroups = Object.entries(groups).filter(([_, g]) => g.tiles.includes(tile.idx));
        if (tileGroups.length > 0) {{
            const ring = document.createElement('span');
            ring.className = 'group-ring';
            ring.style.borderColor = tileGroups[0][1].color || '#fff';
            cell.appendChild(ring);
        }}

        cell.addEventListener('mouseenter', () => showDetail(tile));
        cell.addEventListener('click', (e) => handleCellClick(tile, cell, e));
        cell.addEventListener('dblclick', () => {{ if (currentSet === 'dm') startEditName(tile); }});

        grid.appendChild(cell);
    }}

    area.appendChild(grid);
    applyFilters();
}}

function handleCellClick(tile, cell, e) {{
    if (e.shiftKey && currentSet === 'dm') {{
        // Multi-select mode
        if (multiSelection.has(tile.idx)) {{
            multiSelection.delete(tile.idx);
            cell.classList.remove('multi-selected');
        }} else {{
            multiSelection.add(tile.idx);
            cell.classList.add('multi-selected');
        }}
        updateMultiSelectInfo();
    }} else {{
        // Single select mode
        lockDetail(tile, cell);
    }}
}}

function updateMultiSelectInfo() {{
    const info = document.getElementById('multiSelectInfo');
    const count = multiSelection.size;
    info.textContent = count === 0 ? 'No tiles selected' : `${{count}} tile${{count !== 1 ? 's' : ''}} selected`;
}}

function startEditName(tile) {{
    if (editingTile === tile) return;
    editingTile = tile;
    updateDetailPanel(tile, true);
}}

function saveNameEdit(tile, newName) {{
    if (newName && newName !== tile.name) {{
        nameOverrides[tile.idx] = newName;
    }} else {{
        delete nameOverrides[tile.idx];
    }}
    editingTile = null;
    renderGrid();
    updateDetailPanel(tile);
}}

function cancelNameEdit(tile) {{
    editingTile = null;
    updateDetailPanel(tile);
}}

function createGroup() {{
    const input = document.getElementById('groupNameInput');
    const name = input.value.trim();
    if (!name || multiSelection.size === 0) return;

    const color = pastelColors[colorIndex % pastelColors.length];
    colorIndex++;

    groups[name] = {{
        tiles: Array.from(multiSelection),
        color: color
    }};

    input.value = '';
    multiSelection.clear();
    updateMultiSelectInfo();
    updateGroupList();
    renderGrid();
}}

function updateGroupList() {{
    const list = document.getElementById('groupList');
    list.innerHTML = '';

    for (const [name, data] of Object.entries(groups)) {{
        const item = document.createElement('div');
        item.className = 'group-item';

        const colorDot = document.createElement('span');
        colorDot.className = 'group-color';
        colorDot.style.background = data.color;

        const nameSpan = document.createElement('span');
        nameSpan.className = 'group-name';
        nameSpan.textContent = name;

        const countSpan = document.createElement('span');
        countSpan.className = 'group-count';
        countSpan.textContent = `(${{data.tiles.length}})`;

        item.appendChild(colorDot);
        item.appendChild(nameSpan);
        item.appendChild(countSpan);

        item.addEventListener('click', () => {{
            multiSelection.clear();
            data.tiles.forEach(idx => multiSelection.add(idx));
            updateMultiSelectInfo();
            renderGrid();
        }});

        list.appendChild(item);
    }}
}}

function exportNames() {{
    const allNames = {{}};
    const tiles = DATA.dm;
    for (const tile of tiles) {{
        allNames[tile.idx] = getTileName(tile);
    }}

    const json = JSON.stringify(allNames, null, 2);
    const blob = new Blob([json], {{ type: 'application/json' }});
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'dungeon_mode_names.json';
    a.click();
    URL.revokeObjectURL(url);
}}

function exportGroups() {{
    const exportData = {{}};
    for (const [name, data] of Object.entries(groups)) {{
        exportData[name] = data.tiles;
    }}

    const json = JSON.stringify(exportData, null, 2);
    const blob = new Blob([json], {{ type: 'application/json' }});
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'dungeon_mode_groups.json';
    a.click();
    URL.revokeObjectURL(url);
}}

function renderWallComparison(area, zoom) {{
    area.innerHTML = '';

    // Feature 1: Wall shape examples at the top
    const shapesSection = document.createElement('div');
    shapesSection.className = 'wall-shapes';
    shapesSection.innerHTML = '<h3>Wall Shape Examples</h3>';

    const shapeGrid = document.createElement('div');
    shapeGrid.className = 'shape-grid';

    const shapes = [
        // ── Single Line Wall Group ──────────────────────────────
        {{
            title: 'Box: Single Line (wall1)',
            desc: 'single_line_wall_group — basic box-drawing room',
            grid: [
                ['wall1_se', 'wall1_ew', 'wall1_ew', 'wall1_sw'],
                ['wall1_ns', null, null, 'wall1_ns'],
                ['wall1_ns', null, null, 'wall1_ns'],
                ['wall1_ne', 'wall1_ew', 'wall1_ew', 'wall1_nw']
            ]
        }},
        {{
            title: 'L-Room: Single Line',
            desc: 'Non-rectangular room with tees and cross',
            grid: [
                ['wall1_se', 'wall1_ew', 'wall1_sw', null, null],
                ['wall1_ns', null, 'wall1_nse', 'wall1_ew', 'wall1_sw'],
                ['wall1_ns', null, null, null, 'wall1_ns'],
                ['wall1_ne', 'wall1_ew', 'wall1_ew', 'wall1_ew', 'wall1_nw']
            ]
        }},
        {{
            title: 'Cross: Single Line',
            desc: 'Four-way intersection using nsew cross',
            grid: [
                [null, 'wall1_se', 'wall1_sw', null],
                ['wall1_se', 'wall1_nw', 'wall1_ne', 'wall1_sw'],
                ['wall1_ne', 'wall1_sw', 'wall1_se', 'wall1_nw'],
                [null, 'wall1_ne', 'wall1_nw', null]
            ]
        }},
        // ── Double Line Wall Group (Round Fillings) ─────────────
        {{
            title: 'Box: Double Line (wall2)',
            desc: 'wall_group_round_fillings — double-line room',
            grid: [
                ['wall2_se', 'wall2_ew', 'wall2_ew', 'wall2_sw'],
                ['wall2_ns', null, null, 'wall2_ns'],
                ['wall2_ns', null, null, 'wall2_ns'],
                ['wall2_ne', 'wall2_ew', 'wall2_ew', 'wall2_nw']
            ]
        }},
        {{
            title: 'Partition: Double Line',
            desc: 'Room divided by double-line internal wall',
            grid: [
                ['wall2_se', 'wall2_ew', 'wall2_sew', 'wall2_ew', 'wall2_sw'],
                ['wall2_ns', null, 'wall2_ns', null, 'wall2_ns'],
                ['wall2_ne', 'wall2_ew', 'wall2_new', 'wall2_ew', 'wall2_nw']
            ]
        }},
        // ── Double Vert / Single Horiz (wall_2v1h) ─────────────
        {{
            title: 'Box: 2v1h Mixed',
            desc: 'vertical_double_wall_group — double vert, single horiz',
            grid: [
                ['wall_2v1h_se', 'wall1_ew', 'wall1_ew', 'wall_2v1h_sw'],
                ['wall2_ns', null, null, 'wall2_ns'],
                ['wall2_ns', null, null, 'wall2_ns'],
                ['wall_2v1h_ne', 'wall1_ew', 'wall1_ew', 'wall_2v1h_nw']
            ]
        }},
        {{
            title: 'Partition: 2v1h Mixed',
            desc: 'Double vert walls with single horiz divider',
            grid: [
                ['wall_2v1h_se', 'wall1_ew', 'wall_2v1h_sew', 'wall1_ew', 'wall_2v1h_sw'],
                ['wall2_ns', null, 'wall2_ns', null, 'wall2_ns'],
                ['wall_2v1h_ne', 'wall1_ew', 'wall_2v1h_new', 'wall1_ew', 'wall_2v1h_nw']
            ]
        }},
        // ── Single Vert / Double Horiz (wall_1v2h) ─────────────
        {{
            title: 'Box: 1v2h Mixed',
            desc: '3d_like_wall_group — single vert, double horiz',
            grid: [
                ['wall_1v2h_se', 'wall2_ew', 'wall2_ew', 'wall_1v2h_sw'],
                ['wall1_ns', null, null, 'wall1_ns'],
                ['wall1_ns', null, null, 'wall1_ns'],
                ['wall_1v2h_ne', 'wall2_ew', 'wall2_ew', 'wall_1v2h_nw']
            ]
        }},
        {{
            title: 'Partition: 1v2h Mixed',
            desc: 'Single vert walls with double horiz divider',
            grid: [
                ['wall_1v2h_se', 'wall2_ew', 'wall_1v2h_sew', 'wall2_ew', 'wall_1v2h_sw'],
                ['wall1_ns', null, 'wall1_ns', null, 'wall1_ns'],
                ['wall_1v2h_ne', 'wall2_ew', 'wall_1v2h_new', 'wall2_ew', 'wall_1v2h_nw']
            ]
        }},
        // ── Mixed Border (double outer, single inner) ───────────
        {{
            title: 'Mixed Border Room',
            desc: 'Double outer walls, single inner division via 2v1h junctions',
            grid: [
                ['wall2_se', 'wall2_ew', 'wall2_ew', 'wall2_sw'],
                ['wall2_ns', null, null, 'wall2_ns'],
                ['wall_2v1h_nse', 'wall1_ew', 'wall1_ew', 'wall_2v1h_nsw'],
                ['wall2_ns', null, null, 'wall2_ns'],
                ['wall2_ne', 'wall2_ew', 'wall2_ew', 'wall2_nw']
            ]
        }},
        // ── Minimap Edge Tiles ──────────────────────────────────
        // These use top-left border convention: each tile draws
        // borders only on its TOP edge (row 0) and LEFT edge (col 0).
        // Right/bottom borders come from adjacent cells.
        // 169=NW, 170=top, 185=left, 203=SE corner pixel.
        // 171/186/187/201/202=door-gap variants.
        {{
            title: 'Minimap: Solid Room',
            desc: 'Top-left border convention: 169=NW 170=top 185=left 203=SE pixel',
            compositeB64: MINIMAP_SOLID_B64,
            compositeW: MINIMAP_SOLID_W,
            compositeH: MINIMAP_SOLID_H
        }},
        {{
            title: 'Minimap: Room with Door',
            desc: '187=left-col+gap (door in right wall). Perpendicular tips cap door edges.',
            compositeB64: MINIMAP_DOOR_B64,
            compositeW: MINIMAP_DOOR_W,
            compositeH: MINIMAP_DOOR_H
        }},
        {{
            title: 'Minimap: Two Connected Rooms',
            desc: '187=door in dividing wall connects rooms',
            compositeB64: MINIMAP_TWO_B64,
            compositeW: MINIMAP_TWO_W,
            compositeH: MINIMAP_TWO_H
        }},
        {{
            title: 'Minimap: Goblin Tunnels (excerpt)',
            desc: 'Actual layout from goblin-tunnels.psci rows 1-5, cols 1-5. Colored with dungeon palette.',
            compositeB64: MINIMAP_GT_B64,
            compositeW: 40,
            compositeH: 40
        }},
        // ── Stripe/Streaks Wall Group ────────────────────────────
        // Diagonal-stripe wall system:
        // 192=NW corner(noSE), 193=top edge, 194=NE corner(noSW),
        // 208=left edge, 210=right edge,
        // 224=SW corner(noNE), 225=bottom edge, 226=SE corner(noNW)
        {{
            title: 'Box: Stripe Walls',
            desc: 'stripe_streaks_wall_group — diagonal stripes as wall material',
            grid: [
                ['block_three_quarter_ne_nw_sw', 'diagonal_halftone_se', 'diagonal_halftone_se', 'block_three_quarter_ne_nw_se'],
                ['fill_diagonal_forward', null, null, 'fill_diagonal_backward'],
                ['fill_diagonal_forward', null, null, 'fill_diagonal_backward'],
                ['block_three_quarter_nw_sw_se', 'diagonal_halftone_ne', 'diagonal_halftone_ne', 'block_three_quarter_ne_sw_se']
            ]
        }},
        {{
            title: 'Corridor: Stripe Walls',
            desc: 'Horizontal passage with stripe wall edges',
            grid: [
                ['block_three_quarter_ne_nw_sw', 'diagonal_halftone_se', 'diagonal_halftone_se', 'diagonal_halftone_se', 'diagonal_halftone_se', 'block_three_quarter_ne_nw_se'],
                [null, null, null, null, null, null],
                ['block_three_quarter_nw_sw_se', 'diagonal_halftone_ne', 'diagonal_halftone_ne', 'diagonal_halftone_ne', 'diagonal_halftone_ne', 'block_three_quarter_ne_sw_se']
            ]
        }},
        {{
            title: 'L-Room: Stripe Walls',
            desc: 'Non-rectangular room with stripe wall corners',
            grid: [
                ['block_three_quarter_ne_nw_sw', 'diagonal_halftone_se', 'block_three_quarter_ne_nw_se', null, null],
                ['fill_diagonal_forward', null, 'fill_diagonal_backward', null, null],
                ['fill_diagonal_forward', null, 'block_three_quarter_nw_sw_se', 'diagonal_halftone_se', 'block_three_quarter_ne_nw_se'],
                ['fill_diagonal_forward', null, null, null, 'fill_diagonal_backward'],
                ['block_three_quarter_nw_sw_se', 'diagonal_halftone_ne', 'diagonal_halftone_ne', 'diagonal_halftone_ne', 'block_three_quarter_ne_sw_se']
            ]
        }}
    ];

    for (const shape of shapes) {{
        const example = document.createElement('div');
        example.className = 'shape-example';

        const title = document.createElement('h4');
        title.textContent = shape.title;
        example.appendChild(title);

        const desc = document.createElement('div');
        desc.className = 'shape-desc';
        desc.textContent = shape.desc;
        example.appendChild(desc);

        if (shape.compositeB64) {{
            // Render as a single composite image (pixel-accurate minimap)
            const img = document.createElement('img');
            img.src = `data:image/png;base64,${{shape.compositeB64}}`;
            img.style.width = (shape.compositeW * (zoom / 8)) + 'px';
            img.style.height = (shape.compositeH * (zoom / 8)) + 'px';
            img.style.imageRendering = 'pixelated';
            img.style.border = '1px solid #333';
            example.appendChild(img);
        }} else {{
            const gridEl = document.createElement('div');
            gridEl.className = 'shape-tiles';
            gridEl.style.gridTemplateColumns = `repeat(${{shape.grid[0].length}}, ${{zoom}}px)`;

            for (const row of shape.grid) {{
                for (const tileName of row) {{
                    const cell = document.createElement('div');
                    cell.style.width = zoom + 'px';
                    cell.style.height = zoom + 'px';
                    cell.style.background = '#000';
                    cell.style.display = 'flex';
                    cell.style.alignItems = 'center';
                    cell.style.justifyContent = 'center';

                    if (tileName) {{
                        const tile = DATA.dm.find(t => t.name === tileName);
                        if (tile) {{
                            const img = document.createElement('img');
                            img.src = `data:image/png;base64,${{tile.b64}}`;
                            img.style.width = '100%';
                            img.style.height = '100%';
                            img.style.imageRendering = 'pixelated';
                            cell.appendChild(img);
                        }}
                    }}

                    gridEl.appendChild(cell);
                }}
            }}

            example.appendChild(gridEl);
        }}
        shapeGrid.appendChild(example);
    }}

    shapesSection.appendChild(shapeGrid);
    area.appendChild(shapesSection);

    // Rest of wall comparison (existing)
    const wallTypes = [
        {{ label: "Single Line (wall1)", prefix: "wall1_", set: "dm" }},
        {{ label: "Double Line (wall2)", prefix: "wall2_", set: "dm" }},
        {{ label: "Mixed: Double V / Single H (wall_2v1h)", prefix: "wall_2v1h_", set: "dm" }},
        {{ label: "Mixed: Single V / Double H (wall_1v2h)", prefix: "wall_1v2h_", set: "dm" }},
    ];

    const connOrder = ["ns","ew","se","sw","ne","nw","sew","nse","nsw","new","nsew"];
    const connLabels = ["N-S","E-W","SE ┌","SW ┐","NE └","NW ┘","SEW ┬","NSE ├","NSW ┤","NEW ┴","NSEW ┼"];

    for (const wt of wallTypes) {{
        const group = document.createElement('div');
        group.className = 'wall-group';
        group.innerHTML = `<h4>${{wt.label}}</h4>`;

        const grid = document.createElement('div');
        grid.className = 'wall-grid';
        grid.style.gridTemplateColumns = `repeat(${{connOrder.length}}, ${{zoom + 8}}px)`;

        for (let i = 0; i < connOrder.length; i++) {{
            const conn = connOrder[i];
            const fullName = wt.prefix + conn;
            const tile = DATA[wt.set].find(t => t.name === fullName);

            const wrapper = document.createElement('div');

            if (tile) {{
                const cell = document.createElement('div');
                cell.className = 'tile-cell';
                cell.style.width = zoom + 'px';
                cell.style.height = zoom + 'px';
                cell.dataset.idx = tile.idx;

                const img = document.createElement('img');
                img.src = `data:image/png;base64,${{tile.b64}}`;
                cell.appendChild(img);

                cell.addEventListener('mouseenter', () => showDetail(tile));
                cell.addEventListener('click', () => lockDetail(tile, cell));
                wrapper.appendChild(cell);
            }} else {{
                const empty = document.createElement('div');
                empty.className = 'tile-cell';
                empty.style.width = zoom + 'px';
                empty.style.height = zoom + 'px';
                empty.style.opacity = '0.2';
                empty.textContent = '—';
                empty.style.color = '#444';
                empty.style.fontSize = '10px';
                empty.style.display = 'flex';
                empty.style.alignItems = 'center';
                empty.style.justifyContent = 'center';
                wrapper.appendChild(empty);
            }}

            const label = document.createElement('div');
            label.className = 'wall-label';
            label.textContent = connLabels[i];
            wrapper.appendChild(label);

            grid.appendChild(wrapper);
        }}

        group.appendChild(grid);
        area.appendChild(group);
    }}

    // Also show d437 walls
    const d437Group = document.createElement('div');
    d437Group.className = 'wall-group';
    d437Group.innerHTML = '<h4 style="color:#e94560">— Same layout for Dungeon 437 —</h4>';
    area.appendChild(d437Group);

    const wallTypes437 = [
        {{ label: "CP437 Single Line (wall1)", prefix: "wall1_", set: "d437" }},
        {{ label: "CP437 Double Line (wall2)", prefix: "wall2_", set: "d437" }},
        {{ label: "CP437 Mixed: Double V / Single H", prefix: "wall_2v1h_", set: "d437" }},
        {{ label: "CP437 Mixed: Single V / Double H", prefix: "wall_1v2h_", set: "d437" }},
    ];

    for (const wt of wallTypes437) {{
        const group = document.createElement('div');
        group.className = 'wall-group';
        group.innerHTML = `<h4>${{wt.label}}</h4>`;

        const grid = document.createElement('div');
        grid.className = 'wall-grid';
        grid.style.gridTemplateColumns = `repeat(${{connOrder.length}}, ${{zoom + 8}}px)`;

        for (let i = 0; i < connOrder.length; i++) {{
            const conn = connOrder[i];
            const fullName = wt.prefix + conn;
            const tile = DATA[wt.set].find(t => t.name === fullName);

            const wrapper = document.createElement('div');
            if (tile) {{
                const cell = document.createElement('div');
                cell.className = 'tile-cell';
                cell.style.width = zoom + 'px';
                cell.style.height = zoom + 'px';

                const img = document.createElement('img');
                img.src = `data:image/png;base64,${{tile.b64}}`;
                cell.appendChild(img);

                cell.addEventListener('mouseenter', () => showDetail(tile));
                cell.addEventListener('click', () => lockDetail(tile, cell));
                wrapper.appendChild(cell);
            }} else {{
                const empty = document.createElement('div');
                empty.className = 'tile-cell';
                empty.style.width = zoom + 'px';
                empty.style.height = zoom + 'px';
                empty.style.opacity = '0.2';
                wrapper.appendChild(empty);
            }}

            const label = document.createElement('div');
            label.className = 'wall-label';
            label.textContent = connLabels[i];
            wrapper.appendChild(label);

            grid.appendChild(wrapper);
        }}

        group.appendChild(grid);
        area.appendChild(group);
    }}

    // =========================================================================
    // User-defined wall groups
    // =========================================================================
    const userGroupsHeader = document.createElement('div');
    userGroupsHeader.className = 'wall-group';
    userGroupsHeader.innerHTML = '<h4 style="color:#e94560">— User-Defined Tile Groups —</h4>';
    area.appendChild(userGroupsHeader);

    const userGroups = [
        {{
            label: 'Single Line Wall Group',
            desc: 'Single-line box-drawing walls: nsw, nsew, sew, se, nse, ne, new, nw',
            tiles: [181, 180, 164, 163, 179, 195, 196, 197],
            color: '#baffc9'
        }},
        {{
            label: 'Double Line Wall Group (Round Fillings)',
            desc: 'Double-line box-drawing walls: nsew, sw, sew, nse, nsw, nw, new, ne',
            tiles: [183, 168, 167, 182, 184, 200, 199, 198],
            color: '#ffb3ba'
        }},
        {{
            label: 'Vertical Double Wall Group (2v1h)',
            desc: 'Mixed walls: double vertical, single horizontal',
            tiles: [212, 211, 227, 228, 229, 245, 244, 243],
            color: '#bae1ff'
        }},
        {{
            label: '3D-Like Wall Group (1v2h)',
            desc: 'Mixed walls: single vertical, double horizontal',
            tiles: [230, 231, 232, 216, 215, 247, 248, 246],
            color: '#ffffba'
        }},
        {{
            label: 'Minimap Edge Group',
            desc: 'Thin edge tiles for minimap rooms (Note: tile 169/edge_wedge_nw is essential but was missing from original group)',
            tiles: [169, 170, 171, 185, 186, 187, 201, 202, 203],
            color: '#e0bbff'
        }},
        {{
            label: 'Stripe/Streaks Group',
            desc: 'Diagonal halftones and 3/4 block fills',
            tiles: [193, 192, 208, 225, 224, 226, 210],
            color: '#ffdfba'
        }},
        {{
            label: 'Diagonal Lines',
            desc: 'Dotted diagonal patterns',
            tiles: [148, 132, 133, 149],
            color: '#ffc9de'
        }},
        {{
            label: 'Quadrant Tiles',
            desc: 'Corner quadrant fills (SE, SW, NE, NW)',
            tiles: [130, 131, 146, 147],
            color: '#c9ffec'
        }}
    ];

    for (const ug of userGroups) {{
        const groupDiv = document.createElement('div');
        groupDiv.className = 'wall-group';
        groupDiv.style.borderColor = ug.color + '66';
        groupDiv.style.background = ug.color + '11';

        const header = document.createElement('h4');
        header.style.color = ug.color;
        header.textContent = ug.label;
        groupDiv.appendChild(header);

        const desc = document.createElement('div');
        desc.style.cssText = 'color:#888; font-size:11px; margin-bottom:8px;';
        desc.textContent = ug.desc;
        groupDiv.appendChild(desc);

        const grid = document.createElement('div');
        grid.style.cssText = `display:grid; grid-template-columns:repeat(${{ug.tiles.length}}, ${{zoom + 8}}px); gap:4px;`;

        for (const tileIdx of ug.tiles) {{
            const tile = DATA.dm.find(t => t.idx === tileIdx);
            const wrapper = document.createElement('div');

            if (tile) {{
                const cell = document.createElement('div');
                cell.className = 'tile-cell';
                cell.style.width = zoom + 'px';
                cell.style.height = zoom + 'px';
                cell.dataset.idx = tile.idx;

                const img = document.createElement('img');
                img.src = `data:image/png;base64,${{tile.b64}}`;
                cell.appendChild(img);

                cell.addEventListener('mouseenter', () => showDetail(tile));
                cell.addEventListener('click', () => lockDetail(tile, cell));
                wrapper.appendChild(cell);

                const label = document.createElement('div');
                label.className = 'wall-label';
                label.style.color = ug.color;
                label.textContent = `${{tile.idx}}: ${{getTileName(tile).replace(/^(wall[12]?_|wall_[12]v[12]h_|edge_|diagonal_|block_|quadrant_|fill_|dots_)/, '')}}`;
                wrapper.appendChild(label);
            }}

            grid.appendChild(wrapper);
        }}

        groupDiv.appendChild(grid);
        area.appendChild(groupDiv);
    }}
}}

function showDetail(tile) {{
    if (lockedTile) return;
    updateDetailPanel(tile);
}}

function lockDetail(tile, cell) {{
    if (lockedTile === tile) {{
        lockedTile = null;
        document.querySelectorAll('.tile-cell.selected').forEach(c => c.classList.remove('selected'));
        return;
    }}
    lockedTile = tile;
    document.querySelectorAll('.tile-cell.selected').forEach(c => c.classList.remove('selected'));
    cell.classList.add('selected');
    updateDetailPanel(tile);
}}

function updateDetailPanel(tile, editing = false) {{
    const prefix = currentSet === 'd437' || (currentSet === 'walls') ? 'd437' : 'dm';
    const setKey = tile.b64 ? (DATA.dm.includes(tile) ? 'dm' : 'd437') : prefix;
    const canEdit = setKey === 'dm' && currentSet === 'dm';

    const content = document.getElementById('detailContent');

    let html = `
        <div class="detail-preview">
            <img class="detail-tile-large" src="data:image/png;base64,${{tile.b64}}" alt="${{getTileName(tile)}}">
            <div class="detail-info">
                <div class="label">Index</div>
                <div class="value">${{tile.idx}} (0x${{tile.idx.toString(16).toUpperCase().padStart(2,'0')}})</div>
                <div class="label">Grid Position</div>
                <div class="value">Row ${{tile.row}}, Col ${{tile.col}}</div>
                <div class="label">Unicode Char</div>
                <div class="value" style="font-size:20px">${{tile.char}}</div>
                <div class="label">Category</div>
                <div class="value"><span style="color:${{CAT_COLORS[tile.cat] || '#fff'}}">${{tile.cat}}</span></div>
                <div class="label">Old Name</div>
                <div class="value old-name">${{tile.old_name || '(none)'}}</div>
                <div class="label">Current Name</div>
                <div class="value new-name">${{getTileName(tile)}}</div>
            </div>
        </div>
    `;

    if (canEdit && editing) {{
        html += `
            <div class="name-editor">
                <input type="text" id="nameEditInput" value="${{getTileName(tile)}}" placeholder="Enter new name...">
                <div class="name-editor-buttons">
                    <button class="save" id="saveNameBtn">Save</button>
                    <button class="cancel" id="cancelNameBtn">Cancel</button>
                </div>
            </div>
        `;
    }}

    content.innerHTML = html;

    if (canEdit && editing) {{
        const input = document.getElementById('nameEditInput');
        const saveBtn = document.getElementById('saveNameBtn');
        const cancelBtn = document.getElementById('cancelNameBtn');

        input.focus();
        input.select();

        input.addEventListener('keydown', (e) => {{
            if (e.key === 'Enter') saveNameEdit(tile, input.value);
            if (e.key === 'Escape') cancelNameEdit(tile);
        }});

        saveBtn.addEventListener('click', () => saveNameEdit(tile, input.value));
        cancelBtn.addEventListener('click', () => cancelNameEdit(tile));
    }}

    // Update tilesheet highlight
    const sheetImg = document.getElementById('sheetImg');
    sheetImg.src = SHEETS[setKey] || SHEETS.dm;

    const hl = document.getElementById('sheetHighlight');
    const sheetDisplaySize = 320;
    const tileDisplaySize = sheetDisplaySize / 16;
    hl.style.display = 'block';
    hl.style.left = (tile.col * tileDisplaySize) + 'px';
    hl.style.top = (tile.row * tileDisplaySize) + 'px';
    hl.style.width = tileDisplaySize + 'px';
    hl.style.height = tileDisplaySize + 'px';
}}

function applyFilters() {{
    const search = document.getElementById('search').value.toLowerCase();
    const catFilter = document.getElementById('catFilter').value;

    document.querySelectorAll('.tile-cell').forEach(cell => {{
        const name = (cell.dataset.name || '').toLowerCase();
        const cat = cell.dataset.cat || '';

        let visible = true;
        if (catFilter && cat !== catFilter) visible = false;
        if (search && !name.includes(search)) visible = false;

        cell.classList.toggle('search-hidden', !visible);
    }});
}}

function setupEvents() {{
    // Tab switching
    document.querySelectorAll('.tab').forEach(tab => {{
        tab.addEventListener('click', () => {{
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            currentSet = tab.dataset.set;
            lockedTile = null;

            const sheetImg = document.getElementById('sheetImg');
            if (currentSet === 'd437') sheetImg.src = SHEETS.d437;
            else sheetImg.src = SHEETS.dm;

            // Show/hide features based on tab
            const exportNamesBtn = document.getElementById('exportNamesBtn');
            const exportGroupsBtn = document.getElementById('exportGroupsBtn');
            const groupsSection = document.getElementById('groupsSection');

            if (currentSet === 'dm') {{
                exportNamesBtn.style.display = 'inline-block';
                exportGroupsBtn.style.display = 'inline-block';
                groupsSection.style.display = 'block';
            }} else {{
                exportNamesBtn.style.display = 'none';
                exportGroupsBtn.style.display = 'none';
                groupsSection.style.display = 'none';
            }}

            renderGrid();
        }});
    }});

    // Filters
    document.getElementById('search').addEventListener('input', applyFilters);
    document.getElementById('catFilter').addEventListener('change', applyFilters);

    // Zoom
    document.getElementById('zoomLevel').addEventListener('change', renderGrid);

    // Export buttons
    document.getElementById('exportNamesBtn').addEventListener('click', exportNames);
    document.getElementById('exportGroupsBtn').addEventListener('click', exportGroups);
    document.getElementById('exportGroupsBtn2').addEventListener('click', exportGroups);

    // Group creation
    document.getElementById('createGroupBtn').addEventListener('click', createGroup);
    document.getElementById('groupNameInput').addEventListener('keydown', (e) => {{
        if (e.key === 'Enter') createGroup();
    }});
}}

init();
</script>
</body>
</html>"""

    return html_content


if __name__ == "__main__":
    html = generate_playground_html()
    output_path = "/tmp/tile_rename_playground.html"
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html)
    print(f"Playground written to {output_path}")
    print(f"File size: {len(html):,} bytes")
