; ==========================================================================
; Pet Frogger
; (c) November 1983 by John C. Dale, aka Dalesoft
; for the Commodore Pet 4032
;
; ==========================================================================
; Ported (parodied) to Atari 8-bit computers
; by Ken Jennings (if this were 1983, aka FTR Enterprises)
;
; Version 00, November 2018
; Version 01, December 2018
; Version 02, February 2019
; Version 03, March 2019
;
; --------------------------------------------------------------------------

; ==========================================================================
; Screen Memory
;
; The Atari OS text printing is not being used, therefore the Atari OS's
; screen editor's 24-line limitation is not an issue.  The game can be 
; 25 lines like the original Pet 4032 screen.  Or it can be more. 
; Sooooo, custom display list means do what we want.
;
; Prior versions used Mode 2 text lines exclusively to perpetuate the 
; flavor of the original's text-mode-based game.
; 
; However, Version 03 makes a few changes.  The chunky text used for the
; title and the dead/saved/game-over screens was built from Atari 
; graphics control characters.   Version 03 changes this to a graphics 
; mode that provides the same chunky-pixel size, but at only half the 
; memory for the same screen geometry.  Two lines of graphics is 
; vertically the same height as one line of text.  The block characters
; patterns provide two apparent rows of pixels, so, everything is equal.  
;
; Switching to a graphics mode for the big text allows:
; * Complete color expression for background into the overscan 
;   area, and for the pixels if we so choose.  (Text mode 2 manages 
;   playfield and border colors differently.) 
; * Six lines of graphics in place of three lines of text makes it 
;   trivial to double the number of color changes in the big text.
;   Just a DLI for each line.
; * Without a separate border vs text background an apparent wider 
;   screen width can be faked using the background through the 
;   overscan area. 
;  
; In Version 02 blank lines of mode 2 text were used and colored 
; to make animated prize displays.  Instead of using a text mode 
; we use actual blank lines instructions.  Again, since these display 
; background color into the overscan area the prize animations are 
; larger, filling the entire screen width.  Also, blanks smaller 
; than a text line allow more frequent color transitions.  Thus more 
; color on one display is more eye candy on one display.
;
; Remember, screen memory need not be contiguous from line to line.
; Therefore, we can re-think the declaration of screen contents and
; rearrange it in ways to benefit the code:
;
; 1) The first thing is that data declared for display on screen IS the
;    screen memory.  It is not something that must be copied to screen
;    memory.  Data properly placed in any memory makes it the actual
;    screen memory thanks to the Display List LMS instructions.
; 2) a) In all the prior versions all the rows of boats moving left look 
;       the same, and all the rows moving right looked the same.  
;       Version 02 declared another copy of data for every line of boats.
;       This was necessary, because the frog was drawn in screen memory 
;       and must appear on every row.
;    b) But now, since the frog is a Player/Missile object there is no 
;       need to change the screen memory to draw the frog.   Therefore,
;       all the boat rows could the the same screen memory.  Declaring 
;       one row of left boats, and one row of right boats saves the 
;       contents of 10 more rows of the same.  This is actually a 
;       significant part of the entire executable. 
;    c) Even if the same data is used for each type of boat, they do not 
;       need to appear identical on screen.   If each row has its own 
;       concept of current scroll value, then all the rows can be in 
;       different positions of scrolling, though using the same data.
; 3) Since scrolling is in effect the line width is whatever is needed 
;    to allow the boats to move from an original position to destination
;    and then return the the original scroll position.  If the boats 
;    and waves between them are identical then the entire line of boats 
;    does not need to be duplicated.  There only need to be enough 
;    data to scroll from one boat position to the next.
; 3) Organizing the boats row of graphics to sit within one page of data 
;    means scrolling updates and LMS math only need deal with the low
;    byte of addresses. 
; 3) To avoid wasting space the lines of data from other displays can be
;    dropped into the unused spaces between scrolling sections.
; --------------------------------------------------------------------------

ATASCII_HEART  = $00 ; heart graphics

; Atari uses different, "internal" values when writing to
; Screen RAM.  These are the internal codes for writing
; bytes directly to the screen:
INTERNAL_0        = $10 ; Number '0' for scores.
INTERNAL_SPACE    = $00 ; Blank space character.
;INTERNAL_HLINE    = $52 ; underline for title text.

;I_H = INTERNAL_HLINE

SIZEOF_LINE    = 39  ; That is, 40 - 1
SIZEOF_BIG_GFX = 119 ; That is, 120 - 1


; Revised V03 Title Screen and Instructions:
;    +----------------------------------------+
; 1  |Score:00000000               00000000:Hi| SCORE_TXT
; 2  |                                        |
; 3  |              PET FROGGER               | TITLE
; 4  |              PET FROGGER               | TITLE
; 5  |              PET FROGGER               | TITLE
; 6  |              --- -------               | TITLE
; 7  |                                        |
; 8  |Help the frogs escape from Doc Hopper's | INSTXT_1
; 9  |frog legs fast food franchise! But, the | INSTXT_1
; 10 |frogs must cross piranha-infested rivers| INSTXT_1
; 11 |to reach freedom. You have three chances| INSTXT_1
; 12 |to prove your frog management skills by | INSTXT_1
; 13 |directing frogs to jump on boats in the | INSTXT_1
; 14 |rivers like this:  <QQQQ]  Land only on | INSTXT_1
; 15 |the seats in the boats ('Q').           | INSTXT_1
; 16 |                                        |
; 17 |Scoring:                                | INSTXT_2
; 18 |    10 points for each jump forward.    | INSTXT_2
; 19 |   500 points for each rescued frog.    | INSTXT_2
; 20 |                                        |
; 21 |Use joystick control to jump forward,   | INSTXT_3
; 22 |left, and right.                        | INSTXT_3
; 23 |                                        |
; 24 |   Press joystick button to continue.   | ANYBUTTON_MEM
; 25 |(c) November 1983 by DalesOft  Written b| SCROLLING CREDIT
;    +----------------------------------------+


; Revised V03 Main Game Play Screen:
; FYI: Old boats.
; 8  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_2
; 9  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_2
; New boats are larger to provide more safe surface for the larger 
; frog and to provide some additional graphics enhancement for 
; the boats.  Illustration below shows the entire memory needed 
; for scrolling.
;    +----------------------------------------+
; 1  |Score:00000000               00000000:Hi| SCORE_TXT
; 2  |Frogs:0    Frogs Saved:OOOOOOOOOOOOOOOOO| SCORE_TXT
; 3  |                                        | <-Grassy color
; 4  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_1
; 5  |[[QQQQQ>        [[QQQQQ>        [[QQQQQ>        [[QQQQQ>        | ; Boats Right
; 6  |<QQQQQ]]        <QQQQQ]]        <QQQQQ]]        <QQQQQ]]        | ; Boats Left
; 7  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_2
; 8  |[[QQQQQ>        [[QQQQQ>        [[QQQQQ>        [[QQQQQ>        |
; 9  |<QQQQQ]]        <QQQQQ]]        <QQQQQ]]        <QQQQQ]]        |
; 10 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_3
; 11 |[[QQQQQ>        [[QQQQQ>        [[QQQQQ>        [[QQQQQ>        |
; 12 |<QQQQQ]]        <QQQQQ]]        <QQQQQ]]        <QQQQQ]]        |
; 13 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_4
; 14 |[[QQQQQ>        [[QQQQQ>        [[QQQQQ>        [[QQQQQ>        |
; 15 |<QQQQQ]]        <QQQQQ]]        <QQQQQ]]        <QQQQQ]]        |
; 16 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_5
; 17 |[[QQQQQ>        [[QQQQQ>        [[QQQQQ>        [[QQQQQ>        |
; 18 |<QQQQQ]]        <QQQQQ]]        <QQQQQ]]        <QQQQQ]]        |
; 19 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_6
; 20 |[[QQQQQ>        [[QQQQQ>        [[QQQQQ>        [[QQQQQ>        |
; 21 |<QQQQQ]]        <QQQQQ]]        <QQQQQ]]        <QQQQQ]]        |
; 22 |BBBBBBBBBBBBBBBBBBBOBBBBBBBBBBBBBBBBBBBB| TEXT2
; 23 |                                        | <-Grassy color
; 24 |                                        |
; 25 |(c) November 1983 by DalesOft  Written b| SCROLLING CREDIT
;    +----------------------------------------+

; These things repeat four times.
; Let's just type it once and macro it elsewhere.

; 5  |[[QQQQQ>        [[QQQQQ>        [[QQQQQ>        [[QQQQQ>        | ; Boats Right
	.macro mBoatGoRight
		.by I_BOAT_RB I_BOAT_RB I_SEATS I_SEATS I_SEATS I_SEATS I_SEATS I_BOAT_RF           ;   8
		.by I_WAVES_L I_WAVES_R I_WAVES_L I_WAVES_R I_WAVES_L I_WAVES_R I_WAVES_L I_WAVES_R ; + 8 = 16
	.endm

	.macro mLineOfRightBoats
		.rept 4
			mBoatGoRight ; 16 * 4 = 64
		.endr
	.endm


; 6  |<QQQQQ]]        <QQQQQ]]        <QQQQQ]]        <QQQQQ]]        | ; Boats Left
	.macro mBoatGoLeft
		.by I_BOAT_RB I_BOAT_RB I_SEATS I_SEATS I_SEATS I_SEATS I_SEATS I_BOAT_RF           ;   8
		.by I_WAVES_L I_WAVES_R I_WAVES_L I_WAVES_R I_WAVES_L I_WAVES_R I_WAVES_L I_WAVES_R ; + 8 = 16
	.endm

	.macro mLineOfLeftBoats
		.rept 4
			mBoatGoLeft ; 16 * 4 = 64
		.endr
	.endm


; ANTIC has a 4K boundary for screen memory.
; But, since the visibly adjacent lines of screen data need not be
; contiguous in memory we can simply align screen data into 256
; byte pages only making sure a line doesn't cross the end of a 
; bage.  This will prevent any line of displayed data from crossing 
; over a 4K boundary.


	.align $0100 ; Realign to next page.

; The declarations below are arranged to make sure
; each line of data fits within 256 byte pages.

; Remember, lines of screen data need not be contiguous to
; each other since LMS in the Display List tells ANTIC where to 
; start reading screen memory.  Therefore we can declare lines in
; any order....   Just remember to use LMS in the Display List 
; when data is not contiguous, OK.


; The lines of scrolling boats.  Only one line of data for each 
; direction is declared.  Every other moving row can re-use the 
; same data for display.  Also, since the entire data fits within 
; one page, the coarse scrolling need only update the low byte of 
; the LMS instruction....
 
; 5  |[[QQQQQ>        [[QQQQQ>        [[QQQQQ>        [[QQQQQ>        | ; Boats Right ;   64
; Start Scroll position = LMS + 12 (decrement), HSCROL 0  (Increment)
; End   Scroll position = LMS + 0,              HSCROL 15
PLAYFIELD_MEM1
PLAYFIELD_MEM4
PLAYFIELD_MEM7
PLAYFIELD_MEM10
PLAYFIELD_MEM13
PLAYFIELD_MEM16
	mLineOfRightBoats


; Title text.  Bitmapped version for Mode 9.
; Will not scroll these, so no need for individual labels and leading blanks.
; 60 bytes here instead of the 240 bytes used for the scrolling text version.

; Graphics chars design, PET FROGGER
; |**|**|* |  |**|**|**|  |**|**|**|  |  |**|**|**|  |**|**|* |  | *|**|* |  | *|**|**|  | *|**|**|  |**|**|**|  |**|**|* |
; |**|  |**|  |**|  |  |  |  |**|  |  |  |**|  |  |  |**|  |**|  |**|  |**|  |**|  |  |  |**|  |  |  |**|  |  |  |**|  |**|
; |**|  |**|  |**|**|* |  |  |**|  |  |  |**|**|* |  |**|  |**|  |**|  |**|  |**|  |  |  |**|  |  |  |**|**|* |  |**|  |**|
; |**|**|* |  |**|  |  |  |  |**|  |  |  |**|  |  |  |**|**|* |  |**|  |**|  |**| *|**|  |**| *|**|  |**|  |  |  |**|**|* |
; |**|  |  |  |**|  |  |  |  |**|  |  |  |**|  |  |  |**| *|* |  |**|  |**|  |**|  |**|  |**|  |**|  |**|  |  |  |**| *|* |
; |**|  |  |  |**|**|**|  |  |**|  |  |  |**|  |  |  |**|  |**|  | *|**|* |  | *|**|**|  | *|**|**|  |**|**|**|  |**|  |**|

TITLE_MEM1
	.by %11111000 %11111100 %11111100 %00111111 %00111110 %00011110 %00011111 %00011111 %00111111 %00111110
	.by %11001100 %11000000 %00110000 %00110000 %00110011 %00110011 %00110000 %00110000 %00110000 %00110011
	.by %11001100 %11111000 %00110000 %00111110 %00110011 %00110011 %00110000 %00110000 %00111110 %00110011
	.by %11111000 %11000000 %00110000 %00110000 %00111110 %00110011 %00110111 %00110111 %00110000 %00111110
	.by %11000000 %11000000 %00110000 %00110000 %00110110 %00110011 %00110011 %00110011 %00110000 %00110110
	.by %11000000 %11111100 %00110000 %00110000 %00110011 %00011110 %00011111 %00011111 %00111111 %00110011 ; + 60

; 4  |--- --- ---  --- --- --- --- --- --- ---| TITLE underline

	.by %11111100 %11111100 %11111100 %00111111 %00111111 %00111111 %00111111 %00111111 %00111111 %00111111 ; + 10 

ANYBUTTON_MEM ; Prompt to start game.
; 24 |   Press joystick button to continue.   | INSTXT_4 
	.sb "   Press joystick button to continue.   "

INSTRUCT_MEM1 ; Basic instructions...
; 6  |Help the frogs escape from Doc Hopper's | INSTXT_1
	.sb "Help the frogs escape from Doc Hopper's "

INSTRUCT_MEM2
; 7  |frog legs fast food franchise! But, the | INSTXT_1
	.sb "frog legs fast food franchise! But, the "


	.align $0100 ; Realign to next page.


; 6  |<QQQQQ]]        <QQQQQ]]        <QQQQQ]]        <QQQQQ]]        | ; Boats Left ; + 64 
; Start Scroll position = LMS + 0 (increment), HSCROL 15  (Decrement)
; End   Scroll position = LMS + 12,            HSCROL 0
PLAYFIELD_MEM2
PLAYFIELD_MEM5
PLAYFIELD_MEM8
PLAYFIELD_MEM11
PLAYFIELD_MEM14
PLAYFIELD_MEM17
	mLineOfLeftBoats

INSTRUCT_MEM3
; 8  |frogs must cross piranha-infested rivers| INSTXT_1
	.sb "frogs must cross piranha-infested rivers"

INSTRUCT_MEM4
; 9  |to reach freedom. You have three chances| INSTXT_1
	.sb "to reach freedom. You have three chances"

INSTRUCT_MEM5
; 10 |to prove your frog management skills by | INSTXT_1
	.sb "to prove your frog management skills by "

INSTRUCT_MEM6
; 11 |directing frogs to jump on boats in the | INSTXT_1
	.sb "directing frogs to jump on boats in the "


	.align $0100 ; Realign to next page.


; The Credit text.  Rather than three lines on the main
; and game screen let's make this a continuously scrolling
; line of text on all screens.  This requires two more blocks
; of blank text to space out the start and end of the text.

; Originally:
; 3  |     (c) November 1983 by DalesOft      | CREDIT
; 4  |        Written by John C Dale          | CREDIT
; 5  |Atari V02 port by Ken Jennings, Nov 2018| CREDIT
; 6  |                                        |

; Now:
SCROLLING_CREDIT   ; 40+52+62+61+40 == 255 ; almost a page, how nice.
BLANK_MEM ; Blank text also used for blanks in other places.
	.sb "                                        " ; 40

; The perpetrators identified...
	.sb "    PET FROGGER    (c) November 1983 by Dales" ATASCII_HEART "ft.   " ; 52

	.sb "Original program for CBM PET 4032 written by John C. Dale.    " ; 62

	.sb "Atari 8-bit computer port by Ken Jennings, V03, March 2019" ; 61

END_OF_CREDITS
EXTRA_BLANK_MEM ; Trailing blanks for credit scrolling.
	.sb "                                        " ; 40


	.align $0100  ; Realign to next page.


INSTRUCT_MEM7
; 12 |rivers like this:  <QQQQ]]  Land only on| INSTXT_1
	.sb "rivers like this:  "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_SEATS I_BOAT_LB I_BOAT_LB
	.sb "  Land only on"

INSTRUCT_MEM8
; 13 |the seats in the boats.                 | INSTXT_1
	.sb "the seats in the boats.                 "

SCORING_MEM1 ; Scoring
; 15 |Scoring:                                | INSTXT_2
	.sb "Scoring:                                "

SCORING_MEM2
; 16 |    10 points for each jump forward.    | INSTXT_2
	.sb "    10 points for each jump forward.    "

SCORING_MEM3
; 17 |   500 points for each rescued frog.    | INSTXT_2
	.sb "   500 points for each rescued frog.    "

CONTROLS_MEM1 ; Game Controls
; 19 |Use joystick control to jump forward,   | INSTXT_3
	.sb "Use joystick controller to move         "



	.align $0100  ; Realign to next page.


CONTROLS_MEM2
; 20 |left, and right.                        | INSTXT_3
	.sb "forward, left, and right.               "


; FROG SAVED screen.
; Graphics chars design, SAVED!
; |  |**|**|  |  | *|* |  | *|* | *|* | *|**|**|* | *|**|* |  |  |**|
; | *|* |  |  |  |**|**|  | *|* | *|* | *|* |  |  | *|* |**|  |  |**|
; |  |**|**|  | *|* | *|* | *|* | *|* | *|**|**|  | *|* | *|* |  |**|
; |  |  | *|* | *|* | *|* | *|* | *|* | *|* |  |  | *|* | *|* |  |**|
; |  |  | *|* | *|**|**|* |  |**|**|  | *|* |  |  | *|* |**|  |  |  |
; |  |**|**|  | *|* | *|* |  | *|* |  | *|**|**|* | *|**|* |  |  |**|

; Another benefit of using the bitmap is it makes the data much more obvious. 
FROGSAVE_MEM   ; Graphics data, SAVED!  43 pixels.  40 - 21 == 19 blanks. 43 + 19 = 62.  + 18 = 80
	.by %00000000 %00000000 %00001111 %00000110 %00011001 %10011111 %10011110 %00001100 %00000000 %00000000
	.by %00000000 %00000000 %00011000 %00001111 %00011001 %10011000 %00011011 %00001100 %00000000 %00000000
	.by %00000000 %00000000 %00001111 %00011001 %10011001 %10011111 %00011001 %10001100 %00000000 %00000000
	.by %00000000 %00000000 %00000001 %10011001 %10011001 %10011000 %00011001 %10001100 %00000000 %00000000
	.by %00000000 %00000000 %00000001 %10011111 %10001111 %00011000 %00011011 %00000000 %00000000 %00000000
	.by %00000000 %00000000 %00001111 %00011001 %10000110 %00011111 %10011110 %00001100 %00000000 %00000000




; FROG DEAD screen.
; Graphics chars design, DEAD FROG!
; | *|**|* |  | *|**|**|* |  | *|* |  | *|**|* |  |  |  |  | *|**|**|* | *|**|**|  |  |**|**|  |  |**|**|* |  |**|
; | *|* |**|  | *|* |  |  |  |**|**|  | *|* |**|  |  |  |  | *|* |  |  | *|* | *|* | *|* | *|* | *|* |  |  |  |**|
; | *|* | *|* | *|**|**|  | *|* | *|* | *|* | *|* |  |  |  | *|**|**|  | *|* | *|* | *|* | *|* | *|* |  |  |  |**|
; | *|* | *|* | *|* |  |  | *|* | *|* | *|* | *|* |  |  |  | *|* |  |  | *|**|**|  | *|* | *|* | *|* |**|* |  |**|
; | *|* |**|  | *|* |  |  | *|**|**|* | *|* |**|  |  |  |  | *|* |  |  | *|* |**|  | *|* | *|* | *|* | *|* |  |  |
; | *|**|* |  | *|**|**|* | *|* | *|* | *|**|* |  |  |  |  | *|* |  |  | *|* | *|* |  |**|**|  |  |**|**|* |  |**|

FROGDEAD_MEM   ; Graphics data, DEAD FROG!  (37) + 3 spaces.
	.by %00001111 %00001111 %11000011 %00001111 %00000000 %00111111 %00111110 %00011110 %00011111 %00011000
	.by %00001101 %10001100 %00000111 %10001101 %10000000 %00110000 %00110011 %00110011 %00110000 %00011000
	.by %00001100 %11001111 %10001100 %11001100 %11000000 %00111110 %00110011 %00110011 %00110000 %00011000
	.by %00001100 %11001100 %00001100 %11001100 %11000000 %00110000 %00111110 %00110011 %00110111 %00011000
	.by %00001101 %10001100 %00001111 %11001101 %10000000 %00110000 %00110110 %00110011 %00110011 %00000000
	.by %00001111 %00001111 %11001100 %11001111 %00000000 %00110000 %00110011 %00011110 %00011111 %00011000


; GAME OVER screen.
; Graphics chars design, GAME OVER
; |  |**|**|* |  | *|* |  |**|  | *|* |**|**|**|  |  |  |  |**|**|  | *|* | *|* | *|**|**|* | *|**|**|  |
; | *|* |  |  |  |**|**|  |**|* |**|* |**|  |  |  |  |  | *|* | *|* | *|* | *|* | *|* |  |  | *|* | *|* |
; | *|* |  |  | *|* | *|* |**|**|**|* |**|**|* |  |  |  | *|* | *|* | *|* | *|* | *|**|**|  | *|* | *|* |
; | *|* |**|* | *|* | *|* |**| *| *|* |**|  |  |  |  |  | *|* | *|* | *|* | *|* | *|* |  |  | *|**|**|  |
; | *|* | *|* | *|**|**|* |**|  | *|* |**|  |  |  |  |  | *|* | *|* |  |**|**|  | *|* |  |  | *|* |**|  |
; |  |**|**|* | *|* | *|* |**|  | *|* |**|**|**|  |  |  |  |**|**|  |  | *|* |  | *|**|**|* | *|* | *|* |

GAMEOVER_MEM ; Graphics data, Game Over.  (34) + 6 spaces.
	.by %00000000 %11111000 %01100011 %00011011 %11110000 %00001111 %00011001 %10011111 %10011111 %00000000
	.by %00000001 %10000000 %11110011 %10111011 %00000000 %00011001 %10011001 %10011000 %00011001 %10000000
	.by %00000001 %10000001 %10011011 %11111011 %11100000 %00011001 %10011001 %10011111 %00011001 %10000000
	.by %00000001 %10111001 %10011011 %01011011 %00000000 %00011001 %10011001 %10011000 %00011111 %00000000
	.by %00000001 %10011001 %11111011 %00011011 %00000000 %00011001 %10001111 %00011000 %00011011 %00000000
	.by %00000000 %11111001 %10011011 %00011011 %11110000 %00001111 %00000110 %00011111 %10011001 %10000000


	.align $0100 ; Realign to next page.


PLAYFIELD_MEM0 ; Default display of "Beach", for lack of any other description, and the two lines of Boats
; 3  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_1
	.sb "         "
	.by I_BEACH1
	.sb "      "
	.by I_BEACH2
	.sb "              "
	.by I_BEACH3
	.sb "        " ; "Beach"

PLAYFIELD_MEM3 ; Default display of "Beach", for lack of any other description, and the two lines of Boats
; 6  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_2
	.sb "      "
	.by I_BEACH3
	.sb "    "
	.by I_BEACH1
	.sb "                "
	.by I_BEACH3
	.sb "           " ; "Beach"

PLAYFIELD_MEM6 ; Default display of "Beach", for lack of any other description, and the two lines of Boats
; 9  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_3
	.sb "     "
	.by I_BEACH2
	.sb "       "
	.by I_BEACH3
	.sb "              "
	.by I_BEACH1
	.sb "           " ; "Beach"

PLAYFIELD_MEM9 ; Default display of "Beach", for lack of any other description, and the two lines of Boats
; 12  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_4
	.sb "          "
	.by I_BEACH1
	.sb "         "
	.by I_BEACH3
	.sb "           "
	.by I_BEACH2
	.sb "       " ; "Beach"

PLAYFIELD_MEM12 ; Default display of "Beach", for lack of any other description, and the two lines of Boats
; 15  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_5
	.sb "       "
	.by I_BEACH2
	.sb "      "
	.by I_BEACH2
	.sb "              "
	.by I_BEACH1
	.sb "          " ; "Beach"

PLAYFIELD_MEM15 ; Default display of "Beach", for lack of any other description, and the two lines of Boats
; 18  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_6
	.sb "           "
	.by I_BEACH1
	.sb "         "
	.by I_BEACH2
	.sb "          "
	.by I_BEACH3
	.sb "       " ; "Beach"


	.align $0100 ; Realign to next page.


PLAYFIELD_MEM18 ; One last line of Beach
; 21  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT2
	.sb "        "
	.by I_BEACH3
	.sb "        "
	.by I_BEACH1
	.sb "                 "
	.by I_BEACH1
	.sb "    " ; "Beach"

; Two lines for Scores, lives, and frogs saved.

SCORE_MEM1 ; Labels for crossings counter, scores, and lives
; 1  |Score:00000000               00000000:Hi| SCORE_TXT
	.by I_BS I_SC I_SO I_SR I_SE I_CO
SCREEN_MYSCORE
	.sb "00000000               "
SCREEN_HISCORE
	.sb "00000000"
	.by I_CO I_BH I_SI

SCORE_MEM2
; 2  |Frogs:0    Frogs Saved:OOOOOOOOOOOOOOOOO| SCORE_TXT
	.by I_BF I_SR I_SO I_SG I_SS I_CO
SCREEN_LIVES
	.sb"0    "
	.by I_BF I_SR I_SO I_SG I_SS $00 I_BS I_BA I_SV I_SE I_SD I_CO
SCREEN_SAVED
	.sb "                 "


	.align $0100 ; Realign to next page.

; ==========================================================================
; Color Layouts for the screens.
; 23 lines of data each, not 25.
; Line 24 for the Press A Button Prompt and 
; line 25 for the scrolling credits are managed directly, by
; the VBI, so they do not need entries in the tables.
; --------------------------------------------------------------------------
; FYI from GTIA.asm:
; COLOR_ORANGE1 =      $10
; COLOR_ORANGE2 =      $20
; COLOR_RED_ORANGE =   $30
; COLOR_PINK =         $40
; COLOR_PURPLE =       $50
; COLOR_PURPLE_BLUE =  $60
; COLOR_BLUE1 =        $70
; COLOR_BLUE2 =        $80
; COLOR_LITE_BLUE =    $90
; COLOR_AQUA =         $A0
; COLOR_BLUE_GREEN =   $B0
; COLOR_GREEN =        $C0
; COLOR_YELLOW_GREEN = $D0
; COLOR_ORANGE_GREEN = $E0
; COLOR_LITE_ORANGE =  $F0

TITLE_BACK_COLORS
	.by COLOR_BLACK        COLOR_BLACK              ; Scores, and blank line
	.by COLOR_BLUE1        COLOR_PURPLE_BLUE+2      ; Title lines
	.by COLOR_PURPLE+4     COLOR_PINK+6             ; Title lines
	.by COLOR_RED_ORANGE+8 COLOR_ORANGE2+10         ; Title lines
	.by COLOR_ORANGE1+12                            ; Title lines
	.by COLOR_BLACK                                 ; Space
	.by COLOR_AQUA COLOR_AQUA COLOR_AQUA COLOR_AQUA ; Instructions
	.by COLOR_AQUA COLOR_AQUA COLOR_AQUA COLOR_AQUA ; Instructions
	.by COLOR_BLACK                                 ; Space
	.by COLOR_ORANGE2 COLOR_ORANGE2 COLOR_ORANGE2   ; Scoring
	.by COLOR_BLACK                                 ; Space
	.by COLOR_PINK COLOR_PINK                       ; Controls

TITLE_TEXT_COLORS ; Text luminance
	.by $0C $0C                                     ; Scores, and blank line
	.by COLOR_ORANGE_GREEN+$0C $DA $C8 $B6 $A4 $92 $C2                 ; title
	.by $00                                         ; blank
	.by $04 $06 $08 $0A                             ; Instructions
	.by $0C $0A $08 $06                             ; Instructions
	.by $00                                         ; blank
	.by $06 $08 $0a                                 ; Scoring
	.by $00                                         ; blank
	.by $08 $0A                                     ; controls


GAME_BACK_COLORS
	.by COLOR_BLACK COLOR_BLACK                            ; Scores, lives, saved frogs.
	.by COLOR_GREEN                                        ; Grassy gap

	.by COLOR_ORANGE2+2    COLOR_AQUA      COLOR_AQUA+4      ; Beach, boats, boats.
	.by COLOR_RED_ORANGE+2 COLOR_BLUE1     COLOR_BLUE1+4     ; Beach, boats, boats.
	.by COLOR_ORANGE2+2    COLOR_BLUE2     COLOR_BLUE2+4     ; Beach, boats, boats.
	.by COLOR_RED_ORANGE+2 COLOR_LITE_BLUE COLOR_LITE_BLUE+4 ; Beach, boats, boats.
	.by COLOR_ORANGE2+2    COLOR_BLUE1     COLOR_BLUE1+4     ; Beach, boats, boats.
	.by COLOR_RED_ORANGE+2 COLOR_AQUA      COLOR_AQUA+4      ; Beach, boats, boats.
	.by COLOR_ORANGE2+2                                      ; one last Beach.

	.by COLOR_GREEN                                        ; grassy gap

GAME_TEXT_COLORS ; Text luminance
	.rept 23
		.by $0C                                     ; The rest of the text on screen
	.endr


DEAD_BACK_COLORS ; Text luminance
	.by COLOR_RED_ORANGE+7  COLOR_RED_ORANGE+9  COLOR_RED_ORANGE+11 COLOR_RED_ORANGE+13
	.by COLOR_RED_ORANGE+14 COLOR_RED_ORANGE+14 COLOR_RED_ORANGE+14 COLOR_RED_ORANGE+13
	.by COLOR_RED_ORANGE+11

	.by COLOR_BLACK COLOR_PINK COLOR_PINK COLOR_PINK COLOR_BLACK

	.by COLOR_RED_ORANGE+9 COLOR_RED_ORANGE+7 COLOR_RED_ORANGE+5
	.by COLOR_RED_ORANGE+3 COLOR_RED_ORANGE+1 COLOR_RED_ORANGE+0 COLOR_RED_ORANGE+0
	.by COLOR_RED_ORANGE+0 COLOR_RED_ORANGE+1

DEAD_TEXT_COLORS ; Text luminance
	.rept 10
		.by $00                                     ; Top Scroll.
	.endr

	.by $0A $08 $06

	.rept 10
		.by $00                                     ; Bottom Scroll, and Prompt.
	.endr


WIN_BACK_COLORS                                     ; The Win Screen will populate scrolling colors.
	.rept 23
		.by $00                                     ; The whole screen is black.
	.endr

WIN_TEXT_COLORS
	.rept 10
		.by $00                                     ; Top Scroll.
	.endr

	.by $0A $08 $06                                 ; SAVED!

	.rept 10
		.by $00                                     ; Bottom Scroll
	.endr


OVER_BACK_COLORS
	.rept 10
		.by $00                                     ; Top scroll
	.endr

	.by  COLOR_PINK COLOR_PINK COLOR_PINK 

	.rept 10
		.by $00                                     ; Bottom scroll
	.endr

OVER_TEXT_COLORS
	.rept 10
		.by $00                                     ; Top Scroll.
	.endr

	.by $0A $08 $06

	.rept 10
		.by $00                                     ; Bottom Scroll
	.endr


	.align $0100 ; Realign to next page.


; ==========================================================================
; Tables listing pointers to all the assets.
; --------------------------------------------------------------------------

; All Display lists fit in one page, so only only byte update is needed.
DISPLAYLIST_LO_TABLE  
	.byte <TITLE_DISPLAYLIST
	.byte <GAME_DISPLAYLIST
	.byte <FROGSAVED_DISPLAYLIST
	.byte <FROGDEAD_DISPLAYLIST
	.byte <GAMEOVER_DISPLAYLIST

DISPLAYLIST_HI_TABLE
	.byte >TITLE_DISPLAYLIST
	.byte >GAME_DISPLAYLIST
	.byte >FROGSAVED_DISPLAYLIST
	.byte >FROGDEAD_DISPLAYLIST
	.byte >GAMEOVER_DISPLAYLIST

DISPLAYLIST_GFXLMS_TABLE
	.byte $00, $00  ; no gfx pointer for title and game screen.
	.byte <FROGSAVE_MEM
	.byte <FROGDEAD_MEM
	.byte <GAMEOVER_MEM

DLI_LO_TABLE  ; Address of first chained DLI per each screen.
	.byte <TITLE_DLI_CHAIN_TABLE ; DLI (0) -- Set colors for Scores.
	.byte <GAME_DLI_CHAIN_TABLE
	.byte <SPLASH_DLI_CHAIN_TABLE ; FROGSAVED_DLI
	.byte <SPLASH_DLI_CHAIN_TABLE ; FROGDEAD_DLI
	.byte <SPLASH_DLI_CHAIN_TABLE ; GAMEOVER_DLI

DLI_HI_TABLE
	.byte >TITLE_DLI_CHAIN_TABLE ; DLI sets COLPF1, COLPF2, COLBK for score text. 
	.byte >GAME_DLI_CHAIN_TABLE  ; DLI sets COLPF1, COLPF2, COLBK for score text. 
	.byte >SPLASH_DLI_CHAIN_TABLE ; FROGSAVED_DLI
	.byte >SPLASH_DLI_CHAIN_TABLE ; FROGDEAD_DLI
	.byte >SPLASH_DLI_CHAIN_TABLE ; GAMEOVER_DLI


TITLE_DLI_CHAIN_TABLE ; Low byte update to next DLI from the title display
	.byte <Score_DLI        ; DLI (0) Text - COLPF1, Black - COLBK COLPF2
	.byte <COLPF0_COLBK_DLI ; DLI (1) Table - COLBK, Pixels - COLPF0
	.byte <COLPF0_COLBK_DLI ; DLI 2   Table - COLBK, Pixels - COLPF0
	.byte <COLPF0_COLBK_DLI ; DLI 3   Table - COLBK, Pixels - COLPF0
	.byte <COLPF0_COLBK_DLI ; DLI 4   Table - COLBK, Pixels - COLPF0
	.byte <COLPF0_COLBK_DLI ; DLI 5   Table - COLBK, Pixels - COLPF0
	.byte <COLPF0_COLBK_DLI ; DLI 6   Table - COLBK, Pixels - COLPF0
	.byte <COLPF0_COLBK_DLI ; DLI 7   Table - COLBK, Pixels - COLPF0
	.byte <TITLE_DLI_3      ; DLI 8   Black - COLBK COLPF2
	.byte <TITLE_DLI_4      ; DLI 9   Text - COLPF1, Table - COLBK COLPF2. - start instructions
	.byte <TITLE_DLI_5      ; DLI 10  Text - COLPF1
	.byte <TITLE_DLI_5      ; DLI 11  Text - COLPF1
	.byte <TITLE_DLI_5      ; DLI 12  Text - COLPF1
	.byte <TITLE_DLI_5      ; DLI 13  Text - COLPF1
	.byte <TITLE_DLI_5      ; DLI 14  Text - COLPF1
	.byte <TITLE_DLI_5      ; DLI 15  Text - COLPF1
	.byte <TITLE_DLI_5      ; DLI 16  Text - COLPF1 - end instructions.
	.byte <TITLE_DLI_3      ; DLI 17  Black - COLBK COLPF2
	.byte <TITLE_DLI_4      ; DLI 18  Text - COLPF1, Table - COLBK COLPF2. - start scoring
	.byte <TITLE_DLI_5      ; DLI 19  Text - COLPF1
	.byte <TITLE_DLI_5      ; DLI 20  Text - COLPF1 - end scoring
	.byte <TITLE_DLI_3      ; DLI 21  Black - COLBK COLPF2
	.byte <TITLE_DLI_4      ; DLI 22  Text - COLPF1, Table - COLBK COLPF2. - start controls
	.byte <TITLE_DLI_5      ; DLI 23  Text - COLPF1 - end controls
	.byte <TITLE_DLI_3      ; DLI 24  Black - COLBK COLPF2
	.byte <DLI_SPC1         ; DLI 25 Special DLI for Press Button Prompt will go to the next DLI for Scrolling text.	
;	.byte <TITLE_DLI_SPC2   ; DLI 26 


GAME_DLI_CHAIN_TABLE ; Low byte update to next DLI from the title display
	.byte <Score_DLI   ; DLI (0) for scores
	.byte <GAME_DLI_1  ; DLI (1) Text - COLPF1, for scores  (Same as TITLE_DLI_5)
	.byte <GAME_DLI_2  ; DLI 2   Beach 18 - COLBK,         COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (N/A).
	.byte <GAME_DLI_3  ; DLI 3   Boats 17 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (N/A)
	.byte <GAME_DLI_3  ; DLI 4   Boats 16 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 17)
	.byte <GAME_DLI_2  ; DLI 5   Beach 15 - COLBK,         COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 16).
	.byte <GAME_DLI_3  ; DLI 6   Boats 14 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (N/A)
	.byte <GAME_DLI_3  ; DLI 7   Boats 13 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 14)
	.byte <GAME_DLI_2  ; DLI 8   Beach 12 - COLBK,         COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 13).
	.byte <GAME_DLI_3  ; DLI 9   Boats 11 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (N/A)
	.byte <GAME_DLI_3  ; DLI 10  Boats 10 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 11)
	.byte <GAME_DLI_2  ; DLI 11  Beach 09 - COLBK,         COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 10).
	.byte <GAME_DLI_3  ; DLI 12  Boats 08 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (N/A)
	.byte <GAME_DLI_3  ; DLI 13  Boats 07 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 8)
	.byte <GAME_DLI_2  ; DLI 14  Beach 06 - COLBK,         COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 7).
	.byte <GAME_DLI_3  ; DLI 15  Boats 05 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (N/A)
	.byte <GAME_DLI_3  ; DLI 16  Boats 04 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 5)
	.byte <GAME_DLI_2  ; DLI 17  Beach 03 - COLBK,         COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 4).
	.byte <GAME_DLI_3  ; DLI 18  Boats 02 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (N/A)
	.byte <GAME_DLI_3  ; DLI 19  Boats 01 - COLBK, HSCROL, COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 2)
	.byte <GAME_DLI_2  ; DLI 20  Beach 00 - COLBK,         COLPF0, COLPF1, COLPF2, COLPF3, get PXPF collisions (for 1).
	.byte <TITLE_DLI_3 ; DLI 21  Black - COLBK COLPF2
	.byte <GAME_DLI_5  ; DLI 22  Calls SPC2 to set scrolling credits HSCROL and colors.


; All three graphics screens use the same list.
; Basically, the background color is updated per every line
SPLASH_DLI_CHAIN_TABLE ; Low byte update to next DLI from the title display
	.byte <COLPF0_COLBK_DLI ; DLI (0)  1
	.byte <COLPF0_COLBK_DLI ; DLI (1)  2
	.byte <COLPF0_COLBK_DLI ; DLI (2)  3
	.byte <COLPF0_COLBK_DLI ; DLI (3)  4
	.byte <COLPF0_COLBK_DLI ; DLI (4)  5
	.byte <COLPF0_COLBK_DLI ; DLI (5)  6
	.byte <COLPF0_COLBK_DLI ; DLI (6)  7
	.byte <COLPF0_COLBK_DLI ; DLI (7)  8
	.byte <COLPF0_COLBK_DLI ; DLI (8)  9
	.byte <COLPF0_COLBK_DLI ; DLI (9)  10
	.byte <COLPF0_COLBK_DLI ; DLI (10) 11
	.byte <COLPF0_COLBK_DLI ; DLI (11) 12
	.byte <COLPF0_COLBK_DLI ; DLI (12) 13
	.byte <COLPF0_COLBK_DLI ; DLI (13) 14
	.byte <COLPF0_COLBK_DLI ; DLI (14) 15
	.byte <COLPF0_COLBK_DLI ; DLI (15) 16
	.byte <COLPF0_COLBK_DLI ; DLI (16) 17
	.byte <COLPF0_COLBK_DLI ; DLI (17) 18
	.byte <COLPF0_COLBK_DLI ; DLI (18) 19
	.byte <COLPF0_COLBK_DLI ; DLI (19) 20
	.byte <COLPF0_COLBK_DLI ; DLI (20) 1 Splash Graphics
	.byte <COLPF0_COLBK_DLI ; DLI (21) 2 Splash Graphics
	.byte <COLPF0_COLBK_DLI ; DLI (22) 3 Splash Graphics
	.byte <COLPF0_COLBK_DLI ; DLI (23) 4 Splash Graphics
	.byte <COLPF0_COLBK_DLI ; DLI (24) 5 Splash Graphics
	.byte <COLPF0_COLBK_DLI ; DLI (25) 6 Splash Graphics
	.byte <COLPF0_COLBK_DLI ; DLI (26) 20 
	.byte <COLPF0_COLBK_DLI ; DLI (27) 19 
	.byte <COLPF0_COLBK_DLI ; DLI (28) 18 
	.byte <COLPF0_COLBK_DLI ; DLI (29) 17 
	.byte <COLPF0_COLBK_DLI ; DLI (30) 16 
	.byte <COLPF0_COLBK_DLI ; DLI (31) 15 
	.byte <COLPF0_COLBK_DLI ; DLI (32) 14
	.byte <COLPF0_COLBK_DLI ; DLI (33) 13
	.byte <COLPF0_COLBK_DLI ; DLI (34) 12
	.byte <COLPF0_COLBK_DLI ; DLI (35) 11
	.byte <COLPF0_COLBK_DLI ; DLI (36) 10
	.byte <COLPF0_COLBK_DLI ; DLI (37) 9
	.byte <COLPF0_COLBK_DLI ; DLI (38) 8
	.byte <COLPF0_COLBK_DLI ; DLI (39) 7
	.byte <COLPF0_COLBK_DLI ; DLI (40) 6
	.byte <COLPF0_COLBK_DLI ; DLI (41) 5
	.byte <COLPF0_COLBK_DLI ; DLI (42) 4
	.byte <COLPF0_COLBK_DLI ; DLI (43) 3
	.byte <COLPF0_COLBK_DLI ; DLI (44) 2
	.byte <COLPF0_COLBK_DLI ; DLI (45) 1
	.byte <DLI_SPC1    ; DLI 44 - Special DLI for Press Button Prompt will go to the next DLI for Scrolling text.
;	.byte <GAME_DLI_SPC2    ; DLI 45 

; C0olor tables must be big enough to contain data up to the maximum index that
; occurs of all the screens. 

COLBK_TABLE ; Must be big enough to do splash screens.
	.ds 46

COLPF0_TABLE ; Must be big enough to do splash screens.
	.ds 46

COLPF1_TABLE ; Must be big enough to do Title screen.
	.ds 25

COLPF2_TABLE ; Must be big enough to do Title screen.
	.ds 25

COLPF3_TABLE ; Must be big enough to do Game  screen up to last boat row.
	.ds 22

HSCROL_TABLE ; Must be big enough to do Game screen up to  last boat row.
	.ds 22

PXPF_TABLE ; Big enough for game area for Frog.
	.ds 22

COLOR_BACK_LO_TABLE
	.byte <TITLE_BACK_COLORS
	.byte <GAME_BACK_COLORS
	.byte <WIN_BACK_COLORS
	.byte <DEAD_BACK_COLORS
	.byte <OVER_BACK_COLORS

COLOR_BACK_HI_TABLE
	.byte >TITLE_BACK_COLORS
	.byte >GAME_BACK_COLORS
	.byte >WIN_BACK_COLORS
	.byte >DEAD_BACK_COLORS
	.byte >OVER_BACK_COLORS

COLOR_TEXT_LO_TABLE
	.byte <TITLE_TEXT_COLORS
	.byte <GAME_TEXT_COLORS
	.byte <WIN_TEXT_COLORS
	.byte <DEAD_TEXT_COLORS
	.byte <OVER_TEXT_COLORS

COLOR_TEXT_HI_TABLE
	.byte >TITLE_TEXT_COLORS
	.byte >GAME_TEXT_COLORS
	.byte >WIN_TEXT_COLORS
	.byte >DEAD_TEXT_COLORS
	.byte >OVER_TEXT_COLORS

; ==========================================================================
; A list of the game playfield screen memory locations.  Note this is
; only the part of the game screen that presents the beaches and boats.
; It does not include anything else before or after the playfield.
; --------------------------------------------------------------------------
; Not needed due to Frog being done as Player/Missile.

; PLAYFIELD_MEM_LO_TABLE
	; .byte <PLAYFIELD_MEM0
	; .byte <PLAYFIELD_MEM1
	; .byte <PLAYFIELD_MEM2
	; .byte <PLAYFIELD_MEM3
	; .byte <PLAYFIELD_MEM4
	; .byte <PLAYFIELD_MEM5
	; .byte <PLAYFIELD_MEM6
	; .byte <PLAYFIELD_MEM7
	; .byte <PLAYFIELD_MEM8
	; .byte <PLAYFIELD_MEM9
	; .byte <PLAYFIELD_MEM10
	; .byte <PLAYFIELD_MEM11
	; .byte <PLAYFIELD_MEM12
	; .byte <PLAYFIELD_MEM13
	; .byte <PLAYFIELD_MEM14
	; .byte <PLAYFIELD_MEM15
	; .byte <PLAYFIELD_MEM16
	; .byte <PLAYFIELD_MEM17
	; .byte <PLAYFIELD_MEM18

; PLAYFIELD_MEM_HI_TABLE
	; .byte >PLAYFIELD_MEM0
	; .byte >PLAYFIELD_MEM1
	; .byte >PLAYFIELD_MEM2
	; .byte >PLAYFIELD_MEM3
	; .byte >PLAYFIELD_MEM4
	; .byte >PLAYFIELD_MEM5
	; .byte >PLAYFIELD_MEM6
	; .byte >PLAYFIELD_MEM7
	; .byte >PLAYFIELD_MEM8
	; .byte >PLAYFIELD_MEM9
	; .byte >PLAYFIELD_MEM10
	; .byte >PLAYFIELD_MEM11
	; .byte >PLAYFIELD_MEM12
	; .byte >PLAYFIELD_MEM13
	; .byte >PLAYFIELD_MEM14
	; .byte >PLAYFIELD_MEM15
	; .byte >PLAYFIELD_MEM16
	; .byte >PLAYFIELD_MEM17
	; .byte >PLAYFIELD_MEM18

	
; ==========================================================================
; PLAYER/MISSILE GRAPHICS
; only the part of the game screen that presents the beaches and boats.
; It does not include anything else before or after the playfield.
; --------------------------------------------------------------------------

	.align $0800 ; single line P/M needs 2K boundary.

PMADR

MISSILEADR = PMADR+$300
PLAYERADR0 = PMADR+$400
PLAYERADR1 = PMADR+$500
PLAYERADR2 = PMADR+$600
PLAYERADR3 = PMADR+$700

