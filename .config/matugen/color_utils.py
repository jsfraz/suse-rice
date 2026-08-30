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
    python color_utils.py -hex2color '#3232ff'  # Nearest named color from hex
    python color_utils.py -hex -lighten img.jpg  # Get lightened hex from image
"""

import sys
from PIL import Image
from collections import Counter
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
    Extract the most dominant color from an image.

    Opens the image, resizes it to 150x150 pixels for faster processing,
    and finds the most frequently occurring color. Very dark (sum < 50)
    and very light (sum > 700) pixels are filtered out to avoid
    blacks/whites dominating the result.

    Args:
        image_path: Path to the image file to analyze.

    Returns:
        A tuple of (R, G, B) values representing the dominant color.
        Returns (128, 128, 128) as fallback if no suitable pixels found.
    """
    img = Image.open(image_path)
    img = img.convert('RGB')
    img = img.resize((150, 150))  # Reduce size for faster processing
    
    pixels = list(img.get_flattened_data())
    
    # Filter out very dark and very light pixels
    pixels = [p for p in pixels if sum(p) > 50 and sum(p) < 700]
    
    if not pixels:
        return (128, 128, 128)  # Fallback
    
    # Find the most common color
    most_common = Counter(pixels).most_common(1)[0][0]
    return most_common

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
    Map a hex color to the nearest named palette color.

    Distance is Euclidean in RGB against COLOR_MAP (the same names used
    by -color2hex and crystal-remix icon themes).
    """
    r, g, b = hex_to_rgb(hex_color)
    nearest = None
    nearest_dist = None
    for name, palette_hex in COLOR_MAP.items():
        pr, pg, pb = hex_to_rgb(palette_hex)
        dist = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
        if nearest_dist is None or dist < nearest_dist:
            nearest = name
            nearest_dist = dist
    return nearest

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
    hue value in HSV color space. The hue ranges (in degrees) are:
        - red:    345-360 and 0-15
        - orange: 15-35
        - yellow: 35-65
        - green:  65-150
        - teal:   150-180
        - blue:   180-260
        - purple: 260-290
        - pink:   290-345 (with brightness consideration near red)

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
    
    # Map hue to colors
    if hue < 15 or hue >= 345:
        return "red"
    elif 15 <= hue < 35:
        return "orange"
    elif 35 <= hue < 65:
        return "yellow"
    elif 65 <= hue < 150:
        return "green"
    elif 150 <= hue < 180:
        return "teal"
    elif 180 <= hue < 260:
        return "blue"
    elif 260 <= hue < 290:
        return "purple"
    elif 290 <= hue < 330:
        return "pink"
    elif 330 <= hue < 345:
        # Area between pink and red - decision based on brightness
        if v > 0.6:
            return "pink"
        else:
            return "red"
    else:
        return "blue"  # Fallback

def main():
    """
    Main entry point for the color extraction utility.

    Parses command-line arguments and executes the appropriate action:
        - No flags: Extract dominant color name from image
        - -hex: Output color as hex code instead of name
        - -color2hex: Convert a color name to hex code
        - -hex2color: Convert a hex code to the nearest named palette color
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