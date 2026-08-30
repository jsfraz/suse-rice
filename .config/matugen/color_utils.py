#!/usr/bin/env python3
"""
Image Color Extraction and Manipulation Utility.

This script extracts the dominant color from an image and provides various
color manipulation utilities including:
- Extracting dominant color from images
- Converting colors between RGB, hex, and named color formats
- Shifting hue to create lighter/warmer color variations

Dependencies:
    python-pillow

Usage:
    python color_utils.py [-hex] [-color2hex] [-hex2color] [-lighten] <image_path|color_name|hex>

Examples:
    python color_utils.py image.jpg           # Get color name from image
    python color_utils.py -hex image.jpg      # Get hex color from image
    python color_utils.py -color2hex red      # Convert 'red' to hex
    python color_utils.py -hex2color '#3232ff'  # Named color from hex (by hue)
    python color_utils.py -hex -lighten img.jpg  # Get lightened hex from image
"""

import sys
from PIL import Image
from collections import defaultdict
import colorsys

COLOR_MAP = {
    "red": "#cc0000",
    "orange": "#e59400",
    "yellow": "#e5e500",
    "green": "#198c19",
    "teal": "#007373",
    "blue": "#3232ff",
    "purple": "#8c198c",
    "pink": "#ff19ff",
}

def get_dominant_color(image_path):
    """
    Extract the color a viewer would call dominant.

    Frequency of a single RGB triple is a poor proxy: dark wallpapers
    (navy subway, charcoal shards) have one near-black pixel repeated
    thousands of times. Instead, ignore gray/black/white, weight the
    rest by saturation² × value², and take the weighted-average RGB of
    the strongest 10° hue bin.

    Args:
        image_path: Path to the image file to analyze.

    Returns:
        A tuple of (R, G, B) values representing the dominant color.
        Returns (128, 128, 128) as fallback if no suitable pixels found.
    """
    img = Image.open(image_path)
    img = img.convert('RGB')
    img = img.resize((150, 150), Image.Resampling.BOX)

    # hue_bin -> [weight, r*w, g*w, b*w]
    buckets = defaultdict(lambda: [0.0, 0.0, 0.0, 0.0])
    for r, g, b in img.get_flattened_data():
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        if s < 0.30 or v < 0.25 or v > 0.95:
            continue
        weight = (s ** 2) * (v ** 2)
        hue_bin = int((h * 360) // 10) % 36
        agg = buckets[hue_bin]
        agg[0] += weight
        agg[1] += r * weight
        agg[2] += g * weight
        agg[3] += b * weight

    if not buckets:
        return (128, 128, 128)

    weight, wr, wg, wb = max(buckets.values(), key=lambda item: item[0])
    return (int(wr / weight), int(wg / weight), int(wb / weight))

def rgb_to_hex(rgb):
    """
    Convert an RGB color tuple to a hexadecimal color string.

    Args:
        rgb: A tuple of (R, G, B) integer values (0-255 each).

    Returns:
        A hex color string in the format '#rrggbb'.

    Example:
        >>> rgb_to_hex((255, 128, 0))
        '#ff8000'
    """
    return "#{:02x}{:02x}{:02x}".format(rgb[0], rgb[1], rgb[2])

def color_name_to_hex(color_name):
    """
    Convert a predefined color name to its corresponding hex code.

    Supports a limited set of color names: red, orange, yellow, green,
    teal, blue, purple, and pink. The lookup is case-insensitive.

    Args:
        color_name: A string representing the color name.

    Returns:
        A hex color string in the format '#rrggbb'.
        Returns '#808080' (gray) if the color name is not recognized.

    Example:
        >>> color_name_to_hex('blue')
        '#3232ff'
    """
    return COLOR_MAP.get(color_name.lower(), "#808080")


def hex_to_rgb(hex_color):
    """
    Parse a hex color string into an (R, G, B) tuple.

    Accepts '#rrggbb' or 'rrggbb'.
    """
    hex_color = hex_color.lstrip("#")
    if len(hex_color) != 6:
        raise ValueError(f"invalid hex color: #{hex_color}")
    return (
        int(hex_color[0:2], 16),
        int(hex_color[2:4], 16),
        int(hex_color[4:6], 16),
    )


def hex_to_nearest_color_name(hex_color):
    """
    Map a hex color to a named palette color by hue.

    Uses the same HSV ranges as rgb_to_color_name, so -hex2color matches
    the no-flag image → name path. RGB distance to COLOR_MAP swatches is
    not used: a dark navy is blue, not the nearest dark green chip.
    """
    return rgb_to_color_name(hex_to_rgb(hex_color))

def lighten_hex_color(hex_color, hue_shift=45):
    """
    Shift the hue of a color to create a 'lighter' or warmer appearance.

    This function rotates the hue in the HSV color space, creating
    transitions like red -> orange -> yellow, or blue -> cyan -> green.
    It also slightly increases brightness (by 10%) and decreases
    saturation (by 10%) for a softer, lighter feel.

    Args:
        hex_color: A hex color string (with or without leading '#').
        hue_shift: The amount to shift the hue in degrees (0-360).
                   Default is 45 degrees.

    Returns:
        A hex color string in the format '#rrggbb' with the shifted hue.

    Example:
        >>> lighten_hex_color('#cc0000')  # red
        '#cc6600'  # shifts toward orange
    """
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    
    # Convert to HSV
    h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
    
    # Shift hue (h is 0-1, so divide degrees by 360)
    h = (h + hue_shift / 360.0) % 1.0
    
    # Slightly increase brightness and saturation for a "lighter" feel
    v = min(1.0, v * 1.1)
    s = min(1.0, s * 0.9)
    
    # Convert back to RGB
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    r = int(r * 255)
    g = int(g * 255)
    b = int(b * 255)
    
    return "#{:02x}{:02x}{:02x}".format(r, g, b)

def rgb_to_color_name(rgb):
    """
    Convert an RGB color to a human-readable color name.

    Maps the RGB color to one of eight basic color names based on the
    hue value in HSV color space. Ranges include every COLOR_MAP swatch
    so -color2hex and -hex2color stay inverses. Cyan (180–185+) counts
    as blue — that is what these wallpapers look like, not teal/green.
        - red:    345-360 and 0-15
        - orange: 15-45
        - yellow: 45-65
        - green:  65-150
        - teal:   150-185
        - blue:   185-260
        - purple: 260-290, or 290-330 when dark
        - pink:   290-345 when bright (split with red near 330)

    Args:
        rgb: A tuple of (R, G, B) integer values (0-255 each).

    Returns:
        A string representing the color name (one of: red, orange,
        yellow, green, teal, blue, purple, pink). Defaults to 'blue'
        as a fallback.

    Example:
        >>> rgb_to_color_name((255, 128, 0))
        'orange'
    """
    r, g, b = rgb
    h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
    
    # Convert hue (0-1) to degrees (0-360)
    hue = h * 360
    
    # Map hue to colors. Bounds are chosen so each COLOR_MAP hex
    # (orange 39°, teal 180°, purple/pink both 300°) maps back to itself.
    if hue < 15 or hue >= 345:
        return "red"
    elif hue < 45:
        return "orange"
    elif hue < 65:
        return "yellow"
    elif hue < 150:
        return "green"
    elif hue < 185:
        return "teal"
    elif hue < 260:
        return "blue"
    elif hue < 290:
        return "purple"
    elif hue < 330:
        # Purple and pink share ~300°; pink is the bright swatch.
        return "pink" if v > 0.75 else "purple"
    elif hue < 345:
        return "pink" if v > 0.6 else "red"
    else:
        return "blue"

def main():
    """
    Main entry point for the color extraction utility.

    Parses command-line arguments and executes the appropriate action:
        - No flags: Extract dominant color name from image
        - -hex: Output color as hex code instead of name
        - -color2hex: Convert a color name to hex code
        - -hex2color: Convert a hex code to a named palette color by hue
        - -lighten: Apply hue shift to lighten the resulting color

    The flags can be combined (e.g., -hex -lighten).

    Exit codes:
        0: Success
        1: Error (invalid arguments or processing failure)
    """
    if len(sys.argv) < 2:
        print("Usage: python color_utils.py [-hex] [-color2hex] [-hex2color] [-lighten] <image_path|color_name|hex>", file=sys.stderr)
        sys.exit(1)
    
    hex_output = False
    color2hex_mode = False
    hex2color_mode = False
    lighten_mode = False
    target = None
    
    # Parse arguments
    for i in range(1, len(sys.argv)):
        if sys.argv[i] == "-hex":
            hex_output = True
        elif sys.argv[i] == "-color2hex":
            color2hex_mode = True
        elif sys.argv[i] == "-hex2color":
            hex2color_mode = True
        elif sys.argv[i] == "-lighten":
            lighten_mode = True
        else:
            target = sys.argv[i]
    
    if not target:
        print("Usage: python color_utils.py [-hex] [-color2hex] [-hex2color] [-lighten] <image_path|color_name|hex>", file=sys.stderr)
        sys.exit(1)
    
    try:
        if hex2color_mode:
            print(hex_to_nearest_color_name(target))
        elif color2hex_mode:
            # Convert color name to hex
            hex_code = color_name_to_hex(target)
            if lighten_mode:
                hex_code = lighten_hex_color(hex_code)
            print(hex_code)
        else:
            # Get dominant color from image
            dominant_rgb = get_dominant_color(target)
            
            if hex_output:
                hex_code = rgb_to_hex(dominant_rgb)
                if lighten_mode:
                    hex_code = lighten_hex_color(hex_code)
                print(hex_code)
            else:
                color_name = rgb_to_color_name(dominant_rgb)
                print(color_name)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()