# Atari PET FROGGER Version 00

 PET FROGGER game for Commodore PET 4032 ported to the Atari 8-bit computers

[![Title Screen](https://github.com/kenjennings/Atari-Pet-Frogger/raw/master/V00_Title.png "Title Screen")](#features1)

[![Game Screen](https://github.com/kenjennings/Atari-Pet-Frogger/raw/master/V00_Game.png "Game Screen")](#features2)

[![You Died!](https://github.com/kenjennings/Atari-Pet-Frogger/raw/master/V00_YerDead.png "You're Dead!")](#features3)

Video of the game play on YouTube: https://youtu.be/Aotkgw6ZSfw

---

**Porting PET FROGGER**

[Frogger00.asm](https://github.com/kenjennings/Atari-Pet-Frogger/blob/master/Frogger00.asm "Frogger00.asm") Atari assembly program.

The assembly code for the Atari depends on my MADS include library here: https://github.com/kenjennings/Atari-Mads-Includes.  

---

PET FROGGER for Commodore PET 4032

(c) November 1983 by John C. Dale, aka Dalesoft

Ported (parodied) to Atari 8-bit computers November 2018 by Ken Jennings (if this were 1983, aka FTR Enterprises)

As much of the PET 4032 code is used as possible. In most places only the barest minimum of changes are made to deal with the differences on the Atari.  

Notable changes:

- References to fixed addresses are changed to meaningful labels.  This includes page 0 variables, and score values.

- Kernel call $FFD2 is replaced with "fputc" subroutine for Atari.

- The Atari screen is a full screen editor, so cursor movement off the right edge of the screen is different from the Pet requiring an extra "DOWN" character to move the cursor to next lines.

- Direct write to screen memory uses different internal code values, not ASCII/ATASCII values.

- Direct keyboard scanning is different requiring Atari to clear the OS value in order to get the next character.  Also, key codes are different on the Atari (and not ASCII or Internal codes.)

---

I think I did something that broke the display of multiple frogs that successfully crossed over the rivers.  One is displayed.   But if more frogs cross, still only one is displayed.

I dialed down the game speed a bit in order to shoot the video and make sure my elderly reflexes could manage some successful runs.

---

[Back to Home](https://github.com/kenjennings/Atari-Pet-Frogger/blob/master/README.md "Home") 

