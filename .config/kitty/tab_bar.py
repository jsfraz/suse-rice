from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, draw_title
from kitty.utils import color_as_int

LEFT_CAP = ""
RIGHT_CAP = ""


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    default_bg = as_rgb(color_as_int(draw_data.default_bg))
    tab_bg = screen.cursor.bg
    tab_fg = screen.cursor.fg

    screen.cursor.bg = default_bg
    screen.cursor.fg = tab_bg
    screen.draw(LEFT_CAP)

    screen.cursor.bg = tab_bg
    screen.cursor.fg = tab_fg
    draw_title(draw_data, screen, tab, index, max_tab_length)

    extra = screen.cursor.x + 2 - before - max_tab_length
    if extra > 0:
        screen.cursor.x -= extra + 1
        screen.draw("…")

    screen.cursor.fg = tab_bg
    screen.cursor.bg = default_bg
    screen.draw(RIGHT_CAP)

    screen.cursor.fg = default_bg
    screen.cursor.bg = default_bg
    screen.cursor.bold = screen.cursor.italic = False
    screen.draw("  ")
    return screen.cursor.x
