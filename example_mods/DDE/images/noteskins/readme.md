# NOTESKINS
DDE uses two spritesheets for each noteskin, one of the notes and receptors and the other of the holds.
### notes
Notes do not have "animations" and the spritesheet is instead a list of every frame in a specific order. Every 31 frames is a new direction, and is in the same order as they are in game.
Every 31st frame is the receptor of that current direction, and the rest of the frames are the note's idle animation.
Confirm and pressed animations are not needed and are done in game
### holds
Holds only have two frames, one the main hold graphic, and the other the cap. The spritesheet image itself is edited outside of the spritesheet exporter whatever to stretch the open sides of each frame because antialiasing causes seams otherwise.
### colors
A shader is applied onto the note sprite to replace any red green and blue values with a different color.