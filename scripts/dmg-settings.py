"""Finder layout for the drag-to-Applications installer (dmgbuild 1.6.7)."""
import os

root = defines["root"]
files = [os.path.join(root, "build", "stopwatch.app")]
symlinks = {"Applications": "/Applications"}
background = os.path.join(root, "assets", "installer-background.png")
icon = os.path.join(root, "assets", "AppIcon.icns")
format = "UDZO"
filesystem = "HFS+"
window_rect = ((100, 100), (640, 400))
icon_locations = {"stopwatch.app": (175, 200), "Applications": (465, 200)}
icon_size = 96
text_size = 14
label_pos = "bottom"
default_view = "icon-view"
show_status_bar = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
include_icon_view_settings = True
include_list_view_settings = False
