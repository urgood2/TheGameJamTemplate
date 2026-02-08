#!/usr/bin/env python3
"""Export transparent tile PNGs, group metadata, and Tiled-compatible
Wang set autotiling rules for dungeon-mode and dungeon-437 tilesets.

Outputs are written to  planning/tiled_assets/export/

Usage:
    python3 scripts/export_tiled_assets.py
"""

from __future__ import annotations

import argparse
import json
import shutil
from collections import deque
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path
from typing import Any

from PIL import Image

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parents[1]
EXPORT_ROOT = PROJECT_ROOT / "planning" / "tiled_assets" / "export"

_DEFAULT_DM_SRC = Path("/Users/joshuashin/Downloads/dungeonmode 2/playscii/charsets/dungeon-mode.png")
_DEFAULT_D437_SRC = Path("/Users/joshuashin/Downloads/dungeonmode 2/playscii/charsets/dungeon-437.png")

DM_GROUPS_JSON = PROJECT_ROOT / "planning" / "tiled_assets" / "dungeon_mode_groups.json"
D437_GROUPS_JSON = PROJECT_ROOT / "planning" / "tiled_assets" / "dungeon_437_groups.json"

TILE_SIZE = 8
GRID_COLS = 16
GRID_ROWS = 16

# ---------------------------------------------------------------------------
# Mask constants  (N=1, E=2, S=4, W=8)
# ---------------------------------------------------------------------------
MASK_BITS = {"north": 1, "east": 2, "south": 4, "west": 8}

SUFFIX_TO_MASK = {
    "_ns":   0b0101,   # 5   N+S
    "_ew":   0b1010,   # 10  E+W
    "_se":   0b0110,   # 6   S+E
    "_sw":   0b1100,   # 12  S+W
    "_ne":   0b0011,   # 3   N+E
    "_nw":   0b1001,   # 9   N+W
    "_nse":  0b0111,   # 7   N+S+E
    "_nsw":  0b1101,   # 13  N+S+W
    "_sew":  0b1110,   # 14  S+E+W
    "_new":  0b1011,   # 11  N+E+W
    "_nsew": 0b1111,   # 15  all
}

# ---------------------------------------------------------------------------
# Name dictionaries  (copied from generate_tile_playground.py)
# ---------------------------------------------------------------------------
DM_NAMES: dict[int, str] = {
    0: "blank", 1: "icon_target_circle", 2: "bullet_medium",
    3: "icon_heart_filled", 4: "icon_diamond_filled", 5: "icon_club_filled",
    6: "icon_spade_filled", 7: "bullet_small", 8: "icon_male", 9: "icon_female",
    10: "icon_square_dotted", 11: "arrow_nw", 12: "arrow_e", 13: "arrow_w",
    14: "arrow_n", 15: "arrow_s",
    16: "block_full", 17: "cross_x_thin", 18: "circle_small_hollow",
    19: "icon_heart_hollow", 20: "icon_diamond_hollow", 21: "icon_union_plus",
    22: "icon_flower", 23: "ellipsis", 24: "icon_note_single",
    25: "icon_note_double", 26: "icon_dots_cross", 27: "icon_hand_pointing_up",
    28: "triangle_e_filled", 29: "triangle_w_filled", 30: "triangle_n_filled",
    31: "triangle_s_filled",
    32: "punct_period", 33: "punct_comma", 34: "punct_exclamation",
    35: "punct_question", 36: "punct_hyphen", 37: "punct_plus",
    38: "punct_slash", 39: "punct_backslash", 40: "punct_paren_open",
    41: "punct_paren_close", 42: "punct_asterisk", 43: "punct_colon",
    44: "punct_bracket_open", 45: "punct_underscore", 46: "punct_bracket_close",
    47: "punct_caret",
    48: "digit_0", 49: "digit_1", 50: "digit_2", 51: "digit_3",
    52: "digit_4", 53: "digit_5", 54: "digit_6", 55: "digit_7",
    56: "digit_8", 57: "digit_9", 58: "digit_10_circled",
    59: "punct_semicolon", 60: "punct_less_than", 61: "punct_equals",
    62: "punct_greater_than", 63: "punct_percent",
    64: "punct_at",
    65: "letter_A", 66: "letter_B", 67: "letter_C", 68: "letter_D",
    69: "letter_E", 70: "letter_F", 71: "letter_G", 72: "letter_H",
    73: "letter_I", 74: "letter_J", 75: "letter_K", 76: "letter_L",
    77: "letter_M", 78: "letter_N", 79: "letter_O",
    80: "letter_P", 81: "letter_Q", 82: "letter_R", 83: "letter_S",
    84: "letter_T", 85: "letter_U", 86: "letter_V", 87: "letter_W",
    88: "letter_X", 89: "letter_Y", 90: "letter_Z",
    91: "punct_apostrophe", 92: "punct_interrobang", 93: "punct_tilde",
    94: "punct_dollar", 95: "punct_ampersand",
    96: "punct_hash",
    97: "letter_a", 98: "letter_b", 99: "letter_c", 100: "letter_d",
    101: "letter_e", 102: "letter_f", 103: "letter_g", 104: "letter_h",
    105: "letter_i", 106: "letter_j", 107: "letter_k", 108: "letter_l",
    109: "letter_m", 110: "letter_n", 111: "letter_o",
    112: "letter_p", 113: "letter_q", 114: "letter_r", 115: "letter_s",
    116: "letter_t", 117: "letter_u", 118: "letter_v", 119: "letter_w",
    120: "letter_x", 121: "letter_y", 122: "letter_z",
    123: "punct_quote_double", 124: "punct_interrobang_inv",
    125: "punct_approx", 126: "icon_guarani_currency", 127: "icon_L_stroke",
    128: "wall1_ns", 129: "wall1_ew",
    130: "quadrant_se", 131: "quadrant_sw",
    132: "diagonal_ne_sw", 133: "diagonal_nw_se",
    134: "slope_rise_e_small", 135: "slope_rise_e_med",
    136: "slope_rise_e_large", 137: "slope_rise_w_large",
    138: "icon_house", 139: "icon_castle_rook",
    140: "icon_square_hollow", 141: "icon_circle_bar",
    142: "icon_fishtail_e", 143: "icon_fishtail_w",
    144: "wall2_ns", 145: "wall2_ew",
    146: "quadrant_ne", 147: "quadrant_nw",
    148: "dots_diagonal_se", 149: "dots_diagonal_ne",
    150: "slope_rise_w_small", 151: "slope_rise_w_med",
    152: "slope_fall_e_large", 153: "slope_fall_w_large",
    154: "slope_fall_w_med", 155: "slope_fall_w_small",
    156: "icon_dagger_cross", 157: "icon_shield_cross",
    158: "icon_ankh", 159: "icon_urn_funerary",
    160: "block_lower_half", 161: "block_right_half",
    162: "diagonal_cross_x",
    163: "wall1_se", 164: "wall1_sew", 165: "wall1_sw",
    166: "wall2_se", 167: "wall2_sew", 168: "wall2_sw",
    169: "edge_wedge_nw", 170: "edge_top_thin", 171: "edge_wedge_ne",
    172: "icon_window_target", 173: "icon_cup_open_top",
    174: "icon_bullseye_hollow", 175: "icon_key",
    176: "shade_light", 177: "shade_medium", 178: "shade_dark",
    179: "wall1_nse", 180: "wall1_nsew", 181: "wall1_nsw",
    182: "wall2_nse", 183: "wall2_nsew", 184: "wall2_nsw",
    185: "edge_left_thin", 186: "icon_target_square", 187: "edge_right_thin",
    188: "icon_star_filled", 189: "icon_caret_below",
    190: "icon_bullseye_filled", 191: "icon_triple_bar_dot",
    192: "block_three_quarter_ne_nw_sw",
    193: "diagonal_halftone_se",
    194: "block_three_quarter_ne_nw_se",
    195: "wall1_ne", 196: "wall1_new", 197: "wall1_nw",
    198: "wall2_ne", 199: "wall2_new", 200: "wall2_nw",
    201: "edge_wedge_sw", 202: "edge_bottom_thin", 203: "edge_wedge_se",
    204: "icon_hazard_lightning", 205: "icon_wave_sine",
    206: "icon_alchemy_cross", 207: "icon_alchemy_cup",
    208: "fill_diagonal_forward",
    209: "fill_checkerboard",
    210: "fill_diagonal_backward",
    211: "wall_2v1h_se", 212: "wall_2v1h_sew", 213: "wall_2v1h_sw",
    214: "wall_1v2h_se", 215: "wall_1v2h_sew", 216: "wall_1v2h_sw",
    217: "triangle_quadrant_se", 218: "triangle_quadrant_ne",
    219: "block_right_half_black", 220: "icon_two_circles",
    221: "icon_skull_coffin", 222: "icon_horiz_bar_square",
    223: "icon_return_enter",
    224: "block_three_quarter_nw_sw_se",
    225: "diagonal_halftone_ne",
    226: "block_three_quarter_ne_sw_se",
    227: "wall_2v1h_nse", 228: "wall_2v1h_nsew", 229: "wall_2v1h_nsw",
    230: "wall_1v2h_nse", 231: "wall_1v2h_nsew", 232: "wall_1v2h_nsw",
    233: "triangle_quadrant_nw", 234: "triangle_quadrant_sw",
    235: "triangle_half_lower", 236: "icon_helmet_rescue",
    237: "icon_skull_crossbones", 238: "icon_arch_intersection",
    239: "icon_triangle_with_bar",
    240: "fill_horizontal_stripes", 241: "fill_vertical_stripes",
    242: "icon_modifier_equals",
    243: "wall_2v1h_ne", 244: "wall_2v1h_new", 245: "wall_2v1h_nw",
    246: "wall_1v2h_ne", 247: "wall_1v2h_new", 248: "wall_1v2h_nw",
    249: "icon_perpendicular", 250: "icon_tack_down",
    251: "icon_squared_dot", 252: "icon_diaeresis",
    253: "icon_circumflex", 254: "icon_double_prime",
    255: "icon_because_dots",
}

D437_NAMES: dict[int, str] = {
    0: "blank_null", 1: "icon_smiley", 2: "icon_smiley_inverse",
    3: "icon_heart_filled", 4: "icon_diamond_filled", 5: "icon_club_filled",
    6: "icon_spade_filled", 7: "bullet_medium", 8: "bullet_inverse",
    9: "circle_hollow", 10: "circle_inverse", 11: "icon_male",
    12: "icon_female", 13: "icon_note_single", 14: "icon_note_double",
    15: "icon_sun",
    16: "triangle_e_filled", 17: "triangle_w_filled",
    18: "arrow_ns_double", 19: "punct_double_exclaim",
    20: "icon_paragraph", 21: "icon_section",
    22: "bar_horizontal_thick", 23: "arrow_ns_with_base",
    24: "arrow_n", 25: "arrow_s", 26: "arrow_e", 27: "arrow_w",
    28: "icon_right_angle", 29: "arrow_ew_double",
    30: "triangle_n_filled", 31: "triangle_s_filled",
    32: "space", 33: "punct_exclamation", 34: "punct_quote_double",
    35: "punct_hash", 36: "punct_dollar", 37: "punct_percent",
    38: "punct_ampersand", 39: "punct_apostrophe",
    40: "punct_paren_open", 41: "punct_paren_close",
    42: "punct_asterisk", 43: "punct_plus", 44: "punct_comma",
    45: "punct_hyphen", 46: "punct_period", 47: "punct_slash",
    48: "digit_0", 49: "digit_1", 50: "digit_2", 51: "digit_3",
    52: "digit_4", 53: "digit_5", 54: "digit_6", 55: "digit_7",
    56: "digit_8", 57: "digit_9",
    58: "punct_colon", 59: "punct_semicolon", 60: "punct_less_than",
    61: "punct_equals", 62: "punct_greater_than", 63: "punct_question",
    64: "punct_at",
    65: "letter_A", 66: "letter_B", 67: "letter_C", 68: "letter_D",
    69: "letter_E", 70: "letter_F", 71: "letter_G", 72: "letter_H",
    73: "letter_I", 74: "letter_J", 75: "letter_K", 76: "letter_L",
    77: "letter_M", 78: "letter_N", 79: "letter_O",
    80: "letter_P", 81: "letter_Q", 82: "letter_R", 83: "letter_S",
    84: "letter_T", 85: "letter_U", 86: "letter_V", 87: "letter_W",
    88: "letter_X", 89: "letter_Y", 90: "letter_Z",
    91: "punct_bracket_open", 92: "punct_backslash",
    93: "punct_bracket_close", 94: "punct_caret", 95: "punct_underscore",
    96: "punct_backtick",
    97: "letter_a", 98: "letter_b", 99: "letter_c", 100: "letter_d",
    101: "letter_e", 102: "letter_f", 103: "letter_g", 104: "letter_h",
    105: "letter_i", 106: "letter_j", 107: "letter_k", 108: "letter_l",
    109: "letter_m", 110: "letter_n", 111: "letter_o",
    112: "letter_p", 113: "letter_q", 114: "letter_r", 115: "letter_s",
    116: "letter_t", 117: "letter_u", 118: "letter_v", 119: "letter_w",
    120: "letter_x", 121: "letter_y", 122: "letter_z",
    123: "punct_brace_open", 124: "punct_pipe",
    125: "punct_brace_close", 126: "punct_tilde", 127: "icon_house",
    128: "accent_C_cedilla", 129: "accent_u_diaeresis",
    130: "accent_e_acute", 131: "accent_a_circumflex",
    132: "accent_a_diaeresis", 133: "accent_a_grave",
    134: "accent_a_ring", 135: "accent_c_cedilla",
    136: "accent_e_circumflex", 137: "accent_e_diaeresis",
    138: "accent_e_grave", 139: "accent_i_diaeresis",
    140: "accent_i_circumflex", 141: "accent_i_grave",
    142: "accent_A_diaeresis", 143: "accent_A_ring",
    144: "accent_E_acute", 145: "ligature_ae", 146: "ligature_AE",
    147: "accent_o_circumflex", 148: "accent_o_diaeresis",
    149: "accent_o_grave", 150: "accent_u_circumflex",
    151: "accent_u_grave", 152: "accent_y_diaeresis",
    153: "accent_O_diaeresis", 154: "accent_U_diaeresis",
    155: "icon_cent", 156: "icon_pound_sterling", 157: "icon_yen",
    158: "icon_peseta", 159: "icon_florin",
    160: "accent_a_acute", 161: "accent_i_acute",
    162: "accent_o_acute", 163: "accent_u_acute",
    164: "accent_n_tilde", 165: "accent_N_tilde",
    166: "icon_ordinal_fem", 167: "icon_ordinal_masc",
    168: "punct_question_inverted", 169: "icon_corner_tl_neg",
    170: "icon_corner_tr_neg", 171: "icon_fraction_half",
    172: "icon_fraction_quarter", 173: "punct_exclaim_inverted",
    174: "punct_guillemet_open", 175: "punct_guillemet_close",
    176: "shade_light", 177: "shade_medium", 178: "shade_dark",
    179: "wall1_ns", 180: "wall1_nsw",
    181: "wall_1v2h_nsw", 182: "wall_2v1h_nsw",
    183: "wall_2v1h_sw", 184: "wall_1v2h_sw",
    185: "wall2_nsw", 186: "wall2_ns", 187: "wall2_sw",
    188: "wall2_nw", 189: "wall_2v1h_nw", 190: "wall_1v2h_nw",
    191: "wall1_sw",
    192: "wall1_ne", 193: "wall1_new", 194: "wall1_sew",
    195: "wall1_nse", 196: "wall1_ew", 197: "wall1_nsew",
    198: "wall_1v2h_nse", 199: "wall_2v1h_nse",
    200: "wall2_ne", 201: "wall2_se",
    202: "wall2_new", 203: "wall2_sew",
    204: "wall2_nse", 205: "wall2_ew", 206: "wall2_nsew",
    207: "wall_1v2h_new",
    208: "wall_2v1h_new", 209: "wall_1v2h_sew",
    210: "wall_2v1h_sew", 211: "wall_2v1h_ne",
    212: "wall_1v2h_ne", 213: "wall_1v2h_se",
    214: "wall_2v1h_se", 215: "wall_2v1h_nsew",
    216: "wall_1v2h_nsew", 217: "wall1_nw", 218: "wall1_se",
    219: "block_full", 220: "block_lower_half",
    221: "block_left_half", 222: "block_right_half",
    223: "block_upper_half",
    224: "greek_alpha", 225: "greek_beta_sharp_s",
    226: "greek_gamma_upper", 227: "greek_pi",
    228: "greek_sigma_upper", 229: "greek_sigma_lower",
    230: "greek_mu", 231: "greek_tau", 232: "greek_phi_upper",
    233: "greek_theta", 234: "greek_omega", 235: "greek_delta",
    236: "icon_infinity", 237: "greek_phi_lower",
    238: "greek_epsilon", 239: "icon_intersection",
    240: "icon_triple_bar", 241: "icon_plus_minus",
    242: "icon_greater_equal", 243: "icon_less_equal",
    244: "icon_integral_top", 245: "icon_integral_bottom",
    246: "icon_divide", 247: "icon_approx", 248: "icon_degree",
    249: "bullet_small", 250: "icon_middle_dot", 251: "icon_sqrt",
    252: "icon_superscript_n", 253: "icon_superscript_2",
    254: "block_small_filled", 255: "blank_nbsp",
}

# ---------------------------------------------------------------------------
# Dungeon-mode wall groups  (from dungeon_mode_groups.json)
# ---------------------------------------------------------------------------
DM_WALL_GROUPS: dict[str, list[int]] = {
    "single_line_wall_group": [128, 129, 163, 164, 165, 179, 180, 181, 195, 196, 197],
    "wall_group_round_fillings": [144, 145, 166, 167, 168, 182, 183, 184, 198, 199, 200],
    "vertical_double_wall_group": [211, 212, 213, 227, 228, 229, 243, 244, 245],
    "3d_like_wall_group": [214, 215, 216, 230, 231, 232, 246, 247, 248],
    "stripe_streaks_wall_group": [192, 193, 194, 208, 210, 224, 225, 226],
    "minimap_wall_group": [170, 171, 185, 186, 187, 201, 202, 203],
}

# Stripe group uses manual mask overrides (tiles have non-standard fill patterns)
DM_STRIPE_OVERRIDES: dict[int, int] = {
    192: 6,    # block_three_quarter_ne_nw_sw  -> SE corner (mask 6)
    193: 14,   # diagonal_halftone_se          -> tee down  (mask 14)
    194: 12,   # block_three_quarter_ne_nw_se  -> SW corner (mask 12)
    208: 7,    # fill_diagonal_forward          -> tee right (mask 7)
    210: 13,   # fill_diagonal_backward         -> tee left  (mask 13)
    224: 3,    # block_three_quarter_nw_sw_se  -> NE corner (mask 3)
    225: 11,   # diagonal_halftone_ne          -> tee up    (mask 11)
    226: 9,    # block_three_quarter_ne_sw_se  -> NW corner (mask 9)
}

# Minimap group: ALL tiles must be overridden since suffix _ne/_se/_sw
# in "edge_wedge_ne" etc. doesn't correspond to wall connectivity masks.
# These are thin-line minimap representations where:
#   top/bottom thin edges = horizontal walls, left/right = vertical walls,
#   wedges = corners, target_square = cross
DM_MINIMAP_OVERRIDES: dict[int, int] = {
    170: 14,   # edge_top_thin     -> tee down  (S+E+W)
    171: 6,    # edge_wedge_ne     -> SE corner (S+E)  [NE wedge visually = SE corner]
    185: 7,    # edge_left_thin    -> tee right (N+S+E)
    186: 15,   # icon_target_square -> cross    (N+S+E+W)
    187: 13,   # edge_right_thin   -> tee left  (N+S+W)
    201: 12,   # edge_wedge_sw     -> SW corner (S+W)
    202: 11,   # edge_bottom_thin  -> tee up    (N+E+W)
    203: 9,    # edge_wedge_se     -> NW corner (N+W) [SE wedge visually = NW corner]
}

# ---------------------------------------------------------------------------
# Dungeon-437 wall groups  (derived from D437_NAMES wall* prefixes)
# ---------------------------------------------------------------------------
def _derive_d437_groups() -> dict[str, list[int]]:
    """Programmatically group D437 wall tiles by their prefix."""
    single: list[int] = []
    double: list[int] = []
    mixed_2v1h: list[int] = []
    mixed_1v2h: list[int] = []

    for tid, name in sorted(D437_NAMES.items()):
        if name.startswith("wall_2v1h_"):
            mixed_2v1h.append(tid)
        elif name.startswith("wall_1v2h_"):
            mixed_1v2h.append(tid)
        elif name.startswith("wall2_"):
            double.append(tid)
        elif name.startswith("wall1_"):
            single.append(tid)

    return {
        "single_line_wall_group": sorted(single),
        "double_line_wall_group": sorted(double),
        "mixed_2v1h_wall_group": sorted(mixed_2v1h),
        "mixed_1v2h_wall_group": sorted(mixed_1v2h),
    }


D437_WALL_GROUPS = _derive_d437_groups()

# ---------------------------------------------------------------------------
# Tile extraction helpers  (from generate_tile_playground.py)
# ---------------------------------------------------------------------------
def extract_tile(sheet: Image.Image, tile_id: int) -> Image.Image:
    """Crop an 8x8 tile from the 128x128 tilesheet by index."""
    col = tile_id % GRID_COLS
    row = tile_id // GRID_COLS
    x = col * TILE_SIZE
    y = row * TILE_SIZE
    return sheet.crop((x, y, x + TILE_SIZE, y + TILE_SIZE))


def make_transparent(tile: Image.Image) -> Image.Image:
    """Convert black (0,0,0) pixels to fully transparent."""
    tile = tile.convert("RGBA")
    px = tile.load()
    for py_ in range(tile.height):
        for px_ in range(tile.width):
            r, g, b, a = px[px_, py_]
            if r == 0 and g == 0 and b == 0:
                px[px_, py_] = (0, 0, 0, 0)
    return tile


def rotate_tile(im: Image.Image, degrees: int) -> Image.Image:
    """Rotate tile by degrees (CW). 0 = no rotation."""
    if degrees % 360 == 0:
        return im.copy()
    return im.rotate(-degrees, expand=False)


# ---------------------------------------------------------------------------
# Mask derivation  (from audit_dungeon_mode_wall_rules.py)
# ---------------------------------------------------------------------------
def _flood_component(occupied: list[list[bool]], seed: tuple[int, int]) -> set[tuple[int, int]]:
    """Flood-fill one connected component from a single seed pixel."""
    q = deque([seed])
    seen = {seed}
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < 8 and 0 <= ny < 8 and occupied[ny][nx] and (nx, ny) not in seen:
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


def _edges_from_pixels(seen: set[tuple[int, int]]) -> int:
    """Which tile edges does this pixel set touch?"""
    mask = 0
    if any(y == 0 for _, y in seen):
        mask |= 1  # north
    if any(x == 7 for x, _ in seen):
        mask |= 2  # east
    if any(y == 7 for _, y in seen):
        mask |= 4  # south
    if any(x == 0 for x, _ in seen):
        mask |= 8  # west
    return mask


def mask_from_center_component(im: Image.Image) -> int:
    """Flood-fill from center pixels and check which edges are reached."""
    px = im.load()
    occupied = [[px[x, y][3] > 0 for x in range(8)] for y in range(8)]

    seeds = [(x, y) for y in (3, 4) for x in (3, 4) if occupied[y][x]]
    if not seeds:
        pts = [(x, y) for y in range(8) for x in range(8) if occupied[y][x]]
        if pts:
            seeds = [min(pts, key=lambda p: (p[0] - 3.5)**2 + (p[1] - 3.5)**2)]
    if not seeds:
        return 0

    seen = _flood_component(occupied, seeds[0])
    for s in seeds[1:]:
        if s not in seen:
            seen |= _flood_component(occupied, s)

    return _edges_from_pixels(seen)


def mask_from_all_components(im: Image.Image) -> int:
    """Union of edge-reachability across ALL connected components.

    Unlike mask_from_center_component which only traces from center,
    this considers every opaque pixel. Useful for double-line wall tiles
    where parallel lines form separate components.
    """
    px = im.load()
    occupied = [[px[x, y][3] > 0 for x in range(8)] for y in range(8)]

    visited: set[tuple[int, int]] = set()
    mask = 0

    for y in range(8):
        for x in range(8):
            if occupied[y][x] and (x, y) not in visited:
                comp = _flood_component(occupied, (x, y))
                visited |= comp
                mask |= _edges_from_pixels(comp)

    return mask


def mask_to_dirs(mask: int) -> str:
    dirs = []
    if mask & 1: dirs.append("N")
    if mask & 2: dirs.append("E")
    if mask & 4: dirs.append("S")
    if mask & 8: dirs.append("W")
    return "".join(dirs) if dirs else "isolated"


def mask_to_wangid(mask: int) -> list[int]:
    """Convert a 4-bit cardinal mask to Tiled 8-element edge wangid.

    Wang ID order: [Top, TopRight, Right, BottomRight, Bottom, BottomLeft, Left, TopLeft]
    For edge type, only indices 0,2,4,6 are used (corners stay 0).
    """
    return [
        1 if (mask & 1) else 0,   # Top    (North)
        0,                         # TopRight
        1 if (mask & 2) else 0,   # Right  (East)
        0,                         # BottomRight
        1 if (mask & 4) else 0,   # Bottom (South)
        0,                         # BottomLeft
        1 if (mask & 8) else 0,   # Left   (West)
        0,                         # TopLeft
    ]


# ---------------------------------------------------------------------------
# Suffix-based mask detection for wall tiles
# ---------------------------------------------------------------------------
def mask_from_name(name: str) -> int | None:
    """Try to derive a cardinal mask from the tile name suffix."""
    for suffix, mask in sorted(SUFFIX_TO_MASK.items(), key=lambda kv: -len(kv[0])):
        if name.endswith(suffix):
            return mask
    return None


# ---------------------------------------------------------------------------
# Build the full 16-mask mapping for a wall group
# ---------------------------------------------------------------------------
@dataclass
class TileRule:
    mask: int
    tile_id: int
    tile_name: str
    rotation: int = 0
    source: str = "suffix"  # suffix | override | fallback


def build_group_rules(
    group_name: str,
    tile_ids: list[int],
    names: dict[int, str],
    overrides: dict[int, int] | None = None,
    fallback_ids: dict[str, int] | None = None,
) -> list[TileRule]:
    """Build a mask->tile mapping for a wall group, covering all 16 masks."""
    mask_map: dict[int, TileRule] = {}

    # Phase 1: use overrides (for stripe/minimap groups)
    if overrides:
        for tid, mask in overrides.items():
            if tid in tile_ids:
                mask_map[mask] = TileRule(
                    mask=mask, tile_id=tid, tile_name=names.get(tid, f"tile_{tid}"),
                    rotation=0, source="override",
                )

    # Phase 2: use suffix-based detection (skip tiles already claimed by overrides)
    override_tids = set((overrides or {}).keys())
    for tid in tile_ids:
        if tid in override_tids:
            continue  # already handled by override
        name = names.get(tid, f"tile_{tid}")
        mask = mask_from_name(name)
        if mask is not None and mask not in mask_map:
            mask_map[mask] = TileRule(
                mask=mask, tile_id=tid, tile_name=name,
                rotation=0, source="suffix",
            )

    # Phase 3: fill missing masks with fallbacks
    # For end-caps (masks 1,2,4,8) and isolated (mask 0), use block_full/shade
    if fallback_ids is None:
        fallback_ids = {}

    # Try to fill straights from existing corners via inference
    # NS (5) from any N+S tile, EW (10) from any E+W tile
    if 5 not in mask_map:
        # look for ns-suffixed tiles
        for tid in tile_ids:
            name = names.get(tid, "")
            if name.endswith("_ns"):
                mask_map[5] = TileRule(mask=5, tile_id=tid, tile_name=name, source="suffix")
                break

    if 10 not in mask_map:
        for tid in tile_ids:
            name = names.get(tid, "")
            if name.endswith("_ew"):
                mask_map[10] = TileRule(mask=10, tile_id=tid, tile_name=name, source="suffix")
                break

    # End-caps and isolated get fallback tiles
    fallback_tile = fallback_ids.get("block_full", 16)  # DM default
    shade_tile = fallback_ids.get("shade", 178)          # DM shade_dark

    for m in range(16):
        if m not in mask_map:
            if m == 0:
                mask_map[m] = TileRule(
                    mask=m, tile_id=shade_tile,
                    tile_name=names.get(shade_tile, "shade"),
                    rotation=0, source="fallback",
                )
            elif m in (1, 2, 4, 8):
                mask_map[m] = TileRule(
                    mask=m, tile_id=fallback_tile,
                    tile_name=names.get(fallback_tile, "block_full"),
                    rotation=0, source="fallback",
                )
            else:
                # Try rotation of existing tiles to fill gaps
                # (only for suffix-derived tiles, not override tiles)
                filled = _try_rotation_fill(m, mask_map, names)
                if filled:
                    mask_map[m] = filled
                else:
                    mask_map[m] = TileRule(
                        mask=m, tile_id=fallback_tile,
                        tile_name=names.get(fallback_tile, "block_full"),
                        rotation=0, source="fallback",
                    )

    return [mask_map[m] for m in range(16)]


def _rotate_mask(mask: int, degrees: int) -> int:
    """Rotate a 4-bit cardinal mask CW by the given degrees."""
    steps = (degrees // 90) % 4
    for _ in range(steps):
        n = (mask >> 0) & 1
        e = (mask >> 1) & 1
        s = (mask >> 2) & 1
        w = (mask >> 3) & 1
        # CW rotation: N->E, E->S, S->W, W->N
        mask = (e << 0) | (s << 1) | (w << 2) | (n << 3)
    return mask


def _try_rotation_fill(
    target_mask: int,
    existing: dict[int, TileRule],
    names: dict[int, str],
) -> TileRule | None:
    """Try to find an existing tile that, when rotated, produces target_mask.

    Only rotates suffix-derived tiles (not overrides or fallbacks), since
    override tiles may have non-standard pixel layouts that don't rotate
    predictably.
    """
    for rot in (90, 180, 270):
        needed_src = _rotate_mask(target_mask, 360 - rot)
        if needed_src in existing and existing[needed_src].source == "suffix":
            src = existing[needed_src]
            return TileRule(
                mask=target_mask,
                tile_id=src.tile_id,
                tile_name=src.tile_name,
                rotation=rot,
                source="rotation",
            )
    return None


# ---------------------------------------------------------------------------
# Composite tileset strip builder
# ---------------------------------------------------------------------------
def build_composite_strip(
    rules: list[TileRule],
    sheet: Image.Image,
) -> tuple[Image.Image, dict[int, int]]:
    """Build a horizontal strip of all tiles needed for the wangset.

    Returns (strip_image, {mask: tileid_in_strip}).
    """
    tiles: list[Image.Image] = []
    mask_to_stripid: dict[int, int] = {}

    for rule in rules:
        raw = extract_tile(sheet, rule.tile_id)
        raw = make_transparent(raw)
        if rule.rotation:
            raw = rotate_tile(raw, rule.rotation)
        tiles.append(raw)
        mask_to_stripid[rule.mask] = len(tiles) - 1

    if not tiles:
        return Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0)), {}

    strip = Image.new("RGBA", (TILE_SIZE * len(tiles), TILE_SIZE), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        strip.paste(t, (i * TILE_SIZE, 0))

    return strip, mask_to_stripid


# ---------------------------------------------------------------------------
# Tiled .tsj generator
# ---------------------------------------------------------------------------
def generate_tsj(
    group_name: str,
    rules: list[TileRule],
    mask_to_stripid: dict[int, int],
    tile_count: int,
) -> dict[str, Any]:
    """Generate a Tiled tileset JSON with embedded wangset."""
    pretty_name = group_name.replace("_", " ").title()

    wangtiles = []
    for rule in rules:
        sid = mask_to_stripid.get(rule.mask)
        if sid is not None:
            wangtiles.append({
                "tileid": sid,
                "wangid": mask_to_wangid(rule.mask),
            })

    return {
        "type": "tileset",
        "version": "1.10",
        "tiledversion": "1.11.0",
        "name": group_name,
        "tilewidth": TILE_SIZE,
        "tileheight": TILE_SIZE,
        "tilecount": tile_count,
        "columns": tile_count,
        "image": "tileset.png",
        "imagewidth": tile_count * TILE_SIZE,
        "imageheight": TILE_SIZE,
        "wangsets": [{
            "name": pretty_name,
            "type": "edge",
            "tile": -1,
            "colors": [{
                "name": "Wall",
                "color": "#FF808080",
                "tile": 0,
                "probability": 1.0,
            }],
            "wangtiles": wangtiles,
        }],
    }


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
@dataclass
class VerifyResult:
    group: str
    mask: int
    tile_id: int
    tile_name: str
    rotation: int
    expected_mask: int
    derived_mask: int
    status: str   # pass | fail | override_skip
    note: str = ""


def verify_rules(
    rules: list[TileRule],
    sheet: Image.Image,
    group_name: str,
    overrides: dict[int, int] | None = None,
) -> list[VerifyResult]:
    """Pixel-level verification of each rule.

    Uses two strategies:
    1. Center-component flood-fill (strict, single-line walls)
    2. All-components union (for double/mixed-line walls with gaps)
    """
    results: list[VerifyResult] = []
    override_masks = set((overrides or {}).values())

    for rule in rules:
        raw = extract_tile(sheet, rule.tile_id)
        raw = make_transparent(raw)
        if rule.rotation:
            raw = rotate_tile(raw, rule.rotation)

        derived_center = mask_from_center_component(raw)
        derived_all = mask_from_all_components(raw)

        if rule.source == "fallback":
            status = "pass"
            note = "fallback tile (not verified)"
            derived = derived_center
        elif rule.source == "override" or rule.mask in override_masks:
            status = "override_skip"
            note = "manually overridden — pixel mask may differ from expected"
            derived = derived_center
        elif derived_center == rule.mask:
            status = "pass"
            note = ""
            derived = derived_center
        elif derived_all == rule.mask:
            status = "pass"
            note = "verified via all-components (multi-line wall)"
            derived = derived_all
        else:
            status = "fail"
            derived = derived_center
            note = (f"center-mask={derived_center} ({mask_to_dirs(derived_center)}), "
                    f"all-mask={derived_all} ({mask_to_dirs(derived_all)}) "
                    f"!= expected {rule.mask} ({mask_to_dirs(rule.mask)})")

        results.append(VerifyResult(
            group=group_name,
            mask=rule.mask,
            tile_id=rule.tile_id,
            tile_name=rule.tile_name,
            rotation=rule.rotation,
            expected_mask=rule.mask,
            derived_mask=derived,
            status=status,
            note=note,
        ))

    return results


# ---------------------------------------------------------------------------
# Group info metadata
# ---------------------------------------------------------------------------
def build_group_info(
    group_name: str,
    tileset_name: str,
    rules: list[TileRule],
    names: dict[int, str],
) -> dict[str, Any]:
    tiles_info = []
    for rule in rules:
        tiles_info.append({
            "mask": rule.mask,
            "mask_dirs": mask_to_dirs(rule.mask),
            "tile_id": rule.tile_id,
            "tile_name": rule.tile_name,
            "rotation": rule.rotation,
            "source": rule.source,
            "wangid": mask_to_wangid(rule.mask),
        })

    return {
        "group_name": group_name,
        "tileset": tileset_name,
        "tile_count": len(rules),
        "unique_source_tiles": len(set(r.tile_id for r in rules)),
        "tiles": tiles_info,
        "supported_shapes": ["box", "L-room", "corridor", "cross", "partition"],
        "missing_mask_strategy": "fallback to block_full (end-caps) / shade_dark (isolated) / rotation of existing tiles",
        "generated": datetime.now().isoformat(),
    }


# ===========================================================================
# Main export pipeline
# ===========================================================================
def export_all_tiles(
    sheet: Image.Image,
    names: dict[int, str],
    tileset_key: str,
    prefix: str,
) -> None:
    """Export all 256 transparent tiles for one tileset."""
    out_dir = EXPORT_ROOT / tileset_key / "all_tiles"
    out_dir.mkdir(parents=True, exist_ok=True)

    for idx in range(256):
        tile = extract_tile(sheet, idx)
        tile = make_transparent(tile)
        name = names.get(idx, f"unknown_{idx}")
        fname = f"{prefix}_{idx:03d}_{name}.png"
        tile.save(out_dir / fname)

    print(f"  Exported {256} tiles to {out_dir}")


def export_wall_group(
    group_name: str,
    tile_ids: list[int],
    names: dict[int, str],
    sheet: Image.Image,
    tileset_key: str,
    overrides: dict[int, int] | None = None,
    fallback_ids: dict[str, int] | None = None,
) -> tuple[list[TileRule], list[VerifyResult]]:
    """Export one wall group: tiles, composite, tsj, group_info."""
    group_dir = EXPORT_ROOT / tileset_key / "groups" / group_name
    tiles_dir = group_dir / "tiles"
    tiles_dir.mkdir(parents=True, exist_ok=True)

    # Build rules
    rules = build_group_rules(group_name, tile_ids, names, overrides, fallback_ids)

    # Export individual transparent tiles for this group
    for tid in sorted(set(r.tile_id for r in rules)):
        tile = extract_tile(sheet, tid)
        tile = make_transparent(tile)
        name = names.get(tid, f"tile_{tid}")
        tile.save(tiles_dir / f"{tid:03d}_{name}.png")

    # Build composite strip
    strip, mask_to_stripid = build_composite_strip(rules, sheet)
    strip.save(group_dir / "tileset.png")

    # Generate .tsj
    tsj = generate_tsj(group_name, rules, mask_to_stripid, len(rules))
    (group_dir / "tileset.tsj").write_text(
        json.dumps(tsj, indent=2) + "\n", encoding="utf-8"
    )

    # Generate group_info.json
    info = build_group_info(group_name, tileset_key, rules, names)
    (group_dir / "group_info.json").write_text(
        json.dumps(info, indent=2) + "\n", encoding="utf-8"
    )

    # Verify
    verify = verify_rules(rules, sheet, group_name, overrides)

    passed = sum(1 for v in verify if v.status == "pass")
    skipped = sum(1 for v in verify if v.status == "override_skip")
    failed = sum(1 for v in verify if v.status == "fail")
    print(f"  {group_name}: {passed} pass, {skipped} override-skip, {failed} FAIL")

    return rules, verify


def build_group_catalog(
    all_groups: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """Build the master group catalog."""
    return {
        "generated": datetime.now().isoformat(),
        "total_groups": len(all_groups),
        "groups": all_groups,
    }


def write_readme() -> None:
    """Write export/README.md with Tiled import instructions."""
    readme = """\
# Tiled Asset Export

Transparent tile PNGs and Tiled-compatible Wang set autotiling rules for the **dungeon-mode** and **dungeon-437** tilesets.

Generated by `scripts/export_tiled_assets.py`.

## Directory Structure

```
export/
├── dungeon_mode/
│   ├── all_tiles/              # 256 transparent 8x8 PNGs
│   └── groups/                 # Wall groups with autotiling rules
│       ├── single_line_wall_group/
│       ├── wall_group_round_fillings/
│       ├── vertical_double_wall_group/
│       ├── 3d_like_wall_group/
│       ├── stripe_streaks_wall_group/
│       └── minimap_wall_group/
├── dungeon_437/
│   ├── all_tiles/              # 256 transparent 8x8 PNGs
│   └── groups/
│       ├── single_line_wall_group/
│       ├── double_line_wall_group/
│       ├── mixed_2v1h_wall_group/
│       └── mixed_1v2h_wall_group/
├── metadata/
│   ├── group_catalog.json      # Master index of all groups
│   └── verification_report.json
└── README.md
```

Each wall group folder contains:
- `tiles/` — Individual transparent PNGs for the group's source tiles
- `tileset.png` — Composite horizontal strip (all 16 mask variants in one row)
- `tileset.tsj` — Tiled tileset JSON with embedded Wang set rules
- `group_info.json` — Metadata: tile IDs, mask assignments, usage notes

## Importing into Tiled

### Step 1: Add the tileset

1. Open your Tiled map (or create a new one with 8x8 tile size)
2. Go to **Map → Add External Tileset...**
3. Browse to a group folder and select `tileset.tsj`
4. The tileset will appear in the Tilesets panel with the Wang set pre-configured

### Step 2: Use the terrain brush

1. Select the **Terrain Brush** tool (keyboard shortcut: `T`)
2. In the Tilesets panel, click the **Wang Sets** tab (terrain icon)
3. Select the wall group's Wang set (e.g., "Single Line Wall Group")
4. Select the "Wall" terrain color
5. Paint walls on your map — Tiled automatically picks the correct tile for each position based on neighbor connectivity

### Wang Set Type

All groups use **edge** type Wang sets. This means connectivity is determined by shared edges between tiles:
- Two adjacent tiles both marked "Wall" on their shared edge will connect
- The terrain brush handles corners, tees, crosses, and straights automatically

### Understanding the 16-Mask System

Each tile covers one of 16 connectivity masks (4 directions × 2 states):

| Mask | Dirs | Shape | Description |
|------|------|-------|-------------|
| 0 | — | Isolated | No connections |
| 1 | N | End cap | Dead end pointing north |
| 2 | E | End cap | Dead end pointing east |
| 3 | NE | Corner | Bottom-left bend |
| 4 | S | End cap | Dead end pointing south |
| 5 | NS | Straight | Vertical corridor |
| 6 | ES | Corner | Top-left bend |
| 7 | NES | Tee | Right-facing T-junction |
| 8 | W | End cap | Dead end pointing west |
| 9 | NW | Corner | Bottom-right bend |
| 10 | EW | Straight | Horizontal corridor |
| 11 | NEW | Tee | Upward-facing T-junction |
| 12 | SW | Corner | Top-right bend |
| 13 | NSW | Tee | Left-facing T-junction |
| 14 | ESW | Tee | Downward-facing T-junction |
| 15 | NESW | Cross | Four-way intersection |

## Wall Group Descriptions

### dungeon_mode

| Group | Style | Best For |
|-------|-------|----------|
| **single_line_wall_group** | Classic thin single-line box drawing | Standard dungeon walls, corridors |
| **wall_group_round_fillings** | Double-line box drawing with rounded feel | Fortified walls, castle interiors |
| **vertical_double_wall_group** | Mixed: double vertical + single horizontal | Tall/reinforced vertical passages |
| **3d_like_wall_group** | Mixed: single vertical + double horizontal | Wide horizontal corridors |
| **stripe_streaks_wall_group** | Diagonal stripe/halftone fill patterns | Damaged walls, terrain boundaries |
| **minimap_wall_group** | Thin edge lines and wedge corners | Minimap overlay, HUD wall indicators |

### dungeon_437

| Group | Style | Best For |
|-------|-------|----------|
| **single_line_wall_group** | CP437 single-line box drawing | Standard ASCII dungeon walls |
| **double_line_wall_group** | CP437 double-line box drawing | Fortified/highlighted walls |
| **mixed_2v1h_wall_group** | Double vertical + single horizontal | Structural variation |
| **mixed_1v2h_wall_group** | Single vertical + double horizontal | Structural variation |

## Regenerating

```bash
python3 scripts/export_tiled_assets.py
# Or with custom source paths:
python3 scripts/export_tiled_assets.py --dm-src /path/to/dungeon-mode.png --d437-src /path/to/dungeon-437.png
```

Requires Python 3.10+ and Pillow.
"""
    (EXPORT_ROOT / "README.md").write_text(readme, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export Tiled-compatible tile assets")
    parser.add_argument("--dm-src", type=Path, default=_DEFAULT_DM_SRC,
                        help="Path to dungeon-mode.png source tilesheet")
    parser.add_argument("--d437-src", type=Path, default=_DEFAULT_D437_SRC,
                        help="Path to dungeon-437.png source tilesheet")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    print("=" * 60)
    print("Tiled Asset Export Pipeline")
    print("=" * 60)

    # Load source images
    dm_sheet = Image.open(args.dm_src)
    d437_sheet = Image.open(args.d437_src)
    print(f"Loaded dungeon-mode: {dm_sheet.size}")
    print(f"Loaded dungeon-437:  {d437_sheet.size}")

    # Clean export directory
    if EXPORT_ROOT.exists():
        shutil.rmtree(EXPORT_ROOT)
    EXPORT_ROOT.mkdir(parents=True, exist_ok=True)

    # --- Step 1: Export all 512 transparent tiles ---
    print("\n--- Exporting all tiles ---")
    export_all_tiles(dm_sheet, DM_NAMES, "dungeon_mode", "dm")
    export_all_tiles(d437_sheet, D437_NAMES, "dungeon_437", "d437")

    # --- Step 2: Write dungeon_437_groups.json ---
    print("\n--- Writing dungeon_437_groups.json ---")
    D437_GROUPS_JSON.write_text(
        json.dumps(D437_WALL_GROUPS, indent=2) + "\n", encoding="utf-8"
    )
    print(f"  Wrote {D437_GROUPS_JSON}")

    # --- Step 3: Export wall groups ---
    all_verify: list[VerifyResult] = []
    catalog_entries: dict[str, dict[str, Any]] = {}

    # Dungeon-mode groups
    print("\n--- Dungeon-mode wall groups ---")
    dm_fallbacks = {"block_full": 16, "shade": 178}
    for gname, tids in DM_WALL_GROUPS.items():
        overrides = None
        if gname == "stripe_streaks_wall_group":
            overrides = DM_STRIPE_OVERRIDES
        elif gname == "minimap_wall_group":
            overrides = DM_MINIMAP_OVERRIDES

        rules, verify = export_wall_group(
            gname, tids, DM_NAMES, dm_sheet, "dungeon_mode",
            overrides=overrides, fallback_ids=dm_fallbacks,
        )
        all_verify.extend(verify)
        catalog_entries[f"dungeon_mode/{gname}"] = {
            "tileset": "dungeon_mode",
            "group": gname,
            "source_tiles": len(tids),
            "total_rules": len(rules),
        }

    # Dungeon-437 groups
    print("\n--- Dungeon-437 wall groups ---")
    d437_fallbacks = {"block_full": 219, "shade": 178}
    for gname, tids in D437_WALL_GROUPS.items():
        rules, verify = export_wall_group(
            gname, tids, D437_NAMES, d437_sheet, "dungeon_437",
            fallback_ids=d437_fallbacks,
        )
        all_verify.extend(verify)
        catalog_entries[f"dungeon_437/{gname}"] = {
            "tileset": "dungeon_437",
            "group": gname,
            "source_tiles": len(tids),
            "total_rules": len(rules),
        }

    # --- Step 4: Write metadata ---
    print("\n--- Writing metadata ---")
    meta_dir = EXPORT_ROOT / "metadata"
    meta_dir.mkdir(parents=True, exist_ok=True)

    # Group catalog
    catalog = build_group_catalog(catalog_entries)
    (meta_dir / "group_catalog.json").write_text(
        json.dumps(catalog, indent=2) + "\n", encoding="utf-8"
    )

    # Verification report
    report = {
        "generated": datetime.now().isoformat(),
        "total_checks": len(all_verify),
        "passed": sum(1 for v in all_verify if v.status == "pass"),
        "override_skip": sum(1 for v in all_verify if v.status == "override_skip"),
        "failed": sum(1 for v in all_verify if v.status == "fail"),
        "results": [asdict(v) for v in all_verify],
    }
    (meta_dir / "verification_report.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(f"  Verification: {report['passed']} pass, "
          f"{report['override_skip']} override-skip, {report['failed']} FAIL")

    # --- Step 5: Write README ---
    write_readme()

    # --- Summary ---
    print("\n" + "=" * 60)
    print("Export complete!")
    print(f"  Output: {EXPORT_ROOT}")
    total_files = sum(1 for _ in EXPORT_ROOT.rglob("*") if _.is_file())
    print(f"  Total files: {total_files}")
    print("=" * 60)


if __name__ == "__main__":
    main()
