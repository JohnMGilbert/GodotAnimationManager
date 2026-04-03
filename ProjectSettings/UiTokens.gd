extends RefCounted
class_name UiTokens

# Shared UI tokens for scripts and future theme generation.
# Scene files should prefer inheriting Theme resources, while code can use
# these constants when a color, size, or spacing value is needed directly.

const COLOR_SURFACE := Color8(196, 190, 187)
const COLOR_BORDER := Color8(39, 41, 41)
const COLOR_ACCENT_PRIMARY := Color8(73, 71, 134)
const COLOR_ACCENT_SECONDARY := Color8(154, 34, 87)

const WINDOW_MARGIN := 12
const DIALOG_MARGIN := 10
const SECTION_SPACING := 8
const BUTTON_MIN_WIDTH := 180
const BUTTON_MIN_WIDTH_SMALL := 140
