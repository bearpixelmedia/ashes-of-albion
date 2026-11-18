class_name OverlayPanel
extends Control
## Contract for any screen the world shows over itself (the Town Hall and the
## pause menu): it raises `closed` when the player is done with it, and
## main.open_overlay() owns the freeze and the resume. Nothing else is shared.

signal closed
