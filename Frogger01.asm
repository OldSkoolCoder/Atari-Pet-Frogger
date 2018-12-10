; ==========================================================================
; Pet Frogger
; (c) November 1983 by John C. Dale, aka Dalesoft
;
; ==========================================================================
; Ported (parodied) to Atari 8-bit computers 
; November 2018 by Ken Jennings (if this were 1983, aka FTR Enterprises)
;
; Version 00.
; As much of the Pet code is used as possible.
; In most places only the barest minimum of changes are made to deal with
; the differences on the Atari.  Notable changes:
; * References to fixed addresses are changed to meaningful labels.  This
;   includes page 0 variables, and score values.
; * Kernel call $FFD2 is replaced with "fputc" subroutine for Atari.
; * The Atari screen is a full screen editor, so cursor movement off the
;   right edge of the screen is different from the Pet requiring an extra
;   "DOWN" character to move the cursor to next lines.
; * Direct write to screen memory uses different internal code values, not
;   ASCII/ATASCII values.
; * Direct keyboard scanning is different requiring Atari to clear the
;   OS value in order to get the next character.  Also, key codes are
;   different on the Atari (and not ASCII or Internal codes.)
; * Given the differences in clock speed and frame rates between the
;   UK Pet 4032 the game is intended for and the NTSC Atari to which it is
;   ported the timing values in the delays are altered to scale the game
;   speed more like the original on the Pet.
; --------------------------------------------------------------------------
; Version 01.  December 2018
; Atari-specific optimizations, though limited.  Most of the program 
; still could assemble on a Pet (with changes for values and registers).
; The only doubt I have is monitoring for the start of a frame where the 
; Atari could monitor vcount or the jiffy counter.  Not sure how the Pet 
; could do this.
; * No IOCB printing to screen.  All screen writing is directly to 
;   screen memory.  This greatly speeds up the Title screen and game
;   playfield presentation.  It also shrinks code a little.
; * Extra "graphics" inserted for crossing the river, dying and game over.
; * Code is reorganized into an event/timer loop operation to facilitate
;  future Atari-fication and other features.
; --------------------------------------------------------------------------


; ==========================================================================
; Random blabbering across the versions of Pet Frogger concerning 
; differences between Atari and Pet, and the code considerations:
;
; It appears text printing on the Pet treats the screen like a typewriter.
; "Right" cursor movement used to move through full line width will cause
; the cursor to wrap around to the next line.  "Down" also moves to the next
; line.  I don't know for certain, but for printing purposes the program
; code makes it seem like character printing on the PET does not support
; direct positioning of the cursor other than "Home".

; Printing for the Atari version implemented similarly by sending single
; characters to the screen editor, E: device, channel 0.  The Atari'
; full screen editor does things differently.   Moving off the right edge
; of the screen returns the cursor to the left edge of the screen on the
; same line.  (Full screen editor, remember).  Therefore the Atari needs
; an extra "Down" cursor inserted where code expects the cursor on the
; Pet to be on the following line.  It looks like replacing the "Right"
; cursor movements with a blank space should accomplish the same thing,
; but for the sake of minimal changes Version 00 of the port retains the
; Pet's idea of cursor movement.

; Also, depending on how the text is printed the Atari editor can relate
; several adjacent physical lines as one logical line. Great for editing
; text lines longer than 40 characters, not so good when printing wraps the
; cursor from one line to the next.  Printing a character through the end of
; the screen line (aka the right margin) extends the current line as a
; logical line into the next screen line which pushes the content in lines
; below that further down the screen.

; Since some code does direct manipulation of the screen memory, I wonder
; why all the screen code didn't just do the same.  Copy from source to
; destination is easier (or at least more consistent) than printing.
; Changing all the text handling to use direct write is number one on
; the short list of Version 01 optimizations.

; The "BRK" instruction, byte value $00, is used as the end of string
; sentinel in the data.  This conflicts with the character value $00 for
; the graphics heart which the code also uses in place of the "o" in
; "Dalesoft".  The end of string sentinel is changed to the Atari End
; Of Line character, $9B, which does not conflict with anything else in
; the code for printing or data.

; None of the game displays use the entire 25 lines available on the PET.
; The only time the game writes to the entire screen is when it fills the
; screen with the block graphics upon the frog's demise.  This conveniently
; leaves the 25th line free for the "ported by" credit.  But the Atari only
; displays 24 lines of text!?!  Gasp!  Not true.  The NTSC Atari can do up
; to 30 lines of text.  Only the OS printing routines are limited to 24
; lines of text.  The game's 25 screen lines is accomplished on the Atari
; with a custom display list that also designates screen memory starting at
; $8000 which is the same location the Pet uses for its display.
; --------------------------------------------------------------------------

; ==========================================================================
; Ideas for Atari-specific version improvements, Version 01 and beyond!:
; * Remove all printing.  Replace with direct screen writes.  This will
;   be much faster.
; * Timing delay loops are imprecise.  Use the OS jiffy clock (frame
;   counter) to maintain timing, and while we're here make timing tables
;   for NTSC and PAL.
; * Joystick controls.  I hate the keyboard.  The joystick is free and
;   easy on the Atari.
; * Color... Simple version: a DLI for each line could make separate text
;   line colors for beach lines vs boat lines (and credit text lines.)
; * Sound..  Some simple splats, plops, beeps, water sloshings.
; * Custom character set that looks more like beach, boats, water, and frog.
; * Horizontal Fine scrolling text allows smoother movements for the boats.
; * Player Missile Frog. This would make frog placement v the boat
;   positions easier when horizontal scrolling is in effect, not to mention
;   extra color for the frog.
; * Stir, rinse, repeat -- more extreme of all of the above: more color,
;   more DLI, more custom character sets, isometric perspective.
;   Game additions -- pursuing enemies, alternate boat shapes, lily pads,
;   bonus objects to collect, variable/changing boat speeds.  Heavy metal
;   chip tune soundtrack unrelated to frogs that has no good reason for
;   drowning out the game sound effects.  Boss battles.  Online multi-
;   player death matches.  Game Achievements.  In-game micro transaction
;   payments for upgrades and abilities.  Yeah, that's the ticket.
; --------------------------------------------------------------------------

; ==========================================================================
; Atari System Includes (MADS assembler)
	icl "ANTIC.asm" ; Display List registers
	icl "GTIA.asm"  ; Color Registers.
	icl "POKEY.asm" ;
	icl "OS.asm"    ;
	icl "DOS.asm"   ; LOMEM, load file start, and run addresses.
; --------------------------------------------------------------------------

; ==========================================================================
; Macros (No code/data declared)
	icl "macros.asm"
; --------------------------------------------------------------------------


; ==========================================================================
; Declare some Page Zero variables.
; On the Atari the OS owns the first half of Page Zero.

; The Atari load file format allows loading from disk to anywhere in 
; memory, therefore indulging in this evilness to define Page Zero 
; variables and load directly into them at the same time...
; --------------------------------------------------------------------------
	ORG $88

MovesCars       .word $00 ; = Moves Cars

FrogLocation    .word $00 ; = Pointer to start of Frog's current row in screen memory. 
FrogColumn      .byte $00 ; = Frog X coord
FrogRow         .word $00 ; = Frog Y row position (on the playfield not counting score lines)
FrogLastColumn  .byte $00 ; = Frog's last X coordinate
FrogLastRow     .byte $00 ; = Frog's last Y row position 
LastCharacter   .byte 0   ; = Last Character Under Frog

FrogSafety      .byte 0   ; = 0 When Frog OK.  !0 == Yer Dead.
DelayNumber     .byte 0   ; = Delay No. (Hi = Slow, Low = Fast)

FrogsCrossed    .byte 0   ; = Number Of Frogs crossed
ScoreToAdd      .byte 0   ; = Number To Be Added to Score

NumberOfChars   .byte 0   ; = Number Of Characters Across
FlaggedHiScore  .byte 0   ; = Flag For Hi Score.  0 = no high score.  $FF = High score.
NumberOfLives   .byte 0   ; = Is Number Of Lives

LastKeyPressed  .byte 0   ; = Remember last key pressed
ScreenPointer   .word $00 ; = Pointer to location in screen memory.
TextPointer     .word $00 ; = Pointer to text message to write.
TextLength      .word $00 ; = Length of text message to write.

; Timers and event control.
DoTimers        .byte $00 ; = 0 means stop timer features.  Return from event polling. Main line
						  ; code would inc DoTimers to make sure accidental animation does not
						  ; occur while the code switches between screens.  This will become
						  ; more important when the game logic is enhanced to an event loop.

; Frame counters are decremented each frame.
; Once they decrement to  0 they enable the related activity.

; In the case of key press this counter value is set whenever a key is 
; pressed to force a delay between key presses to limit the speed of 
; the frog movement.
KeyscanFrames   .byte $00 ; = KEYSCAN_FRAMES

; In the case of animation frames the value is set from the ANIMATION_FRAMES
; table based on the number of frogs that crossed the river (difficulty level) 
AnimateFrames   .byte $00 ; = ANIMATION_FRAMES,X.  

; Identify the current screen.  This is what drives which timer/event loop 
; features are in effect.  Value is enumerated from SCREEN_LIST table.
CurrentScreen   .byte $00 ; = identity of current screen.

; This is a 0, 1, toggle to remember the last state of  
; something. For example, a blinking thing on screen.
ToggleState     .byte 0   ; = 0, 1, flipper to drive a blinking thing.

; Another event value.  Use for counting things for each pass of a screen/event.
EventCounter    .byte 0

; Another event value.  Use for multiple sequential actions in an 
; Event/Screen, because I got too lazy to chain a new event into 
; sequences.
EventStage      .byte 0

; Game Score and High Score.
MyScore .by $0 $0 $0 $0 $0 $0 $0 $0 
HiScore .by $0 $0 $0 $0 $0 $0 $0 $0 

; In the event X and/or Y can't be saved on stack, protect them here....
SAVEX = $FE
SAVEY = $FF

; ==========================================================================
; Some Atari character things for convenience, or that can't be easily 
; typed in a modern text editor...
; --------------------------------------------------------------------------
ATASCII_UP     = $1C ; Move Cursor 
ATASCII_DOWN   = $1D
ATASCII_LEFT   = $1E
ATASCII_RIGHT  = $1F

ATASCII_CLEAR  = $7D
ATASCII_EOL    = $9B ; Mark the end of strings

ATASCII_HEART  = $00 ; heart graphics
ATASCII_HLINE  = $12 ; horizontal line, ctrl-r (title underline) 
ATASCII_BALL   = $14 ; ball graphics, ctrl-t

ATASCII_EQUALS = $3D ; Character for '='
ATASCII_ASTER  = $2A ; Character for '*' splattered frog.
ATASCII_Y      = $59 ; Character for 'Y'
ATASCII_0      = $30 ; Character for '0'

; ATASCII chars shorthanded due to frequency....
A_B = ATASCII_BALL
A_H = ATASCII_HLINE

; Atari uses different, "internal" values when writing to 
; Screen RAM.  These are the internal codes for writing 
; bytes directly to the screen:
INTERNAL_O        = $2F ; Letter 'O' is the frog.
INTERNAL_0        = $10 ; Number '0' for scores.
INTERNAL_BALL     = $54 ; Ball graphics, ctrl-t, boat part.
INTERNAL_SPACE    = $00 ; Blank space character.
INTERNAL_INVSPACE = $80 ; Inverse Blank space, for the beach.
INTERNAL_ASTER    = $0A ; Character for '*' splattered frog.
INTERNAL_HEART    = $40 ; heart graphics
INTERNAL_HLINE    = $52 ; underline for title text.

; Graphics chars shorthanded due to frequency....
I_I  = 73      ; Internal ctrl-I
I_II = 73+$80  ; Internal ctrl-I Inverse
I_K  = 75      ; Internal ctrl-K
I_IK = 75+$80  ; Internal ctrl-K Inverse
I_L  = 76      ; Internal ctrl-L
I_IL = 76+$80  ; Internal ctrl-L Inverse
I_O  = 79      ; Internal ctrl-O
I_IO = 79+$80  ; Internal ctrl-O Inverse
I_U  = 85      ; Internal ctrl-U
I_IU = 85+$80  ; Internal ctrl-U Inverse
I_Y  = 89      ; Internal ctrl-Y
I_IY = 89+$80  ; Internal ctrl-Y Inverse
I_S  = 0       ; Internal Space
I_IS = 0+$80   ; Internal Space Inverse
I_T  = $54     ; Internal ctrl-t (ball)
I_IT = $54+$80 ; Internal ctrl-t Inverse

; Keyboard codes for keyboard game controls.
KEY_S = 62
KEY_Y = 43
KEY_6 = 27
KEY_4 = 24


; Timer values.  NTSC.
; About 7 keys per second.
KEYSCAN_FRAMES = $09

; based on number of frogs, how many frames between boat movements...
ANIMATION_FRAMES .byte 30,25,20,18,15,13,11,10,9,8,7,6

; Timer values.  PAL ?? guesses...
; About 7 keys per second.
; KEYSCAN_FRAMES = $07
; based on number of frogs, how many frames between boat movements...
;ANIMATION_FRAMES .byte 25,21,17,14,12,11,10,9,8,7,6,5

; Screen enumeration states for current processing condition.
; Note that the order here does not imply the only order of 
; movement between screens/event activity.  The enumeration 
; could be entirely random.
SCREEN_START       = 0  ; Entry Point for New Game setup..
SCREEN_TITLE       = 1  ; Credits and Instructions.
SCREEN_TRANS_GAME  = 2  ; Transition animation from Title to Game.
SCREEN_GAME        = 3  ; GamePlay 
SCREEN_TRANS_WIN   = 4  ; Transition animation from Game to Win.
SCREEN_WIN         = 5  ; Crossed the river!
SCREEN_TRANS_DEAD  = 6  ; Transition animation from Game to Dead.
SCREEN_DEAD        = 7  ; Yer Dead!
SCREEN_TRANS_OVER  = 8  ; Transition animation from Dead to Game Over.
SCREEN_OVER        = 9  ; Game Over.
SCREEN_TRANS_TITLE = 10 ; Transition animation from Game Over to Title.

; Screen Order/Path
;                       +-------------------------+
;                       V                         |
; Screen Title ---> Game Screen -+-> Win Screen  -+
;       ^               ^        |
;       |               |        +-> Dead Screen -+-> Game Over -+
;       |               |                         |              |
;       |               +-------------------------+              |
;       +--------------------------------------------------------+

; Programmer's unintelligently chosen higher address on Atari
; to account for DOS, etc.
	ORG $5000

	; Label and Credit
	.by "** Thanks to the Word (John 1:1), Creator of heaven and earth, and "
	.by "the semiconductor chemistry and physics which makes all this fun possible. ** "
	.by "Dales" ATASCII_HEART "ft PET FROGGER by John C. Dale, November 1983. ** "
	.by "Atari port by Ken Jennings, December 2018. Version 01. "
	.by "IOCB Printing removed. Everything is direct writes to screen RAM. **" 
	.by "Code reworked into timer/event loop organization. **"


; ==========================================================================
; All "printed" items declared:

; The original Pet version mixed printing to the screen with direct
; writes to screen memory.  The printing required adjustments, because 
; the Atari full screen editor works differently from the Pet terminal.

; Most of the ASCII/PETASCII/ATASCII is now removed.  No more "printing"  
; to the screen.  Everything is directly written to the screen memory.  
; All the data to write to the screen is declared, then the addresses to 
; the data is listed in a table. Rather than several different screen 
; printing routines there is now one display routine that accepts an index 
; into the table driving the data movement to screen memory.  Since the 
; data also has a declared length the end of text sentinel byte is no 
; longer needed.
; --------------------------------------------------------------------------

; Display layouts and associated text blocks:

; Original V00 Title Screen and Instructions:
;    +----------------------------------------+
; 1  |              PET FROGGER               | INSTXT_1
; 2  |              --- -------               | INSTXT_1
; 3  |     (c) November 1983 by DalesOft      | INSTXT_1
; 4  |                                        |
; 5  |All you have to do is to get as many of | INSTXT_2
; 6  |the frogs across the river without      | INSTXT_2
; 7  |drowning them. You have to leap onto a  | INSTXT_2
; 8  |boat like this :- <QQQ] and land on the | INSTXT_2
; 9  |seats ('Q'). You get 10 points for every| INSTXT_2
; 10 |jump forward and 500 points every time  | INSTXT_2
; 11 |you get a frog across the river.        | INSTXT_2
; 12 |                                        |
; 13 |                                        |
; 14 |                                        |
; 15 |The controls are :-                     | INSTXT_3
; 16 |                 S = Up                 | INSTXT_3
; 17 |  4 = left                   6 = right  | INSTXT_3
; 18 |                                        |
; 19 |                                        |
; 20 |     Hit any key to start the game.     | INSTXT_4
; 21 |                                        |
; 22 |                                        |
; 23 |                                        |
; 24 |                                        |
; 25 |Atari V01 port by Ken Jennings, Nov 2018| PORTBYTEXT
;    +----------------------------------------+

;  Original V00 Main Game Play Screen:
;    +----------------------------------------+
; 1  |Successful Crossings =                  | SCORE_TXT 
; 2  |Score = 0000000      Hi = 0000000   Lv:3| SCORE_TXT
; 3  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_1
; 4  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_1
; 5  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_1
; 6  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_2
; 7  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_2
; 8  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_2
; 9  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_3
; 10 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_3
; 11 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_3
; 12 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_4
; 13 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_4
; 14 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_4
; 15 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_5
; 16 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_5
; 17 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_5
; 18 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_6
; 29 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_6
; 20 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_6
; 21 |BBBBBBBBBBBBBBBBBBBOBBBBBBBBBBBBBBBBBBBB| TEXT2
; 22 |     (c) November 1983 by DalesOft      | TEXT2
; 23 |        Written by John C Dale          | TEXT2
; 24 |                                        |
; 25 |Atari V01 port by Ken Jennings, Nov 2018| PORTBYTEXT
;    +----------------------------------------+


; Revised V01 Title Screen and Instructions:
;    +----------------------------------------+
; 1  |              PET FROGGER               | TITLE
; 2  |              --- -------               | TITLE
; 3  |     (c) November 1983 by DalesOft      | CREDIT
; 4  |        Written by John C Dale          | CREDIT
; 5  |Atari V01 port by Ken Jennings, Dec 2018| CREDIT
; 6  |                                        |
; 7  |Help the frogs escape from Doc Hopper's | INSTXT_1
; 8  |frog legs fast food franchise! But, the | INSTXT_1
; 9  |frogs must cross piranha-infested rivers| INSTXT_1
; 10 |to reach freedom. You have three chances| INSTXT_1
; 11 |to prove your frog management skills by | INSTXT_1
; 12 |directing frogs to jump on boats in the | INSTXT_1
; 13 |rivers like this:  <QQQQ]  Land only on | INSTXT_1
; 14 |the seats in the boats ('Q').           | INSTXT_1
; 15 |                                        |
; 16 |Scoring:                                | INSTXT_2
; 17 |    10 points for each jump forward.    | INSTXT_2
; 18 |   500 points for each rescued frog.    | INSTXT_2
; 19 |                                        |
; 20 |Game controls:                          | INSTXT_3
; 21 |                 S = Up                 | INSTXT_3
; 22 |      left = 4           6 = right      | INSTXT_3
; 23 |                                        |
; 24 |     Hit any key to start the game.     | INSTXT_4
; 25 |                                        |
;    +----------------------------------------+

; Transition Title screen to Game Screen.
; Animate Credit lines down from Line 3 to Line 23.
 
; Revised V01 Main Game Play Screen:
;    +----------------------------------------+
; 1  |Score = 0000000      Hi = 0000000   Lv:3| SCORE_TXT
; 2  |  Frogs Saved =                         | SCORE_TXT 
; 3  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_1
; 4  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_1
; 5  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_1
; 6  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_2
; 7  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_2
; 8  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_2
; 9  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_3
; 10 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_3
; 11 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_3
; 12 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_4
; 13 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_4
; 14 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_4
; 15 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_5
; 16 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_5
; 17 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_5
; 18 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_6
; 19 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_6
; 20 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_6
; 21 |BBBBBBBBBBBBBBBBBBBOBBBBBBBBBBBBBBBBBBBB| TEXT2
; 22 |                                        |
; 23 |     (c) November 1983 by DalesOft      | CREDIT
; 24 |        Written by John C Dale          | CREDIT
; 25 |Atari V01 port by Ken Jennings, Dec 2018| CREDIT
;    +----------------------------------------+



; ==========================================================================

BLANK_TXT ; Blank line used to erase things.
	.sb "                                        "

BLANK_TXT_INV ; Inverse blank line used to "animate" things.
	.sb +$80 "                                        "

; ==========================================================================

TITLE_TXT ; Instructions/Title text.
; 1  |              PET FROGGER               | TITLE
; 2  |              --- -------               | TITLE
	.sb "              PET FROGGER               "
	.sb "              " 
	.sb A_H A_H A_H " " A_H A_H A_H A_H
	.sb A_H A_H A_H "               "

CREDIT_TXT ; The perpetrators identified...
; 3  |     (c) November 1983 by DalesOft      | CREDIT
; 4  |        Written by John C Dale          | CREDIT
; 5  |Atari V01 port by Ken Jennings, Dec 2018| CREDIT
	.sb "     (c) November 1983 by Dales" ATASCII_HEART "ft      "
	.sb "        Written by John C. Dale         "
	.sb "Atari V01 port by Ken Jennings, Dec 2018"

INST_TXT1 ; Basic instructions...
; 7  |Help the frogs escape from Doc Hopper's | INSTXT_1
; 8  |frog legs fast food franchise! But, the | INSTXT_1
; 9  |frogs must cross piranha-infested rivers| INSTXT_1
; 10 |to reach freedom. You have three chances| INSTXT_1
; 11 |to prove your frog management skills by | INSTXT_1
; 12 |directing frogs to jump on boats in the | INSTXT_1
; 13 |rivers like this:  <QQQQ]  Land only on | INSTXT_1
; 14 |the seats in the boats ('Q').           | INSTXT_1
	.sb "Help the frogs escape from Doc Hopper's "
	.sb "frog legs fast food franchise! But, the " 
	.sb "frogs must cross piranha-infested rivers" 
	.sb "to reach freedom. You have three chances" 
	.sb "to prove your frog management skills by " 
	.sb "directing frogs to jump on boats in the " 
	.sb "rivers like this:  <" A_B A_B A_B "]  Land only on  " 
	.sb "the seats in the boats ('" A_B "').           " 

INST_TXT2 ; Scoring
; 16 |Scoring:                                | INSTXT_2
; 17 |    10 points for each jump forward.    | INSTXT_2
; 18 |   500 points for each rescued frog.    | INSTXT_2
	.sb "Scoring:                                "
	.sb "    10 points for each jump forward.    "
	.sb "   500 points for each rescued frog.    "

INST_TXT3 ; Game Controls
; 20 |Game controls:                          | INSTXT_3
; 21 |                 S = Up                 | INSTXT_3
; 22 |      left = 4           6 = right      | INSTXT_3
	.sb "Game controls:                          " 
	.sb "                 S = Up                 "
	.sb "      left = 4           6 = right      " 

INST_TXT4 ; Prompt to start game.
; 24 |     Hit any key to start the game.     | INSTXT_4
	.sb "     Hit any key to start the game.     "

INST_TXT4_INV ; inverse version to support blinking.
; 24 |     Hit any key to start the game.     | INSTXT_4INV
	.sb +$80 "     Hit any key to start the game.     "

; ==========================================================================

SCORE_TXT  ; Labels for crossings counter, scores, and lives
; 1  |Score = 0000000      Hi = 0000000   Lv:3| SCORE_TXT
; 2  |  Frogs Saved =                         | SCORE_TXT 
	.sb "Score =              Hi =           Lv: "
	.sb "  Frogs Saved =                         "

TEXT1 ; Default display of "Beach", for lack of any other description, and the two lines of Boats
	.sb +$80 "                                        " ; "Beach"
	.sb " [" A_B A_B A_B A_B ">        " ; Boats Right
	.sb "[" A_B A_B A_B A_B ">       "
	.sb "[" A_B A_B A_B A_B ">      "
	.sb "      <" A_B A_B A_B A_B "]" ; Boats Left
	.sb "        <" A_B A_B A_B A_B "]"
	.sb "    <" A_B A_B A_B A_B "]    "

TEXT2 ; this last block includes a Beach, with the "Frog" character which is the starting line. 
	.sb +$80 "                   O                    " ; The "beach" + frog

; ==========================================================================

YRDDTX  ; Yer dead! Text prompt.
	.sb +$80 "     YOU'RE DEAD!! YOU WAS SWAMPED!     "

FROGTXT ; You made it across the rivers.
	.sb +$80 "     CONGRATULATIONS!! YOU MADE IT!     "
	.sb ATASCII_EOL
	BRK

OVER ; Prompt for playing again.
	.sb "        DO YOU WANT ANOTHER GO ?        "
	.sb ATASCII_EOL
	brk

INSTXT_1 ; Instructions text.  
	.sb "              PET FROGGER               "
	.sb "              " 
	.sb A_H A_H A_H " " A_H A_H A_H A_H
	.sb A_H A_H A_H "               "
	.sb "     (c) November 1983 by Dales" ATASCII_HEART "ft      "

INSTXT_2 ; Instructions text.
	.sb "All you have to do is to get as many of "
	.sb "the frogs across the river without      "
	.sb "drowning them. You have to leap onto a  "
	.sb "boat like this :- <" A_B A_B A_B "] and land on the "
	.sb "seats ('" A_B "'). You get 10 points for every"
	.sb "jump forward and 500 points every time  "
	.sb "you get a frog across the river.        "

INSTXT_3 ; More instructions
	.sb "The controls are :-                     "
	.sb "                 S = Up                 "
	.sb "  4 = left                   6 = right  "

INSTXT_4
	.sb +$80 "     Hit any key to start the game.     "


FROG_SAVE_GFX
; Graphics chars design, SAVED!
; |  |**|**|  |  | *|* |  | *|* | *|* | *|**|**|* | *|**|* |  |  |**|
; | *|* |  |  |  |**|**|  | *|* | *|* | *|* |  |  | *|* |**|  |  |**|
; |  |**|**|  | *|* | *|* | *|* | *|* | *|**|**|  | *|* | *|* |  |**|
; |  |  | *|* | *|* | *|* | *|* | *|* | *|* |  |  | *|* | *|* |  |**|
; |  |  | *|* | *|**|**|* |  |**|**|  | *|* |  |  | *|* |**|  |  |  |
; |  |**|**|  | *|* | *|* |  | *|* |  | *|**|**|* | *|**|* |  |  |**|

; Graphics chars, SAVED!
; | I|iI|iU|  |  |iL|iK|  |iY| Y|iY| Y|iY|iI|iU| L|iY|iI|iK|  |  |i |
; |  |iU|iO| O|iY| Y|iY| Y|iY| Y|iY|Y |iY|iI|iU|  |iY| Y|iY| Y|  |i |
; |  | U|iL| L|iY|iI|iO| Y|  |iO|iI|  |iY|iK| U| O|iY|iK|iI|  |  | U|

; Graphics data, SAVED!  (22) + 18 spaces.
	.by $0,$0,$0,$0,$0,$0,$0,$0,$0,I_I,I_II,I_IU,I_S,I_S,I_IL,I_IK,I_S,I_IY,I_Y,I_IY,I_Y,I_IY,I_II,I_IU,I_L,I_IY,I_II,I_IK,I_S,I_S,I_IS,$0,$0,$0,$0,$0,$0,$0,$0,$0
	.by $0,$0,$0,$0,$0,$0,$0,$0,$0,I_S,I_IU,I_IO,I_O,I_IY,I_Y,I_IY,I_Y,I_IY,I_Y,I_IY,I_Y,I_IY,I_II,I_IU,I_S,I_IY,I_Y,I_IY,I_Y,I_S,I_IS,$0,$0,$0,$0,$0,$0,$0,$0,$0
	.by $0,$0,$0,$0,$0,$0,$0,$0,$0,I_S,I_U,I_IL,I_L,I_IY,I_II,I_IO,I_Y,I_S,I_IO,I_II,I_S,I_IY,I_IK,I_U,I_O,I_IY,I_IK,I_II,I_S,I_S,I_U,$0,$0,$0,$0,$0,$0,$0,$0,$0

FROG_DEAD_GFX
; Graphics chars design, DEAD FROG!
; | *|**|* |  | *|**|**|* |  | *|* |  | *|**|* |  |  |  |  | *|**|**|* | *|**|**|  |  |**|**|  |  |**|**|* |  |**|
; | *|* |**|  | *|* |  |  |  |**|**|  | *|* |**|  |  |  |  | *|* |  |  | *|* | *|* | *|* | *|* | *|* |  |  |  |**|
; | *|* | *|* | *|**|**|  | *|* | *|* | *|* | *|* |  |  |  | *|**|**|  | *|* | *|* | *|* | *|* | *|* |  |  |  |**|
; | *|* | *|* | *|* |  |  | *|* | *|* | *|* | *|* |  |  |  | *|* |  |  | *|**|**|  | *|* | *|* | *|* |**|* |  |**|
; | *|* |**|  | *|* |  |  | *|**|**|* | *|* |**|  |  |  |  | *|* |  |  | *|* |**|  | *|* | *|* | *|* | *|* |  |  |
; | *|**|* |  | *|**|**|* | *|* | *|* | *|**|* |  |  |  |  | *|* |  |  | *|* | *|* |  |**|**|  |  |**|**|* |  |**|

; Graphics chars, DEAD FROG!
; |iY|iI|iK|  |iY|iI|iU| L|  |iL|iK|  |iY|iI|iK|  |  |  |  |iY|iI|iU| L|iY|iI|iO| O| I|iI|iO| O| I|iI|iU| L|  |i |
; |iY| Y|iY| Y|iY| I|iU|  |iY| Y|iY| Y|iY| Y|iY| Y|  |  |  |iY|iI|iU|  |iY|iK|iL| L|iY| Y|iY| Y|iY| Y| U| O|  |i |
; |iY|iK|iI|  |iY|iK| U| O|iY|iI|iO| Y|iY|iK|iI|  |  |  |  |iY| Y|  |  |iY| Y|iO| O| K|iK|iL| L| K|iK|iL|iY|  | U|

; Graphics data, DEAD FROG!  (37) + 3 spaces.
	.by $0,$0,I_IY,I_II,I_IK,I_S,I_IY,I_II,I_IU,I_L,I_S,I_IL,I_IK,I_S,I_IY,I_II,I_IK,I_S,I_S,I_S,I_S,I_IY,I_II,I_IU,I_L,I_IY,I_II,I_IO,I_O,I_I,I_II,I_IO,I_O,I_I,I_II,I_IU,I_L,I_S,I_IS,$0
	.by $0,$0,I_IY,I_Y,I_IY,I_Y,I_IY,I_I,I_IU,I_S,I_IY,I_Y,I_IY,I_Y,I_IY,I_Y,I_IY,I_Y,I_S,I_S,I_S,I_IY,I_II,I_IU,I_S,I_IY,I_IK,I_IL,I_L,I_IY,I_Y,I_IY,I_Y,I_IY,I_Y,I_U,I_O,I_S,I_IS,$0
	.by $0,$0,I_IY,I_IK,I_II,I_S,I_IY,I_IK,I_U,I_O,I_IY,I_II,I_IO,I_Y,I_IY,I_IK,I_II,I_S,I_S,I_S,I_S,I_IY,I_Y,I_S,I_S,I_IY,I_Y,I_IO,I_O,I_IK,I_IK,I_IL,I_L,I_IK,I_IK,I_IL,I_IY,I_S,I_U ,$0

GAME_OVER_GFX
; Graphics chars design, GAME OVER 
; |  |**|**|* |  | *|* |  |**|  | *|* |**|**|**|  |  |  |  |**|**|  | *|* | *|* | *|**|**|* | *|**|**|  |
; | *|* |  |  |  |**|**|  |**|* |**|* |**|  |  |  |  |  | *|* | *|* | *|* | *|* | *|* |  |  | *|* | *|* |
; | *|* |  |  | *|* | *|* |**|**|**|* |**|**|* |  |  |  | *|* | *|* | *|* | *|* | *|**|**|  | *|* | *|* |
; | *|* |**|* | *|* | *|* |**| *| *|* |**|  |  |  |  |  | *|* | *|* | *|* | *|* | *|* |  |  | *|**|**|  |
; | *|* | *|* | *|**|**|* |**|  | *|* |**|  |  |  |  |  | *|* | *|* |  |**|**|  | *|* |  |  | *|* |**|  |
; |  |**|**|* | *|* | *|* |**|  | *|* |**|**|**|  |  |  |  |**|**|  |  | *|* |  | *|**|**|* | *|* | *|* |

; Graphics chars, Game Over. 
; | I|iI|iU| I|  |iL|iK|  |iS| O|iL| Y|i |iU|iU|  |  |  | I|iI|iO| O|iY| Y|iY| Y|iY|iI|iU| L|iY|iI|iO| O|
; |iY| Y| U| O|iY| Y|iY| Y|i |iO|iO| Y|i |iU| L|  |  |  |iY| Y|iY| Y|iY| Y|iY| Y|iY|iI|iU|  |iY|iK|iL| L|
; | K|iK|iL| Y|iY|iI|iO| Y|i |  |iY| Y|i | U| U|  |  |  | K|iK|iL| L|  |iO|iI|  |iY| K| U| O|iY| Y|iO| O|

; Graphics data, Game Over.  (34) + 6 spaces.
	.by $0,$0,$0,I_I,I_II,I_IU,I_I,I_S,I_IL,I_IK,I_S,I_IS,I_O,I_IL,I_Y,I_IS,I_IU,I_IU,I_S,I_S,I_S,I_I,I_II,I_IO,I_O,I_IY,I_Y,I_IY,I_Y,I_IY,I_II,I_IU,I_L,I_IY,I_II,I_IO,I_O,$0,$0,$0
	.by $0,$0,$0,I_IY,I_Y,I_U,I_O,I_IY,I_Y,I_IY,I_Y,I_IS,I_IO,I_IO,I_Y,I_IS,I_IU,I_L,I_S,I_S,I_S,I_IY,I_Y,I_IY,I_Y,I_IY,I_Y,I_IY,I_Y,I_IY,I_II,I_IU,I_S,I_IY,I_IK,I_IL,I_L,$0,$0,$0
	.by $0,$0,$0,I_IK,I_IK,I_IL,I_Y,I_IY,I_II,I_IO,I_Y,I_IS,I_S,I_IY,I_Y,I_IS,I_U,I_U,I_S,I_S,I_S,I_IK,I_IK,I_IL,I_L,I_S,I_IO,I_II,I_S,I_IY,I_IK,I_U,I_O,I_IY,I_Y,I_IO,I_O,$0,$0,$0


; ==========================================================================
; Text is static.  The vertical position may vary based on parameter 
; by the caller.
; So, all we need are lists --  a list of the text and the sizes.
; To index the lists we need enumerated values.
; --------------------------------------------------------------------------
PRINT_BLANK_TXT     = 0  ; BLANK_TXT     ; Blank line used to erase things.
PRINT_BLANK_TXT_INV = 1  ; BLANK_TXT_INV ; Inverse blank line used to "animate" things.
PRINT_TITLE_TXT     = 2  ; TITLE_TXT     ; Instructions/Title text. 
PRINT_CREDIT_TXT    = 3  ; CREDIT_TXT    ; The perpetrators identified...
PRINT_INST_TXT1     = 4  ; INST_TXT1     ; Basic instructions...
PRINT_INST_TXT2     = 5  ; INST_TXT2     ; Scoring
PRINT_INST_TXT3     = 6  ; INST_TXT3     ; Game Controls
PRINT_INST_TXT4     = 7  ; INST_TXT4     ; Prompt to start game.
PRINT_INST_TXT4_INV = 8  ; INST_TXT4_INV ; inverse version to support blinking.
PRINT_SCORE_TXT     = 9  ; SCORE_TXT     ; Labels for crossings counter, scores, and lives
PRINT_TEXT1         = 10 ; TEXT1         ; Beach and boats.
PRINT_TEXT2         = 11 ; TEXT2         ; Beach with frog (starting line)
PRINT_END           = 12 ; value marker for end of list.


TEXT_MESSAGES ; Starting addresses of each of the text messages
	.word BLANK_TXT,BLANK_TXT_INV
	.word TITLE_TXT,CREDIT_TXT,INST_TXT1,INST_TXT2,INST_TXT3,INST_TXT4,INST_TXT4_INV
	.word SCORE_TXT,TEXT1,TEXT2
	
	.word YRDDTX,FROGTXT,OVER
	.word INSTXT_1,INSTXT_2,INSTXT_3,INSTXT_4,PORTBYTEXT

TEXT_SIZES ; length of message.  Each should be a multiple of 40.
	.word 40,40
	.word 80,120,320,120,120,40,40
	.word 80,120,40
	.word 80,40,40,40
	.word 120,280,120,40,40

SCREEN_ADDR ; Direct address lookup for each row of screen memory.
	.rept 25,#           
		.word [40*:1+SCREENMEM]
	.endr


; ==========================================================================
; "Printing" things to the screen.
; --------------------------------------------------------------------------

; ==========================================================================
; Clear the screen.  
; 25 lines of text is divisible by 5 lines, and 5 lines of text is 
; 200 bytes, so the code will loop and clear in multiple, 5 line 
; sections at the same time.
;
; Indexing to 200 means bpl/bmi can't be used to identify continuing 
; or ending condition of the loop.  Therefore, the loop counts 200 to 
; 1 and uses value 0 for end of loop.  This means the base address for 
; the indexing must be one less (-1) from the intended target base.
;
; Used by code:
; A = 0 for blank space.
; X = index, 200 to 1
; --------------------------------------------------------------------------
ClearScreen
	mSaveRegAX ; Save A and X, so the caller doesn't need to.

	lda #INTERNAL_SPACE  ; Blank Space byte. (known to be 0)
	ldx #200             ; Loop 200 to 1, end when 0

ClearScreenLoop
	sta SCREENMEM-1, x    ; 0   to 199 
	sta SCREENMEM+200-1,x ; 200 to 399
	sta SCREENMEM+400-1,x ; 400 to 599
	sta SCREENMEM+600-1,x ; 600 to 799
	sta SCREENMEM+800-1,x ; 800 to 999
	dex
	bne ClearScreenLoop

	mRestoreRegAX ; Restore X and A

	rts


; ==========================================================================
; Print the instruction/title screen text.
; Set state of the text line that is blinking.
; --------------------------------------------------------------------------
DisplayTitleScreen
INSTR 
	jsr ClearScreen 

	ldx #0

; An individual setup and call to PrintToScreen is 7 bytes which 
; makes explicit setup for six calls for screen writing 42 bytes long.
; Since there are multiple, repeat patterns of the same thing, 
; wrap it in a loop and read driving data from a table.
; The ldx for setup, this code in the loop, plus the actual data
; in the driving tables is 2+19+12 = 33 bytes long.

LoopDisplayTitleText
	ldy TITLE_PRINT_LIST,x
	txa
	pha
	lda TITLE_PRINT_ROWS,x
	tax
	jsr PrintToScreen
	pha
	tax
	inx
	cpx #6
	bne LoopDisplayTitleText

	lda #1 ; default condition of blinking prompt is inverse
	sta ToggleState

	rts

TITLE_PRINT_LIST
	.byte PRINT_TITLE_TXT,PRINT_CREDIT_TXT,PRINT_INST_TXT1
	.byte PRINT_INST_TXT2,PRINT_INST_TXT3,PRINT_INST_TXT4_INV

TITLE_PRINT_ROWS
	.byte 0,2,6,15,19,23


; ==========================================================================
; Display the game screen. 
; The credits at the bottom of the screen is still always redrawn.
; From the title screen it is animated to move to the bottom of the 
; screen.  But from the Win and Dead frog screens the credits
; are overdrawn. 
; --------------------------------------------------------------------------
DisplayGameScreen
PRINTSC 
	jsr ClearScreen 

	ldy #PRINT_SCORE_TXT    ; Print the lives and score labels 
	ldx #0
	jsr PrintToScreen

	ldy #PRINT_TEXT1        ; Print TEXT1 -  beaches and boats (6 times)
	ldx #2

LoopPrintBoats
	jsr PrintToScreen

	inx
	inx
	inx

	cpx #20                 ; Printed six times? (18 lines total) 
	bne LoopPrintBoats      ; No, go back to print another set of lines.

	ldy #PRINT_TEXT2        ; Print TEXT2 - last Beach with the frog
;	ldx #20                 ; it already is 20.
	jsr PrintToScreen

	ldy #PRINT_CREDIT_TXT   ; Identify the culprits responsible
	ldx #2
	jsr PrintToScreen

; Display the number of frogs that crossed the river.
	jsr PrintFrogsAndLives

	rts


; ==========================================================================
; Copy text blocks to screen memory.
;
; Parameters:
; Y = index of the text item.  One of the PRINT_... values.
; X = row number on screen 0 to 24.
;
; Used by code:
; A = used to multiply  value of index, and move the values.  
; --------------------------------------------------------------------------
PrintToScreen
	cpy #PRINT_END
	bcs ExitPrintToScreen  ; Greater than or equal to END marker, so exit.

	mSaveRegAYX            ; Save A and Y and X, so the caller doesn't need to.

	asl                    ; multiply row number by 2 for address lookup.
	tax                    ; use as index.
	lda SCREEN_ADDR,x      ; Get screen row address low byte.
	sta ScreenPointer
	inx 
	lda SCREEN_ADDR,x      ; Get screen row address high byte.
	sta ScreenPointer+1

	tya                    ; get the text identification.
	asl                    ; multiply by 2 for all the word lookups.
	tay                    ; use as index.

	lda TEXT_MESSAGES,y    ; Load up the values from the tables
	sta TextPointer
	lda TEXT_SIZES,y
	sta TextLength
	iny                    ; now the high bytes
	lda TEXT_MESSAGES,y    ; Load up the values from the tables.
	sta TextPointer+1
	lda TEXT_SIZES,y
	sta TextLength+1

	ldy #0
PrintToScreenLoop          ; sub-optimal copy through page 0 indirect index
	lda (TextPointer),y    ; Always assumes at least 1 byte to copy
	sta (ScreenPointer),y

	dec TextLength         ; Decrement length.  Stop when length is 0.
	bne DoEvaluateLengthHi ; If low byte is not 0, then continue
	lda TextLength+1       ; Is the high byte also 0?
	beq EndPrintToScreen   ; Low byte and high byte are 0, so we're done.

DoEvaluateLengthHi         ; Check if hi byte of length must decrement 
	lda TextLength         ; If this rolled from 0 to $FF
	cmp #$FF               ; this means there is a high byte to decrement
	bne DoTextPointer      ; Nope.  So, continue.
	dec TextLength+1       ; Yes, low byte went 0 to FF, so decrement high byte.

DoTextPointer              ; inc text pointer.
	inc TextPointer
	bne DoScreenPointer    ; Did not roll from 255 to 0, so skip hi byte
	inc TextPointer+1

DoScreenPointer            ; inc screen pointer.
	inc ScreenPointer
	bne PrintToScreenLoop  ; Did not roll from 255 to 0, so skip hi byte
	inc ScreenPointer+1
	bne PrintToScreenLoop  ; The inc above must reasonably be non-zero.

EndPrintToScreen
	mRegRestoreAYX         ; Restore X, Y and A

ExitPrintToScreen
	rts


; ==========================================================================
; A little code size optimization.
; Add 120 (dec) to the current MovesCars pointer.
; This moves the pointer to the next river/boat line 3 lines lower, 
; so the current shift logic can be repeated.
; --------------------------------------------------------------------------
MoveCarsPlus120
	clc
	lda MovesCars     ; Add $78/120 (dec) to the start of line pointer
	adc #$78          ; to set new position 3 lines lower.
	sta MovesCars
	bcc ExitMoveCarsPlus120 
	inc MovesCars + 1 ; Smartly done instead of lda/adc #0/sta.

ExitMoveCarsPlus120
	rts


; ==========================================================================
; AUTO MOVE FROG
; Process automagical movement on the frog in the moving boat lines
;
; Data to drive AutoMoveFrog routine.
; Byte value indicates direction of row movement.
; 0   = Beach line, no movement.
; 1   = first boat/river row, move right
; 255 = second boat/river row, move left.
; --------------------------------------------------------------------------
AutoMoveFrog
	ldx FrogRow             ; Get the current row number.
	lda MOVING_ROW_STATES,x ; Get the movement flag for the row.
	beq ExitAutoMoveFrog    ; Is it 0?  Nothing to do.  Bail.
	bmi AutoFrogRight       ; is it $ff?  then automatic right move.

	dey                     ; Move Frog left one character
;	cpy #0                  ; Is it at 0? (Why not check for $FF here (or bmi)?)
	bpl ExitAutoMoveFrog    ; Is it 0 or greater? Then nothing to do.  Bail.
;	bne ExitAutoMoveFrog    ; No.  Bail.
	inc FrogSafety          ; Yup.  Ran out of river.   Yer Dead!
	rts

;	jmp YRDD                ; Yup.  Ran out of river.   Yer Dead!

AutoFrogRight 
	iny                     ; Move Frog right one character
	cpy #$28                ; Did it reach the right side ?    $28/40 (dec)
	bne ExitAutoMoveFrog    ; No.  Bail..
	inc FrogSafety          ; Yup.  Ran out of river.   Yer Dead!

	;	jmp YRDD            ; Yup.  Ran out of river.   Yer Dead!

ExitAutoMoveFrog
	rts
;	jmp KEY                 ; Return to keyboard polling.

MOVING_ROW_STATES
	.rept 6                 ; 6 occurrences of 
		.BYTE 0, 1, $FF     ; Beach (0), Left (1), Right (FF) directions.
	.endr


; ==========================================================================
; ANIMATE BOATS
; Move the lines of boats around either left or right.
; Changed logic for moving lines.  The original code moved all the 
; rows going right then all the rows going left.
; This version does each line in order from the top to the bottom of
; the screen.  This is done on the chance that the code is racing the 
; screen rendering and so we don't want main line execution to find 
; a pattern where the code is updating a text line that is being  
; displayed and we end up with tearing animation. 
; --------------------------------------------------------------------------
AnimateBoats
MOVESC
	ldx #6            ; Loop 3 to 18 step 3 -- 6 = 3 times 2 for size of word in SCREEN_ADDR

	; FIRST PART -- Set up for Right Shift... 
RightShiftRow
	lda SCREEN_ADDR,x ; Get address of this row in X from the screen memeory lookup.
	sta MovesCars
	inx
	lda SCREEN_ADDR,x
	sta MovesCars+1
	inx 

	ldy #$27          ; Character position, start at +39 (dec)
	lda (MovesCars),y ; Read byte from screen (start +39)
	pha               ; Save the character at the end to move to position 0.
	dey               ; now at offset +38 (dec)

MoveToRight ; Shift text lines to the right.
	lda (MovesCars),y ; Read byte from screen (start +38)
	iny
	sta (MovesCars),y ; Store byte to screen at next position (start +39)

	dey               ; Back up to the original read position.
	dey               ; Backup to previous position.

	bpl MoveToRight   ; Backed up from 0 to FF? No. Do the shift again.

	; Copy character at end of line to the start of the line.
	pla               ; Get character that was at the end of the line.
	ldy #$00          ; Offset 0 == start of line
	sta (MovesCars),y ; Save it at start of line.

	; SECOND PART -- Setup for Left Shift...
	lda SCREEN_ADDR,x
	sta MovesCars
	inx
	lda SCREEN_ADDR,x
	sta MovesCars+1
	inx 

	ldy #$00          ; Character position, start at +0 (dec)
	lda (MovesCars),y ; Read byte from screen (start +0)
	pha               ; Save to move to position +39.
	iny               ; now at offset +1 (dec)

MoveToLeft ; Shift text lines to the left.
	lda (MovesCars),y ; Get byte from screen (start +1)
	dey
	sta (MovesCars),y ; Store byte at previous position (start +0)

	iny               ; Forward to the original read position. (start +1)
	iny               ; Forward to the next read position. (start +2)

	cpy #$27          ; Reached position $27/39 (dec) (end of line)?
	bne MoveToLeft    ; No.  Do the shift again.

	; Copy character at start of line to the end of the line.
	pla               ; Get character that was at the end of the line.
	ldy #$27          ; Offset $27/39 (dec)
	sta (MovesCars),y ; Save it at end of line.

	inx ; skip the beach line
	inx

	cpx #40 ; 21st line (20 from base 0) times 2  
	bcc RightShiftRow ; Continue to loop, right, left, right, left

	jsr CopyScoreToScreen ; Finish up by updating score display.

	rts


; ==========================================================================
; Copy the score from memory to screen positions.
; --------------------------------------------------------------------------
CopyScoreToScreen
;PRITSC
	ldx #7

DoUpdateScreenScore
	lda MyScore,x       ; Read from Score buffer
	sta SCREENMEM+8,x   ; Screen Memory + 9th character 
	lda HiScore,x       ; Read from Hi Score buffer
	sta SCREENMEM+26,x  ; Screen Memory + 27th character
	dex                 ; Loop 8 bytes - 7 to 0.
	bpl DoUpdateScreenScore 

	rts


; ==========================================================================
; PRINT FROGS AND LIVES
; Display the number of frogs that crossed the river.
; --------------------------------------------------------------------------
PrintFrogsAndLives
;PRINT2
	lda #INTERNAL_O     ; On Atari we're using "O" as the frog shape.
	ldx FrogsCrossed    ; number of times successfully crossed the rivers.
	beq WriteLives      ; then nothing to display. Skip to do lives.

SavedFroggies 
	sta SCREENMEM+46,x  ; Write to screen. (second line, 16th position)
	dex                 ; Decrement number of frogs.
	bne SavedFroggies   ; then go back and display the next frog counter.

WriteLives
	lda NumberOfLives   ; Get number of lives.
	clc                 ; Add to value for  
	adc #INTERNAL_0     ; Atari internal code for '0'
	sta SCREENMEM+39    ; Write to screen. Last position of first line.

	rts


; ==========================================================================
; SET BOAT SPEED
; Set the animation timer for the game screen based on the 
; number of frogs that have been saved.
;
; A  and  X  will be saved.
; --------------------------------------------------------------------------
SetBoatSpeed
	mSaveRegAX

	ldx FrogsCrossed
	cpx #12                   ; Index is 0 to 11.   
	bcc GetSpeedByWayOfFrogs  ; anything bigger than that
	ldx #11                   ; must be truncated to the limit.
GetSpeedByWayOfFrogs
	lda ANIMATION_FRAMES,x    ; Set timer for animation based on frogs.
	jsr ResetTimers

	mRestoreRegAX

	rts


; ==========================================================================
; DISPLAY GAME SCREEN
; Draw everything for game on screen.
; Scores and lives at the top.
; 19 lines of beaches and boats.
; --------------------------------------------------------------------------
DisplayGameScreen
;PRINTSC 
	jsr ClearScreen 

	ldy #PRINT_TEXT1 ; Beach and boats...
	ldx #2
LoopDisplayBoatsEtc
;PRINT ; Print TEXT1 -  beaches and boats, six times.
	jsr PrintToScreen

	inx        ; So, is tya, clc, adc #3, tay better?  probably not.
	inx
	inx

	cpx #20                 ; if we printed six times, (18 lines total) then we're done 
;	cpy #PRINT_TEXT1_1+6   
;	bcc PRINT               ; Go back and print another set of lines.
	bcc LoopDisplayBoatsEtc ; Go back and print another set of lines.

; Print TEXT2 - Beach
	ldy #PRINT_TEXT2 ; Beach with the frog present
	jsr PrintToScreen

; Identify the criminals responsible...
	ldy #PRINT_CREDIT_TXT
	ldx #22
	jsr PrintToScreen 

; Print the lives and score labels in the top two lines of the screen.
	ldy #PRINT_SCORE_TXT
	ldx #0
	jsr PrintToScreen

; Display the number of frogs that crossed the river.
	jsr PrintFrogsAndLives

; Set the animation timer for the game screen.
	jsr SetBoatSpeed

	; Reset frog position to origin..
	ldy #$13            ; Y = #$13/19 (dec) 
	sty FrogColumn      ; Frog X coord
	sty FrogLastColummn ; Where the Frog was before update.
	ldy #20 
	sty FrogRow
	sty FrogLastRow
	lda #INTERNAL_INVSPACE; $80 for inverse blank space.
	sty 

	rts



; ==========================================================================
; GAME OVER screen.
; Wait for a keypress.
; --------------------------------------------------------------------------
;INSTR ; Per PET Memory Map - Set integer value for SYS/GOTO ?
;	jsr ClearScreen 

; Print the lives and score labels in the top two lines of the screen.
;	ldy #PRINT_SCORE_TXT
;	jsr PrintToScreen

; Display the number of frogs that crossed the river.
;	jsr PrintFrogsAndLives

;	ldy #PRINT_GAMEOVER
;	jsr PrintToScreen

;INSTR1
;	jsr WaitKey           ; Atari polling the keyboard.

;	rts


; ==========================================================================
; Called once on program start.
; Use this to setup Atari display settings to imitate the   
; PET 4032's 40x25 display.
; --------------------------------------------------------------------------
GAMESTART
	; Atari initialization stuff...
	
	; Changing the Display List is potentially tricky.  If the update is 
	; interrupted by the Vertical blank, then it could mess up the display
	; list address and crash the Atari.  So, the code must make sure the 
	; system is not near the end of the screen to make the change.
	; The jiffy counter is updated during the vertical blank.  When the 
	; main code sees the counter change then it means the vertical blank is 
	; over, the electron beam is near the top of the screen thus there is 
	; now plenty of time to set the new display list pointer.  Technically, 
	; this should be done by managing SDMCTL too, but this is overkill for a 
	; program with only one display.

	jsr libScreenWaitFrame ; Wait for display to start next frame.

	; Safe to change Display list pointer now.  Would not be interrupted.
	lda #<DISPLAYLIST
	sta SDLSTL
	lda #>DISPLAYLIST
	sta SDLSTH

	; Tell the OS where screen memory starts 
	lda #<SCREENMEM ; low byte screen
	sta SAVMSC
	lda #>SCREENMEM ; hi byte screen
	sta SAVMSC+1

	lda #1
	sta CRSINH ; Turn off the displayed cursor.

	lda #0
	sta DINDEX ; Tell OS screen/cursor control is Text Mode 0
	sta LMARGN ; Set left margin to 0 (default is 2)

	lda #COLOR_GREEN ; Set screen base color dark green
	sta COLOR2       ; Background and
	sta COLOR4       ; Border
	lda #$0A
	sta COLOR1       ; Text brightness

	; End of Atari initialization stuff.

	; Continue with regular Pet Frogger initialization
	; Zero these values...
	lda #0 
	sta FlaggedHiScore
	sta LastKeyPressed

	lda #SCREEN_START  ; Set main game loop to start new game at title screen.
	sta CurrentScreen 

	jmp GameLoop ; Ready to go.  


; ==========================================================================
; RESET KEY SCAN TIMER and ANIMATION TIMER
; 
; A  is the time to set for animation.
; --------------------------------------------------------------------------
ResetTimers
	sta AnimateFrames

	pha ; preserve it for caller.
	lda #KEYSCAN_FRAMES
	sta KeyscanFrames
	pla ; get this back for the caller.

	rts


; ==========================================================================
; RESET ANIMATION TIMER
; 
; A  is the time to set for animation.
; --------------------------------------------------------------------------
ResetAnimateTimer
	sta AnimateFrames

	rts


; ==========================================================================
; NEW GAME SETUP
; --------------------------------------------------------------------------
NewGameSetup
	lda #0
	sta FrogsCrossed       ; Zero the number of successful crossings.

	lda #<[SCREENMEM+$320] ; Low Byte, Frog position.
	sta FrogLocation      
	lda #>[SCREENMEM+$320] ; Hi Byte, Frog position.
	sta FrogLocation + 1

	ldy #$13               ; Y = 19 (dec)

	lda #INTERNAL_INVSPACE ; On Atari use inverse space for beach.
	sta LastCharacter      ; Preset the character under the frog.

	lda #$12               ; 18 (dec), number of screen rows of playfield.
	sta FrogRow
	lda #$30               ; 48 (dec), delay counter.
	sta DelayNumber

	lda #INTERNAL_O        ; On Atari we're using "O" as the frog shape.
	sta (FrogLocation),y   ; SCREENMEM + $320 + $13

	jsr ClearGameScores    ; Zero the score.  And high score if not set.

	rts


; ==========================================================================
; Clear the score digits to zeros.
; That is, internal screen code for "0" 
; If a high score is flagged, then do not clear high score.
; --------------------------------------------------------------------------
ClearGameScores
	ldx #$07           ; 8 digits. 7 to 0

CLEAR
	lda #INTERNAL_0    ; Atari internal code for "0"
	sta MyScore,x      ; Put zero/"0" in score buffer.
	ldy FlaggedHiScore ; Has a high score been flagged? ($FF) 
	bmi CLNEXT         ; If so, then skip this and go to the next digit.

	sta HiScore,x      ; Also put zero/"0" in the high score. 
	tay                ; Now Y also is zero/"0".
	lda #3             ; Reset number of 
	sta NumberOfLives  ; lives to 3.
	tya                ; A  is zero/"0" again.
	ldy #$13           ; Y = 19 (dec) (again)

CLNEXT
	dex                ; decrement index to score digits.
	bpl CLEAR          ; went from 0 to $FF? no, loop for next digit.

	rts


; ==========================================================================
; TOGGLE FLIP FLOP
;
; Flip toggle state 0, 1, 0, 1, 0, 1,....
;
; Ordinarily should be EOR with #1, but I don;t trust myself that
; Toggle state ends up being something greater than 1 due to some 
; moment of sloppiness, so the absolute, slower slogging about 
; with INC and AND is done here.
;
; Uses A, CPU flag status Z indicates 0 or 1
; --------------------------------------------------------------------------
ToggleFlipFlop
	inc ToggleState ; Add 1.  (says Capt Obvious)
	lda ToggleState
	and #1          ; Squash to only lowest bit -- 0, 1, 0, 1, 0, 1...
	sta ToggleState

	rts


; ==========================================================================
; ADD 500 TO SCORE
;
; Add 500 to score.  (duh.)
;
; Uses A, X 
; --------------------------------------------------------------------------
Add500ToScore
	lda #5            ; Represents "500" Since we don't need to add to the tens and ones columns.  
	sta ScoreToAdd    ; Save to add 1
	ldx #5            ; Offset from start of "00000*00" to do the adding.
	stx NumberOfChars ; Position offset in score.
	jsr AddToScore    ; Deal with score update.

	rts


; ==========================================================================
; ADD 10 TO SCORE
;
; Add 10 to score.  (duh.)
;
; Uses A, X 
; --------------------------------------------------------------------------
Add10ToScore
	lda #1            ; Represents "10" Since we don't need to add to the ones column.  
	sta ScoreToAdd    ; Save to add 1
	ldx #6            ; Offset from start of "000000*0" to do the adding.
	stx NumberOfChars ; Position offset in score.
	jsr AddToScore    ; Deal with score update.

	rts

; ==========================================================================
; ADD TO SCORE
; 
; Add ScoreToAdd to current score at position NumberOfChars relative
; to the first digit of the score string.
; 
; A, Y, X Registers are preserved.
; --------------------------------------------------------------------------
AddToScore
SCORE
	mRegSaveAYX          ; Save A, X, and Y.

	ldx NumberOfChars    ; index into "00000000" to add score.
	lda ScoreToAdd       ; value to add to the score
	clc
	adc MyScore,x
	sta MyScore,x

EvaluateCarry            ; (re)evaluate if carry occurred for the current position.
	lda MyScore,x
	cmp #[INTERNAL_0+10] ; Did math carry past the "9"?
	bcc PULL             ; if it does not carry , then go to exit.

; The score carried past "9", so it must be adjusted and
; the next/greater position is added.
UPDATE
	lda #INTERNAL_0      ; Atari internal code for "0".  
	sta MyScore,x        ; Reset current position to "0"
	dex                  ; Go to previous position in score
	inc MyScore,x        ; Add 1 to the next digit.
	bne EvaluateCarry    ; This cannot go from $FF to 0, so it must be not zero.
;	jmp SCORE1           ; go (re)evaluate carry for the current position.

PULL                     ; All done.
	mRegRestoreAYX       ; Restore Y, X, and A

	rts


; ==========================================================================
; FROG MOVE UP
;
; Add 10 to the score, move screen memory pointer up one line, and 
; finally decrement row counter.
; (packed into a callable routine to shorten the caller's code.) 
;
; On return BEQ means the frog has reached safety.
; Thus BNE means continue game.
;
; Uses A
; --------------------------------------------------------------------------
FrogMoveUp ; Move the frog a row up.
	jsr Add10ToScore

	lda FrogLocation     ; subtract $28/40 (dec) from 
	sec                  ; the address pointing to 
	sbc #$28             ; the frog.
	sta FrogLocation
	bcs DecrementRows
	dec FrogLocation+1 

DecrementRows            ; decrement number of rows.
	dec FrogRow

	rts


; ==========================================================================
; SETUP TRANSITION TO WIN SCREEN 
;
; Prep values to run the Transition Event for the Win screen
;
; Uses A, X 
; --------------------------------------------------------------------------
SetupTransitionToWin
	jsr Add500ToScore

	lda #6                 ; Animation moving speed.
	jsr ResetTimers

	lda #0                  ; Zero event controls.
	sta EventCounter
	sta EventStage

	lda #SCREEN_TRANS_WIN   ; Next step is operating the transition animation.
	sta CurrentScreen   

	rts


; ==========================================================================
; SETUP TRANSITION TO DEAD SCREEN 
;
; Prep values to run the Transition Event for the dead frog.
; Splat frog.  
; Set timer to 1.5 second wait.
;
; Uses A, X 
; --------------------------------------------------------------------------
SetupTransitionToDead
	; splat the frog:
	lda #INTERNAL_ASTER  ; Atari ASCII $2A/42 (dec) Splattered Frog.
	sta (FrogLocation),y ; Road kill the frog.

	lda #90                 ; Initial delay moving speed.
	jsr ResetTimers

	lda #0                  ; Zero event controls.
	sta EventCounter
	sta EventStage

	lda #SCREEN_TRANS_DEAD  ; Next step is operating the transition animation.
	sta CurrentScreen   

	rts


; ==========================================================================
; Event process SCREEN START/NEW GAME
; Setup for New Game and do transition to Title screen.
; --------------------------------------------------------------------------
EventScreenStart
	jsr NewGameSetup        ; SCREEN_START, Yes. Setup for a new game.

	jsr DisplayTitleScreen  ; Draw title and game instructions.

	lda #60                 ; Text Blinking speed for prompt on Title screen.
	jsr ResetTimers

	lda #SCREEN_TITLE ; Next step is operating the title screen input.
	sta CurrentScreen

	rts


; ==========================================================================
; Event Process TITLE SCREEN
; The activity on the title screen is 
; 1) blinking the text and 
; 2) waiting for a key press.
; --------------------------------------------------------------------------
EventTitleScreen
	lda AnimateFrames            ; Did animation counter reach 0 ?
	bne CheckTitleKey            ; no, then is a key pressed? 

	jsr ToggleFlipFlop           ; Yes! Let's toggle the flashing prompt
	bne TitlePromptInverse       ; If this is 1 then display inverse prompt

	ldy #PRINT_INST_TXT4         ; Display normal prompt
	ldx #23
	jsr PrintToScreen
	jmp ResetTitlePromptBlinking

TitlePromptInverse
	ldy #PRINT_INST_TXT4_INV     ; Display inverse prompt
	ldx #23
	jsr PrintToScreen

ResetTitlePromptBlinking
	lda #60                      ; Blinking speed.
	jsr ResetTimers

CheckTitleKey
	jsr CheckKey                 ; Get a key if timer permits.
	cmp #$FF                     ; Key is pressed?
	beq EndTitleScreen           ; Nothing pressed, done with title screen.

ProcessTitleScreenInput          ; a key is pressed. Prepare for the screen transition.
	lda #10                      ; Text moving speed.
	jsr ResetTimers

	lda #3                       ; Transition Loops from third row through 21st row.
	sta EventCounter

	lda #SCREEN_TRANS_GAME       ; Next step is operating the transition animation.
	sta CurrentScreen   

EndTitleScreen
	lda CurrentScreen            ; Yeah, redundant to when a key is pressed.

	rts


; ==========================================================================
; Event Process TRANSITION TO GAME SCREEN
; The Activity in the transition area, based on timer.
; 1) Progressively reprint the credits on lines from the top of the screen 
; to the bottom.
; 2) follow with a blank line to erase the highest line of trailing text.
; --------------------------------------------------------------------------
EventTransitionToGame
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne EndTransitionToGame  ; Nope.  Nothing to do.
	lda #10                  ; yes.  Reset it.
	jsr ResetTimers

	ldy #PRINT_BLANK_TXT    ; erase top line
	ldx EventCounter
	jsr PrintToScreen

	inx                     ; next row.
	stx EventCounter        ; Save new row number
	ldy #PRINT_CREDIT_TXT   ; Print the culprits responsible
	jsr PrintToScreen

	cpx #21                 ; reached bottom of screen?
	bne EndTransitionToGame ; No.  Remain on this transition event next time.

	jsr DisplayGameScreen   ; Draw game screen.

	lda #0
	sta FrogSafety          ; Schrodinger's current frog is known to be alive.

	lda #SCREEN_GAME        ; Yes, change to game screen.
	sta CurrentScreen

EndTransitionToGame
	lda CurrentScreen

	rts


; ==========================================================================
; Event Process GAME SCREEN
; Play the game.
; 1) When the input timer allows, get a key.
; 2) Evaluate frog Movement
; 2.a) Determine exit to Win screen
; 2.b) Determine exit to Dead screen.
; 3) When the animation timer expires, shift the boat rows.
; 3.a) Determine if frog hits screen border to go to Dead screen.
; As a timer based pattern the key input is first.
; Keyboard input updates the frog's logical and physical position 
; and updates screen memory.
; The animation update forces an automatic movement of the frog 
; logically, as the frog moves with the boats and remains static
; relative to the boats.
; --------------------------------------------------------------------------
EventGameScreen
; ==========================================================================
; GAME SCREEN - Keyboard section
; --------------------------------------------------------------------------
	jsr CheckKey         ; Get a key if timer permits.
	cmp #$FF             ; Key is pressed?
	beq CheckForAnim     ; Nothing pressed, Skip the input section.

	sta LastKeyPressed   ; Save key.

	ldy FrogColumn       ; Current X coordinate
	lda LastCharacter    ; Get the last character (under the frog)
	sta (FrogLocation),y ; Erase the frog with the last character.

ProcessKey ; Process keypress
	lda LastKeyPressed       ; Restore the key press to A

	cmp #KEY_4               ; Testing for Left "4" key, #24
	bne RightKeyTest         ; No.  Go test for Right.

	dey                      ; Move Y to left.
	bpl SaveNewFrogLocation  ; Not $FF.  Go place frog on screen.
	iny                      ; It is $FF.  Correct by adding 1 to Y.
	bpl SaveNewFrogLocation  ; Place frog on screen

RightKeyTest 
	cmp #KEY_6               ; Testing for Right "6", #27
	bne UpKeyTest            ; Not "6" key, so go test for Up.

	iny                      ; Move Y to right.
	cpy #$28                 ; Did it move off screen? Position $28/40 (dec)
	bne SaveNewFrogLocation  ; No.  Go place frog on screen.
	dey                      ; Yes.  Correct by subtracting 1 from Y.
	bne SaveNewFrogLocation  ; Corrected.  Go place frog on screen.

UpKeyTest ; Test for Up "S" key
	cmp #KEY_S               ; Atari "S", #62 ?
	bne ReplaceFrogOnScreen  ; No.  Replace Frog on screen.  Try boat animation.
	jsr FrogMoveUp           ; Yes, go do UP.
	beq DoSetupForFrogWins   ; No more rows to cross. Update to frog Wins!

; Row greater than 0.  Evaluate good/bad jump. 
SaveNewFrogLocation
	lda (FrogLocation),y     ; Get the character in the new position.
	sta LastCharacter        ; Save for later when frog moves.

; Will the Pet Frog land on the Beach?
	cmp #INTERNAL_INVSPACE   ; Atari uses inverse space for beach
	beq ReplaceFrogOnScreen  ; The beach is safe. Draw the frog.

; Will the Pet Frog land in the boat?
CheckBoatLanding
	cmp #INTERNAL_BALL       ; Atari uses ball graphics, ctrl-t
	beq ReplaceFrogOnScreen  ; Yes.  Safe!  Draw the frog.  

; Safe locations have been accounted.
; Wherever the Frog will land now, it is Baaaaad.
DoSetupForYerDead
;CHECK2
	jsr SetupTransitionToDead
	clc
	bcc EndGameScreen

	; Safe location at the far beach.  the Frog is saved.
DoSetupForFrogWins
;CHECK2
	jsr SetupTransitionToWin
	clc
	bcc EndGameScreen

; Replace frog on screen, continue with boat animation.
ReplaceFrogOnScreen
;PLACE2 
	lda #INTERNAL_O          ; Atari internal code for "O" is frog.
	sta (FrogLocation),y     ; Save to screen memory to display it.
	bne CheckForAnim         ; Frog movement complete. (always branch) Do boat animation.

; ==========================================================================
; GAME SCREEN - Screen Animation
; --------------------------------------------------------------------------
CheckForAnim
	lda AnimateFrames    ; Does the timer allow the boats to move?
	bne EndGameScreen    ; Nothing at this time. Exit.

	jsr AnimateBoats     ; Move the boats around.
	jsr AutoMoveFrog     ; GOTO AUTOMVE

EndGameScreen
	lda CurrentScreen  

	rts


; ==========================================================================
; Event Process TRANSITION TO WIN
; The Activity in the transition area, based on timer.
; 1) wipe screen from top to middle, and bottom to middle
; 2) Display the Frogs SAVED!
; --------------------------------------------------------------------------
EventTransitionToWin
	lda AnimateFrames       ; Did animation counter reach 0 ?
	bne EndTransitionToWin  ; Nope.  Nothing to do.

	lda #6                  ; yes.  Reset it.
	jsr ResetTimers

	ldx EventCounter       ; Row number for text.
	cpx #13                ; From 0 to 12, erase from top to middle
	beq DoSwitchToWins     ; When at 13 then fill screen is done.

	ldy #PRINT_BLANK_TXT_INV    ; inverse blanks.  
	jsr PrintToScreen

	lda #24                ; Subtract Row number for text from 24.
	sec
	sbc EventCounter
	tax

	jsr PrintToScreen      ; And print the inverse blanks again.

	inc EventCounter
	bne EndTransitionToWin  ; Nothing else to do here.

; Clear screen is done.   Display the big prompt.
DoSwitchToWins  ; Copy the big text announcement to screen
	ldx #120
LoopPrintWinsText
	lda FROG_SAVE_GFX,x
	sta SCREENMEM+240,X
	dex
	bpl LoopPrintWinsText

;Setup for Wins screen (wait for input loop)
	lda #60                 ; Text Blinking speed for prompt on WIN screen.
	jsr ResetTimers

	lda #SCREEN_WIN         ; Change to wins screen.
	sta CurrentScreen

EndTransitionToWin
	lda CurrentScreen

	rts


; ==========================================================================
; Event Process WIN SCREEN
; The Activity in the transition area, based on timer.
;
; --------------------------------------------------------------------------
EventWinScreen
	lda AnimateFrames          ; Did animation counter reach 0 ?
	bne CheckWinKey            ; no, then is a key pressed? 

	jsr ToggleFlipFlop         ; Yes! Let's toggle the flashing prompt
	bne WinPromptInverse       ; If this is 1 then display inverse prompt

	ldy #PRINT_INST_TXT4       ; Display normal prompt
	ldx #23
	jsr PrintToScreen
	jmp ResetWinPromptBlinking

WinPromptInverse
	ldy #PRINT_INST_TXT4_INV   ; Display inverse prompt
	ldx #23
	jsr PrintToScreen

ResetWinPromptBlinking
	lda #60                    ; Blinking speed.
	jsr ResetTimers

CheckWinKey
	jsr CheckKey               ; Get a key if timer permits.
	cmp #$FF                   ; Key is pressed?
	beq EndWinScreen           ; Nothing pressed, done with title screen.

ProcessWinScreenInput          ; a key is pressed. Prepare for the screen transition.
	lda #10                    ; Text moving speed.
	jsr ResetTimers

	lda #3                     ; Transition Loops from third row through 21st row.
	sta EventCounter

	lda #SCREEN_TRANS_GAME     ; Next step is operating the transition animation.
	sta CurrentScreen   

EndWinScreen
	lda CurrentScreen          ; Yeah, redundant to when a key is pressed.

	rts

	
; ==========================================================================
; Event Process TRANSITION TO DEAD
; The Activity in the transition area, based on timer.
; 1) Progressively reprint the credits on lines from the top of the screen 
; to the bottom.
; 2) follow with a blank line to erase the highest line of trailing text.
; --------------------------------------------------------------------------
EventTransitionToDead
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne EndTransitionToDead  ; Nope.  Nothing to do.
	lda #10                  ; yes.  Reset it.
	jsr ResetTimers

	ldy #PRINT_BLANK_TXT    ; erase top line
	ldx EventCounter
	jsr PrintToScreen

	inx                     ; next row.
	stx EventCounter        ; Save new row number
	ldy #PRINT_CREDIT_TXT   ; Print the culprits responsible
	jsr PrintToScreen

	cpx #21                 ; reached bottom of screen?
	bne EndTransitionToDead ; No.  Remain on this transition event next time.

	jsr DisplayGameScreen   ; Draw game screen.

	lda #0
	sta FrogSafety          ; Schrodinger's current frog is known to be alive.

	lda #SCREEN_DEAD        ; Yes, change to game screen.
	sta CurrentScreen

EndTransitionToDead
	lda CurrentScreen

	rts

	
; ==========================================================================
; Event Process DEAD SCREEN
; The Activity in the transition area, based on timer.
;
; --------------------------------------------------------------------------
EventDeadScreen
	lda AnimateFrames            ; Did animation counter reach 0 ?
	bne CheckDeadKey            ; no, then is a key pressed? 

	jsr ToggleFlipFlop           ; Yes! Let's toggle the flashing prompt
	bne DeadPromptInverse       ; If this is 1 then display inverse prompt

	ldy #PRINT_INST_TXT4         ; Display normal prompt
	ldx #23
	jsr PrintToScreen
	jmp ResetDeadPromptBlinking

DeadPromptInverse
	ldy #PRINT_INST_TXT4_INV     ; Display inverse prompt
	ldx #23
	jsr PrintToScreen

ResetDeadPromptBlinking
	lda #60                      ; Blinking speed.
	jsr ResetTimers

CheckWinKey
	jsr CheckKey                 ; Get a key if timer permits.
	cmp #$FF                     ; Key is pressed?
	beq EndDeadScreen           ; Nothing pressed, done with title screen.

ProcessDeadScreenInput          ; a key is pressed. Prepare for the screen transition.
	lda #10                      ; Text moving speed.
	jsr ResetTimers

	lda #3                       ; Transition Loops from third row through 21st row.
	sta EventCounter

	lda #SCREEN_TRANS_GAME       ; Next step is operating the transition animation.
	sta CurrentScreen   

EndDeadScreen
	lda CurrentScreen            ; Yeah, redundant to when a key is pressed.

	rts

; ==========================================================================
; Event Process TRANSITION TO OVER
; The Activity in the transition area, based on timer.
; 1) Progressively reprint the credits on lines from the top of the screen 
; to the bottom.
; 2) follow with a blank line to erase the highest line of trailing text.
; --------------------------------------------------------------------------
EventTransitionGameOver
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne EndTransitionGameOver  ; Nope.  Nothing to do.
	lda #10                  ; yes.  Reset it.
	jsr ResetTimers

	ldy #PRINT_BLANK_TXT    ; erase top line
	ldx EventCounter
	jsr PrintToScreen

	inx                     ; next row.
	stx EventCounter        ; Save new row number
	ldy #PRINT_CREDIT_TXT   ; Print the culprits responsible
	jsr PrintToScreen

	cpx #21                 ; reached bottom of screen?
	bne EndTransitionGameOver ; No.  Remain on this transition event next time.

	jsr DisplayGameScreen   ; Draw game screen.

	lda #0
	sta FrogSafety          ; Schrodinger's current frog is known to be alive.

	lda #SCREEN_OVER        ; Yes, change to game screen.
	sta CurrentScreen

EndTransitionGameOver
	lda CurrentScreen

	rts

; ==========================================================================
; Event Process GAME OVER SCREEN
; The Activity in the transition area, based on timer.
;
; --------------------------------------------------------------------------
EventGameOverScreen
	lda AnimateFrames           ; Did animation counter reach 0 ?
	bne CheckOverKey            ; no, then is a key pressed? 

	jsr ToggleFlipFlop          ; Yes! Let's toggle the flashing prompt
	bne OverPromptInverse       ; If this is 1 then display inverse prompt

	ldy #PRINT_INST_TXT4        ; Display normal prompt
	ldx #23
	jsr PrintToScreen
	jmp ResetDeadPromptBlinking

DeadPromptInverse
	ldy #PRINT_INST_TXT4_INV    ; Display inverse prompt
	ldx #23
	jsr PrintToScreen

ResetDeadPromptBlinking
	lda #60                     ; Blinking speed.
	jsr ResetTimers

CheckWinKey
	jsr CheckKey                ; Get a key if timer permits.
	cmp #$FF                    ; Key is pressed?
	beq EndDeadScreen           ; Nothing pressed, done with title screen.

ProcessDeadScreenInput          ; a key is pressed. Prepare for the screen transition.
	lda #10                     ; Text moving speed.
	jsr ResetTimers

	lda #3                      ; Transition Loops from third row through 21st row.
	sta EventCounter

	lda #SCREEN_TRANS_TITLE     ; Next step is operating the transition animation.
	sta CurrentScreen   

EndDeadScreen
	lda CurrentScreen           ; Yeah, redundant to when a key is pressed.

	rts


; ==========================================================================
; Event Process TRANSITION TO TITLE
; The Activity in the transition area, based on timer.
; 1) Progressively reprint the credits on lines from the top of the screen 
; to the bottom.
; 2) follow with a blank line to erase the highest line of trailing text.
; --------------------------------------------------------------------------
EventTransitionToTitle
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne EndTransitionToTitle ; Nope.  Nothing to do.
	lda #10                  ; yes.  Reset it.
	jsr ResetTimers

	ldy #PRINT_BLANK_TXT     ; erase top line
	ldx EventCounter
	jsr PrintToScreen

	inx                      ; next row.
	stx EventCounter         ; Save new row number
	ldy #PRINT_CREDIT_TXT    ; Print the culprits responsible
	jsr PrintToScreen

	cpx #21                  ; reached bottom of screen?
	bne EndTransitionToTitle ; No.  Remain on this transition event next time.

	jsr DisplayGameScreen    ; Draw game screen.

	lda #0
	sta FrogSafety           ; Schrodinger's current frog is known to be alive.

	lda #SCREEN_START        ; Yes, change to beginning of event cycle/start new game.
	sta CurrentScreen

EndTransitionToTitle
	lda CurrentScreen

	rts


; ==========================================================================
; GAME LOOP 
;
; The main loop for the game... said Capt Obvious.
; Very vaguely like an event loop or state loop across the progressive 
; game states which are (more or less) based on the current mode of 
; the display.
;
; Rules:  "Continue" labels for the next screen/event block must  
;         be called with screen value in A.  Therefore, each Event 
;         routine should end by lda CurrentScreen.
; --------------------------------------------------------------------------

GameLoop
; ==========================================================================
; SCREEN START/NEW GAME
; Setup for New Game and do transition to Title screen.
; --------------------------------------------------------------------------
	lda CurrentScreen
	cmp #SCREEN_START
	bne ContinueTitleScreen ; SCREEN_START=0?  No? 

	jsr EventScreenStart

; ==========================================================================
; TITLE SCREEN
; The activity on the title screen is 
; 1) blinking the text and 
; 2) waiting for a key press.
; --------------------------------------------------------------------------
ContinueTitleScreen
	cmp #SCREEN_TITLE
	bne ContinueTransitionToGame

	jsr EventTitleScreen

; ==========================================================================
; TRANSITION TO GAME SCREEN
; The Activity in the transition area, based on timer.
; 1) Progressively reprint the credits on lines from the top of the screen 
; to the bottom.
; 2) follow with a blank line to erase the highest line of trailing text.
; --------------------------------------------------------------------------
ContinueTransitionToGame
	cmp #SCREEN_TRANS_GAME
	bne ContinueGameScreen

	jsr EventTransitionToGame

; ==========================================================================
; GAME SCREEN
; Play the game.
; 1) When the input timer allows, get a key.
; 2) Evaluate frog Movement
; 2.a) Determine exit to Win screen
; 2.b) Determine exit to Dead screen.
; 3) When the animation timer expires, shift the boat rows.
; 3.a) Determine if frog hits screen border to go to Dead screen.
; As a timer based pattern the key input is first.
; Keyboard input updates the frog's logical and physical position 
; and updates screen memory.
; The animation update forces an automatic movement of the frog 
; logically, as the frog moves with the boats and remains static
; relative to the boats.
; --------------------------------------------------------------------------
ContinueGameScreen
	cmp #SCREEN_GAME
	bne ContinueTransitionToWin

	jsr EventGameScreen

; ==========================================================================
; TRANSITION TO WIN SCREEN
; The Activity in the transition area, based on timer.
; 1) Animate something.
; 2) End With display of WIN Screen.
; --------------------------------------------------------------------------
ContinueTransitionToWin
	cmp #SCREEN_TRANS_WIN
	bne ContinueWinScreen

	jsr EventTransitionToWin

EndTransitionToWin
	lda CurrentScreen  

; ==========================================================================
; WIN SCREEN
; The activity in the WIN screen.
; 1) blinking the text and 
; 2) waiting for a key press.
; --------------------------------------------------------------------------
ContinueWinScreen
	cmp #SCREEN_WIN
	bne ContinueTransitionToDead

	jsr EventWinScreen

EndWinScreen
	lda CurrentScreen 

; ==========================================================================
; TRANSITION TO DEAD SCREEN
; The Activity in the transition area, based on timer.
; 1) Animate something.
; 2) End With display of DEAD Screen.
; --------------------------------------------------------------------------
ContinueTransitionToDead
	cmp #SCREEN_TRANS_DEAD
	bne ContinueDeadScreen

	jsr EventTransitionToDead

EndTransitionToDead
	lda CurrentScreen  

; ==========================================================================
; DEAD SCREEN
; The activity in the DEAD screen.
; 1) blinking the text and 
; 2) waiting for a key press.
; 3.a) Evaluate to continue to game screen
; 3.b.) Evaluate to continue to Game Over
; --------------------------------------------------------------------------
ContinueDeadScreen
	cmp #SCREEN_DEAD
	bne ContinueTransitionToOver

	jsr EventDeadScreen

EndDeadScreen
	lda CurrentScreen 

; ==========================================================================
; TRANSITION TO GAME OVER SCREEN
; The Activity in the transition area, based on timer.
; 1) Animate something.
; 2) End With display of GAME OVER Screen.
; --------------------------------------------------------------------------
ContinueTransitionToOver
	cmp #SCREEN_TRANS_OVER
	bne ContinueOverScreen

	jsr EventTransitionGameOver

EndTransitionToOver
	lda CurrentScreen  

; ==========================================================================
; GAME OVER SCREEN
; The activity in the DEAD screen.
; 1) blinking the text and 
; 2) waiting for a key press.
; --------------------------------------------------------------------------
ContinueOverScreen
	cmp #SCREEN_OVER
	bne ContinueTransitionToTitle

	jsr EventGameOverScreen

EndOverScreen
	lda CurrentScreen 

; ==========================================================================
; TRANSITION TO TITLE 
; The Activity in the transition area, based on timer.
; 1) Animate something.
; 2) End With going to the Title Screen.
; --------------------------------------------------------------------------
ContinueTransitionToTitle
	cmp #SCREEN_TRANS_TITLE
	bne EndGameLoop

	jsr EventTransitionToTitle

EndTransitionToTitle
	lda CurrentScreen  

; ==========================================================================
; END OF GAME EVENT LOOP
; --------------------------------------------------------------------------
EndGameLoop
	jsr TimerLoop    ; Wait for end of frame and update the timers.

	jmp GameLoop     ; rinse, repeat, forever.

	rts





; Frog is dead.
YerADeadFrog
YRDD
	lda #INTERNAL_ASTER  ; Atari ASCII $2A/42 (dec) Splattered Frog.
	sta (FrogLocation),y ; Road kill the frog.
;	jsr DELAY1           ; Various pauses....
;	jsr DELAY1           ; Should do this with  jiffy counters. future TO DO.
	jsr FILLSC           ; Fill screen with inverse blanks.

; Print the dead frog prompt.
;	ldy #PRINT_YRDDTX
	jsr PrintToScreen

	
; Decide   G A M E   O V E R-ish

DecideGameOver
GAMEOV
	jsr PRITSC           ; update display.
	jsr DELAY1
	dec NumberOfLives    ; subtract a life.
	lda NumberOfLives
	cmp #0               ; 0 lives left means
	beq GOV              ; definitely game over.
	lda #$FF
	sta FlaggedHiScore   ; flag the high score
	jmp START1

VerilyISayGameOver
GOV
	lda #$FF
	sta CH    ; Atari.  Make sure key is cleared.
	jmp GOVER ; G A M E   O V E R


FrogWins
	inc FrogsCrossed     ; Add to frogs successfully crossed the rivers.
	jsr FILLSC           ; Update the score display

FrogWins1 ; Print the frog wins text.
;	ldy #PRINT_FROGTXT
	jsr PrintToScreen

FrogWins2  ; More score maintenance.   and delays.
	jsr SCORE
;	jsr PRITSC
;	jsr DELAY1
	jmp NEXTFR




FILLSC  ; Setup pointer to screen. then fill screen
	lda #<[SCREENMEM+$50]  ; point to screen memory +80 bytes (2 lines from top)
	sta ScreenPointer
	lda #>[SCREENMEM+$50]
	sta ScreenPointer+1

; This was inside FILL, but only needs to be done once before the loop
	ldy #0
FILL ; Fill screen with the "beach" characters
	lda #INTERNAL_INVSPACE ; Atari beach character is inverse space.
	sta (ScreenPointer),y
	lda ScreenPointer      ; Increment  
	clc                    ; the  
	adc #1                 ; pointer 
	sta ScreenPointer      ; to  
	lda ScreenPointer+1    ; screen 
	adc #0                 ; memory.
	sta ScreenPointer+1    ; You know, inc lowbyte, bne FILL works instead of adc.
	cmp #>[SCREENMEM+$400] ; Did high byte reach $8400 (screen memory + 1K)?
	bne FILL               ; Nope, continue filling.

; Setup for score update.
	ldx #4
	lda #5

	stx NumberOfChars      ; Index into "00000000" to add the score.
	sta ScoreToAdd         ; Add 5 which represents "500" to the score.  Don't need 10s or 1s values, since they are 0.

	jsr PRINT2             ; Display frogs count
	ldy #0
	rts


; ==========================================================================
; Update starting frog position.
; --------------------------------------------------------------------------
NEXTFR
	lda DelayNumber        ; Subtract 3 from delay number...
	sec
	sbc #3
	sta DelayNumber

START1 ; Manage frog's starting postion.
	lda #<[SCREENMEM+$320] ; Set Frog Location pointer to $8320
	sta FrogLocation
	lda #>[SCREENMEM+$320]
	sta FrogLocation + 1

	jsr PRINTSC
	jsr MOVESC

	lda #INTERNAL_INVSPACE ; Atari: Beach character 
	sta LastCharacter      ; Prep space under frog

	lda #INTERNAL_O        ; Atari: using "O" as the frog shape.

	ldy #$13               ; Y = 19 (dec) the middle of screen
	sta (FrogLocation),y   ; Erase Frog starting position.
	lda #$12               ; A = 18 (dec)
	sta FrogRow       ; Save as number of rows to jump
	
	jmp KEY                ; GOTO Key input


; ==========================================================================
; Add to score.
; --------------------------------------------------------------------------
SCORE
	mRegSaveAYX               ; Save A, X, and Y.

	ldx NumberOfChars ; index into "00000000" to add score.
	lda ScoreToAdd    ; value to add to the score
	clc
	adc MyScore,x
	sta MyScore,x

SCORE1                   ; (re)evaluate if carry occurred for the current position.
	lda MyScore,x
	cmp #[INTERNAL_0+10] ; Did math carry past the "9"?
	bcc PULL             ; if it does not carry , then go to exit.

; The score carried past "9", so it must be adjusted and
; the next/greater position is added.
UPDATE
	lda #INTERNAL_0 ; Atari internal code for "0".  
	sta MyScore,x   ; Reset current position to "0"
	dex             ; Go to previous position in score
	inc MyScore,x   ; Add 1 to the next digit.
	bne SCORE1      ; This cannot go from $FF to 0, so it must be not zero.
;	jmp SCORE1      ; go (re)evaluate carry for the current position.

PULL                     ; All done.
	mRegRestoreAYX  ; Restore Y, X, and A

	rts


; ==========================================================================
; Game Over - Prompt to go again.
; --------------------------------------------------------------------------
GOVER
	ldy #0

GOVER1                 ; Print the go again message.
;	ldy #PRINT_OVER
	jsr PrintToScreen

GOVER2
	jsr WaitKey        ; For Atari, wait for a key press.  returned in A
	cmp #KEY_Y         ; keyboard code for Y 
	bne GOVER3         ; Not "Y".

	jsr HISC           ; Manage high score
	lda #$FF           ; Re-init a few things. . . .
	sta FlaggedHiScore ;
	lda #0
	sta FrogsCrossed
	lda #3
	sta NumberOfLives
	jmp START          ; Back to start.

GOVER3
	jsr INSTR          ; Display instructions.
	jsr HISC           ; Manage high score
	lda #$FF
	sta FlaggedHiScore ; Re-init a few things. . . .
	lda #3
	sta NumberOfLives
	jmp START          ; Back to start.


; ==========================================================================
; Figure out if My Score is the High Score
; --------------------------------------------------------------------------
HighScoreOrNot
HISC
	lda #0

CompareScoreToHighScore
HISC2
	lda MyScore,x               ; Get my score
	clc
	cmp HiScore,x               ; Compare to high score
	beq ContinueCheckingScores  ; Equals?  then so far it is not high score
	bcs CopyNewHighScore        ; Greater than.  Would be new high score.

ContinueCheckingScores
NOT
	inx
	cpx #7                      ; Are all 7 digits tested?
	bne CompareScoreToHighScore ; No, then go do next digit.
	rts                         ; Yes.  Done.

CopyNewHighScore
HISC1                           ; It is a high score.
	lda MyScore,x               ; Copy my score to high score
	sta HiScore,x
	inx
	cpx #7                      ; if the first 7 digits are not done testing, then
	bne CopyNewHighScore        ; go test next digit.

	rts


; ==========================================================================
; Check for a keypress based on timer state. 
;
; A  returns the key pressed.  or returns $FF for no key pressed.
; If the timer allows reading, and a key is found, then the timer is 
; reset for the time of the next key input cycle.
; --------------------------------------------------------------------------
CheckKey
	lda KeyscanFrames         ; Is keyboard timer delay  0?
	bne ExitCheckKeyNow       ; No. thus no key to scan.

	lda CH
	pha                       ; Save the key for later

	cmp #$FF                  ; No key pressed, so nothing to do.
	beq ExitCheckKey
	 
	lda #$FF                  ; Got a key.  
	sta CH                    ; Clear register for next key read.

	lda #KEYSCAN_FRAMES       ; Reset keyboard timer for next key input.
	sta KeyscanFrames

ExitCheckKey                  ; exit with some kind of key value in A.
	pla                       ; restore the pressed key in A.
	rts

ExitCheckKeyNow               ; exit with no key value in A
	lda #$FF
	rts


; ==========================================================================
; Wait for a keypress. 
;
; A  returns the key pressed.
; --------------------------------------------------------------------------
WaitKey
	lda #$FF
	sta CH          ; Clear any pending key

WaitKeyLoop
	lda CH
	cmp #$FF        ; No key pressed
	beq WaitKeyLoop ; Loop until a key is pressed.

	pha             ; Save the key
	lda #$FF
	sta CH          ; Clear any pending key
	pla             ; return the pressed key in A.

	rts


;==============================================================================
;                                                           TIMERLOOP  A
;==============================================================================
; Primitive timer loop.
;
; When the game design is more Atari-ficated (planned Version 02) this is part 
; of the program's deferred Vertical Blank Interrupt routine.  This routine 
; services any display-oriented updates and notifications for the mainline 
; code that runs during the bulk of the frame.
;
; Main code calls this at the end of its cycle, then afterwards it restarts 
; its cycle.  
; This routine waits for the current frame to finish display, then 
; manages the timers/countdown values.
; It is the responsibility of the main line code to observe when timers
; reach 0 and reset them or act accordingly.
;
; All registers are preserved.
;==============================================================================

TimerLoop
	mRegSaveAYX

	lda DoTimers           ; Are timers turned on or off?
	beq ExitEventLoop      ; Off, skip it all.

	jsr libScreenWaitFrame ; Wait until end of frame

	lda KeyscanFrames      ; Is keyboard delay already 0?
	beq DoAnimateClock     ; Yes, do not decrement it again.
	dec KeyscanFrames      ; Minus 1.

DoAnimateClock
	lda AnimateFrames      ; Is animation countdown already 0?
	beq ExitEventLoop      ; Yes, do not decrement now.
	dec AnimateFrames      ; Minus 1

ExitEventLoop
	mRegRestoreAYX

	rts


;==============================================================================
;                                                       SCREENWAITFRAMES  A  Y
;==============================================================================
; Subroutine to wait for a number of frames.
;
; FYI:
; Calling with A = 1 is the same thing as directly calling ScreenWaitFrame.
;
; ScreenWaitFrames expects A to contain the number of frames.
;
; ScreenWaitFrames uses  Y
;==============================================================================
	
libScreenWaitFrames
	sty SAVEY           ;  Save what is here, can't go to stack due to tay 
	tay
	beq bExitWaitFrames

bLoopWaitFrames
	jsr libScreenWaitFrame

	dey
	bne bLoopWaitFrames ; Still more frames to count?   go 

bExitWaitFrames
	ldy SAVEY           ; restore Y
	rts                 ; No.  Clock changed means frame ended.  exit.


;==============================================================================
;                                                           SCREENWAITFRAME  A
;==============================================================================
; Subroutine to wait for the current frame to finish display.
;
; ScreenWaitFrame  uses A
;==============================================================================
	
libScreenWaitFrame
	pha                ; Save A, so caller is not disturbed.
	lda RTCLOK60       ; Read the jiffy clock incremented during vertical blank.

bLoopWaitFrame
	cmp RTCLOK60       ; Is it still the same?
	beq bLoopWaitFrame ; Yes.  Then the frame has not ended.

	pla                ; restore A
	rts                ; No.  Clock changed means frame ended.  exit.


; ==========================================================================
; When a custom character set is used, it would go here:
; --------------------------------------------------------------------------

;	ORG $7800 ; 1K from $7800 to $7BFF
;CHARACTERSET


; ==========================================================================
; Custom Character Set Planning . . . **Minimum setup.
;
;  1) **Frog
;  2) **Boat Front Right
;  3) **Boat Back Right
;  4) **Boat Front Left
;  5) **Boat Back Left
;  6) **Boat Seat
;  7) **Splattered Frog.
;  8)   Waves 1
;  9)   Waves 2
; 10)   Waves 3
; 11) **Beach 1
; 12)   Beach 2
; 13)   Beach 3
;
; --------------------------------------------------------------------------
 

; ==========================================================================
; Force the Atari to impersonate the PET 4032 by setting the 40-column
; text mode memory to the same fixed address.  This minimizes the 
; amount of code changes for screen memory.
;
; But, first we need a 25-line ANTIC Mode 2 text screen which means a  
; custom display list.
; 
; The Atari OS text printing is not being used, therefore the Atari screen 
; editor's 24-line limitation is not an issue. 
; --------------------------------------------------------------------------

	ORG $7FD8  ; $xxD8 to xxFF - more than enough space for Display List
	
DISPLAYLIST
	.byte DL_BLANK_8, DL_BLANK_8, DL_BLANK_4 ; 20 blank scan lines.
	mDL_LMS DL_TEXT_2,SCREENMEM              ; Mode 2 text and Load Memory Scan for text/graphics
	.rept 24
		.byte DL_TEXT_2                      ; 24 more lines of Mode 2 text.
	.endr
	.byte DL_JUMP_VB
	.word DISPLAYLIST


; ==========================================================================
; Make Screen memory the same location the Pet uses for screen memory.
; --------------------------------------------------------------------------
	ORG $8000

SCREENMEM


; ==========================================================================
; Inform DOS of the program's Auto-Run address...
; --------------------------------------------------------------------------
	mDiskDPoke DOS_RUN_ADDR, GAMESTART
	
	
	END

