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
; Version 02, January 2019
;
; --------------------------------------------------------------------------

; ==========================================================================
; Screen Memory
;
; The custom Display lists make the Atari impersonate the PET 4032's
; 40-column, 25 line display.  Each Display List averages about 81 bytes,
; so three can fit in the same page.
;
; The Atari OS text printing is not being used, therefore the Atari screen
; editor's 24-line limitation is not an issue.
;
; Where a display expects completely static, blank, black lines a
; display list would use real, blank line instructions.  However, the
; ANTIC mode 2 text uses color differently from other text modes.
; The "background" behind text uses COLPF2 and COLPF4 for the border.
; Other modes use COLPF4 as true background through the border and
; empty background behind text.  Therefore where the program expects
; to use color in the background behind text, it uses a text instruction
; pointing to an empty line of blank spaces, so that COLPF2 can be used
; to show color within the same horizontal limits as the other text
; in the screen. This makes it easy to "animate" with color changes to
; the text background.
;
; Remember, screen memory need not be contiguous from line to line.
; Therefore, we can re-think the declaration of screen contents and
; rearrange it in ways to benefit the code:
;
; 1) The first thing is that data declared for display on screen IS the
;    screen memory.  It is not something that must be copied to screen
;    memory.  Data properly placed in any memory makes it the actual
;    screen memory thanks to the Display List LMS instructions.
; 2) All the scrolling boats lines can be put at the beginning of pages
;    to simplify the math for the LMS address. Only the low byte of the
;    LMS need be updated to perform scrolling.  But, this would be pretty
;    wasteful using only 80 bytes of a 256 byte page.  What to do?
; 3) To avoid wasting space the lines of data from other displays can be
;    dropped into the unused spaces between scrolling sections.
; --------------------------------------------------------------------------

ATASCII_HEART  = $00 ; heart graphics
ATASCII_HLINE  = $12 ; horizontal line, ctrl-r (title underline)
ATASCII_BALL   = $14 ; ball graphics, ctrl-t

ATASCII_ASTER  = $2A ; Character for '*' splattered frog.
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

; Graphics chars shorthanded due to frequency in the code....
; These characters "draw" the huge text on the screens for
; the title, Dead Frog, Saved, and Game Over messages.

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


SIZEOF_LINE    = 39  ; That is, 40 - 1
SIZEOF_BIG_GFX = 119 ; That is, 120 - 1



; Revised V02 Title Screen and Instructions:
;    +----------------------------------------+
; 1  |              PET FROGGER               | TITLE
; 2  |              PET FROGGER               | TITLE
; 3  |              PET FROGGER               | TITLE
; 4  |              --- -------               | TITLE
; 5  |                                        |
; 6  |Help the frogs escape from Doc Hopper's | INSTXT_1
; 7  |frog legs fast food franchise! But, the | INSTXT_1
; 8  |frogs must cross piranha-infested rivers| INSTXT_1
; 9  |to reach freedom. You have three chances| INSTXT_1
; 10 |to prove your frog management skills by | INSTXT_1
; 11 |directing frogs to jump on boats in the | INSTXT_1
; 12 |rivers like this:  <QQQQ]  Land only on | INSTXT_1
; 13 |the seats in the boats ('Q').           | INSTXT_1
; 14 |                                        |
; 15 |Scoring:                                | INSTXT_2
; 16 |    10 points for each jump forward.    | INSTXT_2
; 17 |   500 points for each rescued frog.    | INSTXT_2
; 18 |                                        |
; 19 |Use joystick control to jump forward,   | INSTXT_3
; 20 |left, and right.                        | INSTXT_3
; 21 |                                        |
; 22 |                                        |
; 23 |                                        |
; 24 |   Press joystick button to continue.   | ANYBUTTON_MEM
; 25 |(c) November 1983 by DalesOft  Written b| SCROLLING CREDIT
;    +----------------------------------------+


; Revised V02 Main Game Play Screen:
;    +----------------------------------------+
; 1  |Score:00000000               00000000:Hi| SCORE_TXT
; 2  |Frogs:0    Frogs Saved:OOOOOOOOOOOOOOOOO| SCORE_TXT
; 3  |                                        | <-Grassy color
; 4  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_1
; 5  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_1
; 6  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_1
; 7  |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_2
; 8  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_2
; 9  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_2
; 10 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_3
; 11 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_3
; 12 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_3
; 13 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_4
; 14 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_4
; 15 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_4
; 16 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_5
; 17 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_5
; 18 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_5
; 19 |BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB| TEXT1_6
; 20 | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_6
; 21 |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_6
; 22 |BBBBBBBBBBBBBBBBBBBOBBBBBBBBBBBBBBBBBBBB| TEXT2
; 23 |                                        | <-Grassy color
; 24 |                                        |
; 25 |(c) November 1983 by DalesOft  Written b| SCROLLING CREDIT
;    +----------------------------------------+



; ANTIC's has a 4K boundary for screen memory.
; But, we can simply align each set of lines into pages and that
; will prevent any line of screen data from crossing over a
; 4K boundary.

	.align $0100
; The declarations below are arranged to make sure
; each line of data fits within 256 byte pages.

; Remember, lines of screen data need not be contiguous to
; each other since LMS for each line tells where to start
; reading screen memory.  Therefore we can declare lines in
; any order....

; First the Credit text.  Rather than three lines on the main
; and game screen let's make this a continuously scrolling
; line of text on all screens.  This requires two more blocks
; of blank text to space out the start and end of the text.

; Formerly:
; 3  |     (c) November 1983 by DalesOft      | CREDIT
; 4  |        Written by John C Dale          | CREDIT
; 5  |Atari V02 port by Ken Jennings, Jan 2019| CREDIT
; 6  |                                        |

; Now:
SCROLLING_CREDIT   ; 40+47+61+56+40 == 244;
BLANK_MEM ; Blank text also used a blank in many other places.
	.sb "                                        " ; 40

CREDIT_MEM1 ; The perpetrators identified...
	.sb "PET FROGGER   (c) November 1983 by Dales" ATASCII_HEART "ft.   " ; 47

CREDIT_MEM2
	.sb "Original program for CBM PET 4032 written by John C. Dale.   " ; 61

CREDIT_MEM3
	.sb "Atari 8-bit computer port by Ken Jennings, V02, Jan 2019" ; 56

END_OF_CREDITS
EXTRA_BLANK_MEM ; Trailing line for credit scrolling.
	.sb "                                        " ; 40

; Six lines times 40 characters is 240 bytes of data.



	.align $0100  ; Realign to next page.

; Graphics chars design, PET FROGGER
; |**|**|* |  |**|**|**|  |**|**|**|  |  |**|**|**|  |**|**|* |  | *|**|* |  | *|**|**|  | *|**|**|  |**|**|**|  |**|**|* |
; |**|  |**|  |**|  |  |  |  |**|  |  |  |**|  |  |  |**|  |**|  |**|  |**|  |**|  |  |  |**|  |  |  |**|  |  |  |**|  |**|
; |**|  |**|  |**|**|* |  |  |**|  |  |  |**|**|* |  |**|  |**|  |**|  |**|  |**|  |  |  |**|  |  |  |**|**|* |  |**|  |**|
; |**|**|* |  |**|  |  |  |  |**|  |  |  |**|  |  |  |**|**|* |  |**|  |**|  |**| *|**|  |**| *|**|  |**|  |  |  |**|**|* |
; |**|  |  |  |**|  |  |  |  |**|  |  |  |**|  |  |  |**| *|* |  |**|  |**|  |**|  |**|  |**|  |**|  |**|  |  |  |**| *|* |
; |**|  |  |  |**|**|**|  |  |**|  |  |  |**|  |  |  |**|  |**|  | *|**|* |  | *|**|**|  | *|**|**|  |**|**|**|  |**|  |**|

; Graphics chars, PET FROGGER
; |i |iU|iK|  |i |iU|iU|  |iU|i |iU|  |  |i |iU|iU|  |i |iU|iK|  |iL|iU|iK|  |iL|iU|iU|  |iL|iU|iU|  |i |iU|iU|  |i |iU|iK|
; |i |U |iI|  |i |iU|L |  |  |i |  |  |  |i |iU|L |  |i |U |iI|  |i |  |i |  |i |I |U |  |i |I |U |  |i |iU|L |  |i |U |iI|
; |i |  |  |  |i |U |U |  |  |i |  |  |  |i |  |  |  |i |K |iK|  |iO|U |iO|  |iO|U |i |  |iO|U |i |  |i |U |U |  |i |K |iK|

; Graphics data, DEAD FROG!  (40).  To make this scroll will need some leading spaces.

TITLE_MEM1 ; Title text.
	.sb "                                        " ; Leading blanks  for  scrolling.
	.by I_iS I_iU I_iK I_S I_iS I_iU I_iU I_S I_iU I_iS I_iU I_S I_S I_iS I_iU I_iU I_S I_iS I_iU I_iK I_S I_iL I_iU I_iK I_S I_iL I_iU I_iU I_S I_iL I_iU I_iU I_S I_iS I_iU I_iU I_S I_iS I_iU I_iK
TITLE_MEM2
	.sb "                                        "  ; Leading blanks  for  scrolling.
	.by I_iS I_U  I_iI I_S I_iS I_iU I_L  I_S I_S  I_iS I_S  I_S I_S I_iS I_iU I_L  I_S I_iS I_U  I_iI I_S I_iS I_S  I_iS I_S I_iS I_iS I_U  I_S I_iS I_iS I_U  I_S I_iS I_iU I_L  I_S I_iS I_U  I_iI
TITLE_MEM3
	.sb "                                        "  ; Leading blanks  for  scrolling.
	.by I_iS I_S  I_S  I_S I_iS I_U  I_U  I_S I_S  I_iS I_S  I_S I_S I_iS I_S  I_S  I_S I_iS I_K  I_iK I_S I_iO I_U  I_iO I_S I_iO I_U  I_iS I_S I_iO I_U  I_iS I_S I_iS I_U  I_U  I_S I_iS I_K  I_iK



; Playfield groups II
; Remember the part about screen memory not needing to be contiguous?
; Here we do another weird thing with screen memory.  Declaring each
; boat row at specific places relative to page alignments makes the
; low byte of each screen memory address location the same value for
; each row.  This means the math for the LMS is the same for each row.

; All the moving rows of boats start at low byte $00/0 (dec)
; Other lines of data start after to fill in the page.

	.align $0100

PLAYFIELD_MEM1
; 4  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_1 ; Boats Right
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "

TITLE_MEM4
; 4  |--- --- ---  --- --- --- --- --- --- ---| TITLE
	.sb A_H A_H A_H " " A_H A_H A_H " " A_H A_H A_H "  "
	.sb A_H A_H A_H " " A_H A_H A_H " " A_H A_H A_H " " A_H A_H A_H " "
	.sb A_H A_H A_H " " A_H A_H A_H " " A_H A_H A_H " "

INSTRUCT_MEM1 ; Basic instructions...
; 6  |Help the frogs escape from Doc Hopper's | INSTXT_1
	.sb "Help the frogs escape from Doc Hopper's "

INSTRUCT_MEM2
; 7  |frog legs fast food franchise! But, the | INSTXT_1
	.sb "frog legs fast food franchise! But, the "

INSTRUCT_MEM3
; 8  |frogs must cross piranha-infested rivers| INSTXT_1
	.sb "frogs must cross piranha-infested rivers"




	.align $0100

PLAYFIELD_MEM2
; 5  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_1 ; Boats Left
	.sb "      "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "          "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "

INSTRUCT_MEM4
; 9  |to reach freedom. You have three chances| INSTXT_1
	.sb "to reach freedom. You have three chances"

INSTRUCT_MEM5
; 10 |to prove your frog management skills by | INSTXT_1
	.sb "to prove your frog management skills by "

INSTRUCT_MEM6
; 11 |directing frogs to jump on boats in the | INSTXT_1
	.sb "directing frogs to jump on boats in the "

INSTRUCT_MEM7
; 12 |rivers like this:  <QQQQ]  Land only on | INSTXT_1
	.sb "rivers like this:  "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "  Land only on  "



	.align $0100

PLAYFIELD_MEM4
; 7  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_2 ; Boats Right
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "

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



	.align $0100

PLAYFIELD_MEM5
; 8  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_2 ; Boats Left
	.sb "      "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "          "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "

CONTROLS_MEM1 ; Game Controls
; 19 |Use joystick control to jump forward,   | INSTXT_3
	.sb "Use joystick control to jump forward,   "

CONTROLS_MEM2
; 20 |left, and right.                        | INSTXT_3
	.sb "left, and right.                        "


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



	.align $0100

PLAYFIELD_MEM7
; 10  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_3 ; Boats Right
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "

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



	.align $0100

PLAYFIELD_MEM8
; 11  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_3 ; Boats Left
	.sb "      "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "          "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "

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
	.by I_BF I_SR I_SO I_SG I_SS $00 I_BS I_BS I_SV I_SE I_SD
SCREEN_SAVED
	.sb "                 "

ANYBUTTON_MEM ; Prompt to start game.
; 24 |   Press joystick button to continue.   | INSTXT_4
	.sb "   Press joystick button to continue.   "



	.align $0100

PLAYFIELD_MEM10
; 13  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_4 ; Boats Right
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "

; FROG SAVED screen., 25 lines:
; 10 blank lines.
; 3 lines of big text.
; 10 blank lines
; Press Any Key Line
; 1 blank line

FROGSAVE_MEM
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
	.by $0 $0 $0 $0 $0 $0 $0 $0 $0 I_I I_II I_IU I_S I_S  I_IL I_IK I_S I_IY I_Y  I_IY I_Y I_IY I_II I_IU I_L I_IY I_II I_IK I_S I_S I_IS $0 $0 $0 $0 $0 $0 $0 $0 $0
	.by $0 $0 $0 $0 $0 $0 $0 $0 $0 I_S I_IU I_IO I_O I_IY I_Y  I_IY I_Y I_IY I_Y  I_IY I_Y I_IY I_II I_IU I_S I_IY I_Y  I_IY I_Y I_S I_IS $0 $0 $0 $0 $0 $0 $0 $0 $0
	.by $0 $0 $0 $0 $0 $0 $0 $0 $0 I_S I_U  I_IL I_L I_IY I_II I_IO I_Y I_S  I_IO I_II I_S I_IY I_IK I_U  I_O I_IY I_IK I_II I_S I_S I_U  $0 $0 $0 $0 $0 $0 $0 $0 $0



	.align $0100

PLAYFIELD_MEM11
; 14  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_4 ; Boats Left
	.sb "      "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "          "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "


; FROG DEAD screen., 25 lines:
; 10 blank lines.
; 3 lines of big text.
; 10 blank lines
; Press Any Key Line
; 1 blank line

FROGDEAD_MEM
; Graphics chars design, DEAD FROG!
; | *|**|* |  | *|**|**|* |  | *|* |  | *|**|* |  |  |  |  | *|**|**|* | *|**|**|  |  |**|**|  |  |**|**|* |  |**|
; | *|* |**|  | *|* |  |  |  |**|**|  | *|* |**|  |  |  |  | *|* |  |  | *|* | *|* | *|* | *|* | *|* |  |  |  |**|
; | *|* | *|* | *|**|**|  | *|* | *|* | *|* | *|* |  |  |  | *|**|**|  | *|* | *|* | *|* | *|* | *|* |  |  |  |**|
; | *|* | *|* | *|* |  |  | *|* | *|* | *|* | *|* |  |  |  | *|* |  |  | *|**|**|  | *|* | *|* | *|* |**|* |  |**|
; | *|* |**|  | *|* |  |  | *|**|**|* | *|* |**|  |  |  |  | *|* |  |  | *|* |**|  | *|* | *|* | *|* | *|* |  |  |
; | *|**|* |  | *|**|**|* | *|* | *|* | *|**|* |  |  |  |  | *|* |  |  | *|* | *|* |  |**|**|  |  |**|**|* |  |**|

; Graphics chars, DEAD FROG!
; |iY|iI|iK|  |iY|iI|iU| L|  |iL|iK|  |iY|iI|iK|  |  |  |  |iY|iI|iU| L|iY|iI|iO| O| I|iI|iO| O| I|iI|iU| L|  |i |
; |iY| Y|iY| Y|iY|iI|iU|  |iY| Y|iY| Y|iY| Y|iY| Y|  |  |  |iY|iI|iU|  |iY|iK|iL| L|iY| Y|iY| Y|iY| Y| U| O|  |i |
; |iY|iK|iI|  |iY|iK| U| O|iY|iI|iO| Y|iY|iK|iI|  |  |  |  |iY| Y|  |  |iY| Y|iO| O| K|iK|iL| L| K|iK|iL|iY|  | U|

; Graphics data, DEAD FROG!  (37) + 3 spaces.
	.by $0 $0 I_IY I_II I_IK I_S I_IY I_II I_IU I_L I_S  I_IL I_IK I_S I_IY I_II I_IK I_S I_S I_S I_S I_IY I_II I_IU I_L I_IY I_II I_IO I_O I_I  I_II I_IO I_O I_I  I_II I_IU I_L I_S I_IS $0
	.by $0 $0 I_IY I_Y  I_IY I_Y I_IY I_II I_IU I_S I_IY I_Y  I_IY I_Y I_IY I_Y  I_IY I_Y I_S I_S I_S I_IY I_II I_IU I_S I_IY I_IK I_IL I_L I_IY I_Y  I_IY I_Y I_IY I_Y  I_U  I_O I_S I_IS $0
	.by $0 $0 I_IY I_IK I_II I_S I_IY I_IK I_U  I_O I_IY I_II I_IO I_Y I_IY I_IK I_II I_S I_S I_S I_S I_IY I_Y  I_S  I_S I_IY I_Y  I_IO I_O I_K  I_IK I_IL I_L I_K  I_IK I_IL I_Y I_S I_U  $0



	.align $0100

PLAYFIELD_MEM13
; 16  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_5 ; Boats Right
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "

; GAME OVER screen., 25 lines:
; 10 blank lines.
; 3 lines of big text.
; 10 blank lines
; Press Any Key Line
; 1 blank line

GAMEOVER_MEM
; Graphics chars design, GAME OVER
; |  |**|**|* |  | *|* |  |**|  | *|* |**|**|**|  |  |  |  |**|**|  | *|* | *|* | *|**|**|* | *|**|**|  |
; | *|* |  |  |  |**|**|  |**|* |**|* |**|  |  |  |  |  | *|* | *|* | *|* | *|* | *|* |  |  | *|* | *|* |
; | *|* |  |  | *|* | *|* |**|**|**|* |**|**|* |  |  |  | *|* | *|* | *|* | *|* | *|**|**|  | *|* | *|* |
; | *|* |**|* | *|* | *|* |**| *| *|* |**|  |  |  |  |  | *|* | *|* | *|* | *|* | *|* |  |  | *|**|**|  |
; | *|* | *|* | *|**|**|* |**|  | *|* |**|  |  |  |  |  | *|* | *|* |  |**|**|  | *|* |  |  | *|* |**|  |
; |  |**|**|* | *|* | *|* |**|  | *|* |**|**|**|  |  |  |  |**|**|  |  | *|* |  | *|**|**|* | *|* | *|* |

; Graphics chars, Game Over.
; | I|iI|iU| L|  |iL|iK|  |iS| O|iL| Y|i |iU|iU|  |  |  | I|iI|iO| O|iY| Y|iY| Y|iY|iI|iU| L|iY|iI|iO| O|
; |iY| Y| U| O|iY| Y|iY| Y|i |iO|iO| Y|i |iU| L|  |  |  |iY| Y|iY| Y|iY| Y|iY| Y|iY|iI|iU|  |iY|iK|iL| L|
; | K|iK|iL| Y|iY|iI|iO| Y|i |  |iY| Y|i | U| U|  |  |  | K|iK|iL| L|  |iO|iI|  |iY| K| U| O|iY| Y|iO| O|

; Graphics data, Game Over.  (34) + 6 spaces.
	.by $0 $0 $0 I_I  I_II I_IU I_L I_S  I_IL I_IK I_S I_IS I_O  I_IL I_Y I_IS I_IU I_IU I_S I_S I_S I_I  I_II I_IO I_O I_IY I_Y  I_IY I_Y I_IY I_II I_IU I_L I_IY I_II I_IO I_O $0 $0 $0
	.by $0 $0 $0 I_IY I_Y  I_U  I_O I_IY I_Y  I_IY I_Y I_IS I_IO I_IO I_Y I_IS I_IU I_L  I_S I_S I_S I_IY I_Y  I_IY I_Y I_IY I_Y  I_IY I_Y I_IY I_II I_IU I_S I_IY I_IK I_IL I_L $0 $0 $0
	.by $0 $0 $0 I_K  I_IK I_IL I_Y I_IY I_II I_IO I_Y I_IS I_S  I_IY I_Y I_IS I_U  I_U  I_S I_S I_S I_K  I_IK I_IL I_L I_S  I_IO I_II I_S I_IY I_IK I_U  I_O I_IY I_Y  I_IO I_O $0 $0 $0



	.align $0100

PLAYFIELD_MEM14
; 17  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_5 ; Boats Left
	.sb "      "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "          "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "


	.align $0100

PLAYFIELD_MEM16
; 19  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_6 ; Boats Right
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "
	.by $00 I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "        "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "       "
	.by I_BOAT_RB I_SEATS I_SEATS I_SEATS I_BOAT_RF
	.sb "      "


	.align $0100

PLAYFIELD_MEM17
; 20  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_6 ; Boats Left
	.sb "      "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "          "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "        "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "
	.by I_BOAT_LF I_SEATS I_SEATS I_SEATS I_BOAT_LB
	.sb "    "


	.align $0100

; ==========================================================================
; Color Layouts for the screens.
; --------------------------------------------------------------------------

TITLE_BACK_COLORS
	.by COLOR_GREEN COLOR_GREEN
	.by COLOR_GREEN COLOR_GREEN                     ; Title line
	.by COLOR_BLACK                                 ; Space
	.by COLOR_AQUA COLOR_AQUA COLOR_AQUA COLOR_AQUA ; Directions
	.by COLOR_AQUA COLOR_AQUA COLOR_AQUA COLOR_AQUA ; Directions
	.by COLOR_BLACK                                 ; Space
	.by COLOR_ORANGE2 COLOR_ORANGE2 COLOR_ORANGE2   ; Scoring
	.by COLOR_BLACK                                 ; Space
	.by COLOR_PINK COLOR_PINK COLOR_PINK            ; Controls
	.by COLOR_BLACK COLOR_BLACK                     ; Space
	.by COLOR_BLACK                                 ; Press Button (turned off)
	.by COLOR_BLACK                                 ; Credits

TITLE_TEXT_COLORS ; Text luminance
	.by $0C $08 $04 $00                             ; Scrolling title
	.rept 19
		.by $0A                                     ; The rest of the text on screen
	.endr
	.by $00                                         ; Press Button (turned off)
	.by $0A                                         ; Credits


GAME_BACK_COLORS
	.by COLOR_BLACK COLOR_BLACK               ; Scores
	.by COLOR_GREEN                           ; Grassy gap
	.by COLOR_ORANGE1 COLOR_BLUE1 COLOR_BLUE1 ; Beach, boats, boats.
	.by COLOR_ORANGE1 COLOR_BLUE1 COLOR_BLUE1 ; Beach, boats, boats.
	.by COLOR_ORANGE1 COLOR_BLUE1 COLOR_BLUE1 ; Beach, boats, boats.
	.by COLOR_ORANGE1 COLOR_BLUE1 COLOR_BLUE1 ; Beach, boats, boats.
	.by COLOR_ORANGE1 COLOR_BLUE1 COLOR_BLUE1 ; Beach, boats, boats.
	.by COLOR_ORANGE1 COLOR_BLUE1 COLOR_BLUE1 ; Beach, boats, boats.
	.by COLOR_ORANGE1                         ; one last Beach.
	.by COLOR_GREEN                           ; grassy gap
	.by COLOR_BLACK                           ; Press Button (turned off)
	.by COLOR_BLACK                           ; Credits

GAME_TEXT_COLORS ; Text luminance
	.rept 23
		.by $0A                                     ; The rest of the text on screen
	.endr
	.by $00                                         ; Press Button (turned off)
	.by $0A                                         ; Credits


DEAD_BACK_COLORS ; Text luminance
	.by COLOR_BLACK
	.by COLOR_RED_ORANGE COLOR_RED_ORANGE COLOR_RED_ORANGE COLOR_RED_ORANGE
	.by COLOR_RED_ORANGE COLOR_RED_ORANGE COLOR_RED_ORANGE COLOR_RED_ORANGE

	.by COLOR_BLACK COLOR_PINK COLOR_PINK COLOR_PINK COLOR_BLACK

	.by COLOR_RED_ORANGE COLOR_RED_ORANGE COLOR_RED_ORANGE COLOR_RED_ORANGE
	.by COLOR_RED_ORANGE COLOR_RED_ORANGE COLOR_RED_ORANGE COLOR_RED_ORANGE

	.by COLOR_BLACK
	.by COLOR_BLACK                                 ; Press Button (turned off)
	.by COLOR_BLACK                                 ; Credits

DEAD_TEXT_COLORS ; Text luminance
	.by $00
	.by $0E $0C $0A $08 $06 $04 $02 $00
	.by $00 $0A $08 $06 $00
	.by $00 $02 $04 $06 $08 $0A $0C $0E
	.by $00
	.by $00                                         ; Press Button (turned off)
	.by $0A                                         ; Credits


WIN_BACK_COLORS
	.by COLOR_BLACK  ; Scores
	.by COLOR_ORANGE1 COLOR_ORANGE2 COLOR_RED_ORANGE COLOR_PINK
	.by COLOR_PURPLE COLOR_PURPLE_BLUE COLOR_BLUE1 COLOR_BLUE2

	.by COLOR_BLACK COLOR_GREEN COLOR_GREEN COLOR_GREEN COLOR_BLACK

	.by COLOR_LITE_BLUE COLOR_AQUA COLOR_BLUE_GREEN COLOR_GREEN
	.by COLOR_YELLOW_GREEN COLOR_ORANGE_GREEN COLOR_LITE_ORANGE COLOR_ORANGE2

	.by COLOR_BLACK
	.by COLOR_BLACK                                 ; Press Button (turned off)
	.by COLOR_BLACK                                 ; Credits

WIN_TEXT_COLORS
	.by $00; Text luminance
	.by $0A $0A $0A $0A $0A $0A $0A $0A
	.by $00 $0C $08 $04 $00
	.by $0A $0A $0A $0A $0A $0A $0A $0A
	.by $00
	.by $00                                         ; Press Button (turned off)
	.by $0A                                         ; Credits

OVER_BACK_COLORS
	.by COLOR_BLACK
	.by COLOR_PINK COLOR_PINK COLOR_PINK COLOR_PINK
	.by COLOR_PINK COLOR_PINK COLOR_PINK COLOR_PINK

	.by COLOR_BLACK COLOR_BLACK COLOR_BLACK COLOR_BLACK COLOR_BLACK

	.by COLOR_PINK COLOR_PINK COLOR_PINK COLOR_PINK
	.by COLOR_PINK COLOR_PINK COLOR_PINK COLOR_PINK

	.by COLOR_BLACK
	.by COLOR_BLACK                                 ; Press Button (turned off)
	.by COLOR_BLACK                                 ; Credits

OVER_TEXT_COLORS
	.by $00; Text luminance
	.by $00 $02 $04 $06 $08 $0A $0C $0E
	.by $00 $0A $08 $06 $00
	.by $0E $0C $0A $08 $06 $04 $02 $00
	.by $00
	.by $00                                         ; Press Button (turned off)
	.by $0A                                         ; Credits


	.align $0100

; ==========================================================================
; Tables listing pointers to all the assets.
; --------------------------------------------------------------------------

; ==========================================================================
; Give a display number below the VBI routine can set the Display List,
; and populate zero page pointers for other routines.
; --------------------------------------------------------------------------

DISPLAY_TITLE = 0
DISPLAY_GAME  = 1
DISPLAY_WIN   = 2
DISPLAY_DEAD  = 3
DISPLAY_OVER  = 4

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
PLAYFIELD_MEM_LO_TABLE
	.byte <PLAYFIELD_MEM0
	.byte <PLAYFIELD_MEM1
	.byte <PLAYFIELD_MEM2
	.byte <PLAYFIELD_MEM3
	.byte <PLAYFIELD_MEM4
	.byte <PLAYFIELD_MEM5
	.byte <PLAYFIELD_MEM6
	.byte <PLAYFIELD_MEM7
	.byte <PLAYFIELD_MEM8
	.byte <PLAYFIELD_MEM9
	.byte <PLAYFIELD_MEM10
	.byte <PLAYFIELD_MEM11
	.byte <PLAYFIELD_MEM12
	.byte <PLAYFIELD_MEM13
	.byte <PLAYFIELD_MEM14
	.byte <PLAYFIELD_MEM15
	.byte <PLAYFIELD_MEM16
	.byte <PLAYFIELD_MEM17
	.byte <PLAYFIELD_MEM18

PLAYFIELD_MEM_HI_TABLE
	.byte >PLAYFIELD_MEM0
	.byte >PLAYFIELD_MEM1
	.byte >PLAYFIELD_MEM2
	.byte >PLAYFIELD_MEM3
	.byte >PLAYFIELD_MEM4
	.byte >PLAYFIELD_MEM5
	.byte >PLAYFIELD_MEM6
	.byte >PLAYFIELD_MEM7
	.byte >PLAYFIELD_MEM8
	.byte >PLAYFIELD_MEM9
	.byte >PLAYFIELD_MEM10
	.byte >PLAYFIELD_MEM11
	.byte >PLAYFIELD_MEM12
	.byte >PLAYFIELD_MEM13
	.byte >PLAYFIELD_MEM14
	.byte >PLAYFIELD_MEM15
	.byte >PLAYFIELD_MEM16
	.byte >PLAYFIELD_MEM17
	.byte >PLAYFIELD_MEM18

; ==========================================================================
; A list of the game playfield's LMS address locations.
; --------------------------------------------------------------------------

PLAYFIELD_LMS_LO_TABLE
	.byte <PF_LMS0
	.byte <PF_LMS1
	.byte <PF_LMS2
	.byte <PF_LMS3
	.byte <PF_LMS4
	.byte <PF_LMS5
	.byte <PF_LMS6
	.byte <PF_LMS7
	.byte <PF_LMS8
	.byte <PF_LMS9
	.byte <PF_LMS10
	.byte <PF_LMS11
	.byte <PF_LMS12
	.byte <PF_LMS13
	.byte <PF_LMS14
	.byte <PF_LMS15
	.byte <PF_LMS16
	.byte <PF_LMS17
	.byte <PF_LMS18

PLAYFIELD_LMS_HI_TABLE
	.byte >PF_LMS0
	.byte >PF_LMS1
	.byte >PF_LMS2
	.byte >PF_LMS3
	.byte >PF_LMS4
	.byte >PF_LMS5
	.byte >PF_LMS6
	.byte >PF_LMS7
	.byte >PF_LMS8
	.byte >PF_LMS9
	.byte >PF_LMS10
	.byte >PF_LMS11
	.byte >PF_LMS12
	.byte >PF_LMS13
	.byte >PF_LMS14
	.byte >PF_LMS15
	.byte >PF_LMS16
	.byte >PF_LMS17
	.byte >PF_LMS18

; ==========================================================================
; A list of the game playfield's LMS address locations for ONLY the
; moving rows of boats based on direction.
; --------------------------------------------------------------------------

PLAYFIELD_LMS_RIGHT_LO_TABLE
	.byte <PF_LMS1
	.byte <PF_LMS4
	.byte <PF_LMS7
	.byte <PF_LMS10
	.byte <PF_LMS13
	.byte <PF_LMS16

PLAYFIELD_LMS_RIGHT_HI_TABLE
	.byte >PF_LMS1
	.byte >PF_LMS4
	.byte >PF_LMS7
	.byte >PF_LMS10
	.byte >PF_LMS13
	.byte >PF_LMS16


PLAYFIELD_LMS_LEFT_LO_TABLE
	.byte <PF_LMS2
	.byte <PF_LMS5
	.byte <PF_LMS8
	.byte <PF_LMS11
	.byte <PF_LMS14
	.byte <PF_LMS17

PLAYFIELD_LMS_LEFT_HI_TABLE
	.byte >PF_LMS2
	.byte >PF_LMS5
	.byte >PF_LMS8
	.byte >PF_LMS11
	.byte >PF_LMS14
	.byte >PF_LMS17


; =========================================================================
; A list of the game LMS addresses for scrolling the credit line.
; --------------------------------------------------------------------------

PLAYFIELD_LMS_SCROLL_LO_TABLE
	.byte <SCROLL_CREDIT_LMS0
	.byte <SCROLL_CREDIT_LMS1
	.byte <SCROLL_CREDIT_LMS2
	.byte <SCROLL_CREDIT_LMS3
	.byte <SCROLL_CREDIT_LMS4


PLAYFIELD_LMS_SCROLL_HI_TABLE
	.byte >SCROLL_CREDIT_LMS0
	.byte >SCROLL_CREDIT_LMS1
	.byte >SCROLL_CREDIT_LMS2
	.byte >SCROLL_CREDIT_LMS3
	.byte >SCROLL_CREDIT_LMS4
