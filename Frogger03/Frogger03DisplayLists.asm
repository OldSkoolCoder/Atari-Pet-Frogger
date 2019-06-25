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
; Version 03, June 2019
;
; --------------------------------------------------------------------------

; ==========================================================================
; Display Lists.
;
; In Versions 00 through 02 the the custom Display lists make the Atari 
; impersonate the PET 4032's 40-column, 25 line display.  Version 03 now
; substitutes graphics for some uses of text modes, and uses different 
; sizes of blank lines to fill empty areas of the screen.  
; Due to requirements of the Game screen, the displays are now 202 
; scan lines, two taller than needed for the default, 25 text line 
; display used by the Pet.
;
; The Atari OS text printing is not being used, therefore the Atari screen
; editor's limitations are not an issue.
;
; ANTIC has a 1K boundary limit for Display Lists.  We do not need to align
; to 1K, because display lists are ordinarily short, and several will 
; easily fit in one page of memory.  So, the code can make due with 
; aligning to a page.  If they all stay in the page then they can't cross
; a 1K boundary.
; --------------------------------------------------------------------------

	.align $0100

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

; ==========================================================================
; Give a display number below the VBI routine can set the Display List,
; and populate zero page pointers for other routines.
; --------------------------------------------------------------------------

DISPLAY_TITLE = 0
DISPLAY_GAME  = 1
DISPLAY_WIN   = 2
DISPLAY_DEAD  = 3
DISPLAY_OVER  = 4


; Version 01, and 02  used graphics control characters in Antic Text 
; Mode 2 for the title.  Version 03 uses 6 lines of Map Mode 9 in place 
; of the 3 lines of Text Mode 2.  Real graphics ensue...
; Mode 9 requires only 10 bytes per line.  Therefore only 20 bytes 
; for 2 lines which cover the same screen real-estate (8 scan lines) 
; as the text line they replace.  The text line requires 40 bytes which 
; doesn't include the character set data needed for the Text mode.
; In V03 we're replacing the V02 scrolling with glitzier color 
; transitions as the Map mode allows full use of color and the 
; individual lines allow 6 easy transitions in this space instead 
; of 3 with the Text mode.  
; Also, the Title screen will add a flying frog demo, so that's the 
; eye candy for Version 03.

; New DLI updates.....  
; Before score line 1, need to set all PM registers.
; After score line 1 need a minimal line to burn off the second entry in the tables.
; Need a line before gfx to set all the regular player's attributes.
; May need to insert some blanks between lines to allow more time. 

TITLE_DISPLAYLIST
	.byte DL_BLANK_8        ; 8 scan lines 
	.byte DL_BLANK_8 ; 8 blank scan lines.  DLI 0/0 Score_DLI sets COLPF1, COLPF2, COLBK for score text. set P/M position
;	.byte DL_BLANK_4        ; 4 blank lines. 
	.byte DL_BLANK_2|DL_DLI    

	mDL_LMS DL_TEXT_2,SCORE_MEM1           ; (1-8) scores
	
	.byte DL_BLANK_2
	
	.byte   DL_BLANK_8|DL_DLI              ; (9-16) An empty line. DLI 1/1 COLPF0_COLBK_DLI Set GREEN background (COLBAK) and Map mode 9 color (COLPF0) for Line1. 

 

	;                                        Title Graphics...
	mDL_LMS DL_MAP_9|DL_DLI,TITLE_MEM1     ; (17-20)   DLI 2/2 COLPF0_COLBK_DLI Set COLPF0 for Line 2
	.byte   DL_MAP_9|DL_DLI                ; (21-24)   DLI 2/3 COLPF0_COLBK_DLI Set COLPF0 for Line 3
	.byte   DL_MAP_9|DL_DLI                ; (25-28)   DLI 2/4 COLPF0_COLBK_DLI Set COLPF0 for Line 4
	.byte   DL_MAP_9|DL_DLI                ; (29-32)   DLI 2/5 COLPF0_COLBK_DLI Set COLPF0 for Line 5
	.byte   DL_MAP_9|DL_DLI                ; (33-36)   DLI 2/6 COLPF0_COLBK_DLI Set COLPF0 for Line 6
	.byte   DL_MAP_9|DL_DLI                ; (37-40)   DLI 2/7 COLPF0_COLBK_DLI Set COLPF0 for underlines

	.byte   DL_BLANK_2                     ; (41-42)   An empty line.      2
	.byte   DL_MAP_9                       ; (43-46)   Underlines        + 4
	.byte   DL_BLANK_2|DL_DLI              ; (47-48)   An empty line.    + 2 = 8 
	;                                                  DLI 3/8 TITLE_DLI_3 set BLACK for COLBK.

	.byte   DL_BLANK_8|DL_DLI              ; (49-56)   DLI 4/9 TITLE_DLI_4 set AQUA for COLBK and COLPF2, and set COLPF1

	;                                        Basic Instructions... 
	mDL_LMS DL_TEXT_2|DL_DLI,INSTRUCT_MEM1 ; (57-64)   DLI 5/10 TITLE_DLI_5 set COLPF1 text
	.byte   DL_TEXT_2|DL_DLI               ; (65-72)   DLI 5/11 TITLE_DLI_5 set COLPF1 text
	mDL_LMS DL_TEXT_2|DL_DLI,INSTRUCT_MEM3 ; (73-80)   DLI 5/12 TITLE_DLI_5 set COLPF1 text
	.byte   DL_TEXT_2|DL_DLI               ; (81-88)   DLI 5/13 TITLE_DLI_5 set COLPF1 text
	.byte   DL_TEXT_2|DL_DLI               ; (89-96)   DLI 5/14 TITLE_DLI_5 set COLPF1 text
	.byte   DL_TEXT_2|DL_DLI               ; (97-104)  DLI 5/15 TITLE_DLI_5 set COLPF1 text
	mDL_LMS DL_TEXT_2|DL_DLI,INSTRUCT_MEM7 ; (105-112) DLI 5/16 TITLE_DLI_5 set COLPF1 text
	.byte   DL_TEXT_2|DL_DLI               ; (113-120) DLI 3/17 TITLE_DLI_3 set BLACK for COLBK

	.byte   DL_BLANK_8|DL_DLI              ; (121-128) DLI 4/18 TITLE_DLI_4 set ORANGE2 for COLBK and COLPF2, set COLPF1 text   
	;                                      ; Scoring.  
	.byte   DL_TEXT_2|DL_DLI               ; (129-136) DLI 5/19 TITLE_DLI_5 set COLPF1 text
	.byte   DL_TEXT_2|DL_DLI               ; (137-144) DLI 5/20 TITLE_DLI_5 set COLPF1 text

	.byte   DL_TEXT_2|DL_DLI               ; (145-152) DLI 3/21 TITLE_DLI_3 set BLACK for COLBK

	.byte   DL_BLANK_8|DL_DLI              ; (153-160) An empty line. DLI 4/22 TITLE_DLI_4 set PINK for COLBK and COLPF2, and set COLPF1 text

	;                                        Game Controls...
	.byte   DL_TEXT_2|DL_DLI               ; (161-168) DLI 5/23 TITLE_DLI_5 set COLPF1 text

	mDL_LMS DL_TEXT_2|DL_DLI,CONTROLS_MEM2 ; (169-176) DLI 3/24 TITLE_DLI_3 set BLACK for COLBK

	.byte   DL_BLANK_8|DL_DLI              ; (177-184) An empty line.  DLI SPC1/25 sets COLBK, COLPF2, COLPF1 colors.

	.byte   DL_BLANK_1                     ; (185)     One extra to line up credit with the same line on the game screen 

	mDL_JMP BOTTOM_OF_DISPLAY              ; (186-193, 194, 195-202) End of display.  See Page 0 for this evil.


; Revised V03 Main Game Play Screen:
; FYI: Old boats.
; 8  | [QQQQ>        [QQQQ>       [QQQQ>      | TEXT1_2
; 9  |      <QQQQ]        <QQQQ]    <QQQQ]    | TEXT1_2
; Old:  [QQQQ>
; New: [[QQQQQ>

; New boats are larger to provide more safe surface for the larger 
; frog and to provide some additional graphics enhancement for 
; the boats.  Illustration below shows the lines with the 
; additional boat data needed for scrolling.

; Line placement is jiggled about to add enough blank lines and 
; filler space to make the Display List Interrupts work, so the 
; gap at the  bottom of the illustration is not real -- its scan 
; lines are distributed between the other lines.
; Given the number of things that the Display List Interrupts must 
; reload between each line, and the fact that horizontal scrolling 
; lines results in variable DMA timing to the point where zero CPU 
; time is available, the DLIs on scrolling lines are moved to the 
; following line.  Consequently, in order to preserve the color 
; continuity after a boat line the line following the boat is not 
; a blank line.   It is a Mode C line filled with COLPF0 pixels. 
; This allows the DLIs to manage the color transition for the 
; Background color before it is needed, and delay the update to 
; COLPF0 until later.

;    +----------------------------------------+
; 1  |Score:00000000               00000000:Hi| SCORE_TXT
; 2  |Frogs:0    Frogs Saved:OOOOOOOOOOOOOOOOO| SCORE_TXT
; 3  |                                        | 
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
; 23 |                                        |
; 24 |                                        |
; 25 |(c) November 1983 by DalesOft  Written b| SCROLLING CREDIT
;    +----------------------------------------+

; New DLI updates.....  
; Before score line 1, need to set all PM registers.
; After score line 1 need to set everything for line 2.
; Need a line before gfx to set all the regular player's attributes.
; May need to insert some blanks between lines to allow more time. 
; Beach DLI may need to start earlier, run longer, and PM properties 
; may need to be setup first before playfield.

GAME_DISPLAYLIST
	.byte DL_BLANK_8, DL_BLANK_8|DL_DLI
	.byte DL_BLANK_2                                ; 20 blank scan lines.  
	;                                                                  SCORE DLI 0/0 sets COLPF1, COLPF2/COLBK for score text.
	
	mDL_LMS DL_TEXT_2|DL_DLI,SCORE_MEM1                    ; (1-8)     Labels for scores 1. 
	;                                                                  SCORE DLI 0/1 sets COLPF1, COLPF2/COLBK for score text.
	
	.byte DL_BLANK_1                                       ; ()      


; ========== Start

	.byte DL_TEXT_2|DL_DLI                                 ; (9-16)    Labels for Scores 2.
	;                                                                  DLI 2/2 sets COLPF0,1,2,3,BK for Beach. (row 18)

; ========== 1

	.byte DL_BLANK_2                                       ; (17)      Blank before Beach for time.
	
PF_LMS0 = [* + 1]                                          ;           Plus 1 is the address of the display list LMS
	mDL_LMS DL_TEXT_4|DL_DLI,PLAYFIELD_MEM0                ; (18-25)   Beach. 
	;                                                                  DLI 3/3 sets boats right (row 17) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (26)      One scan line 

PF_LMS1 = [* + 1] ; Right
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM1            ; (27-34)   Boats Right (row 17)

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (35)      One scan line 
	;                                                                  DLI 3/4 sets boats left (row 16) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (36)      One scan line free time for DLI

PF_LMS2 = [* + 1] ; Left
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM2+8          ; (37-44)   Boats Left (row 16)

; ========== 2

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (45)      One scan line 
	;                                                                  DLI 2/5 sets COLPF0,1,2,3,BK for Beach (row 15) 

PF_LMS3 = [* + 1]                                          ;           Plus 1 is the address of the display list LMS
	mDL_LMS DL_TEXT_4|DL_DLI,PLAYFIELD_MEM3                ; (46-53)   Beach. 
	;                                                                  DLI 3/6 sets boats right (row 14) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (54)      One scan line 

PF_LMS4 = [* + 1] ; Right
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM4+4          ; (55-62)   Boats Right (row 14)

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (63)      One scan line 
	;                                                                  DLI 3/7 sets boats left (row 13) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (64)      One scan line free time for DLI

PF_LMS5 = [* + 1] ; Left
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM5+12         ; (65-72)   Boats Left (row 13)

; ========== 3

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (73)      One scan line 
	;                                                                  DLI 2/8 sets COLPF0,1,2,3,BK for Beach (row 12) 

PF_LMS6 = [* + 1]                                          ;           Plus 1 is the address of the display list LMS
	mDL_LMS DL_TEXT_4|DL_DLI,PLAYFIELD_MEM6                ; (74-81)   Beach. 
	;                                                                  DLI 3/9 sets boats right (row 11) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (82)      One scan line 

PF_LMS7 = [* + 1] ; Right
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM7+4          ; (83-90)   Boats Right (row 11)

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (91)      One scan line 
	;                                                                  DLI 3/10 sets boats left (row 10) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (92)      One scan line free time for DLI

PF_LMS8 = [* + 1] ; Left
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM8+12         ; (93-100)  Boats Left (row 10)

; ========== 4

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (101)     One scan line 
	;                                                                  DLI 2/11 sets COLPF0,1,2,3,BK for Beach (row 9) 

PF_LMS9 = [* + 1]                                          ;           Plus 1 is the address of the display list LMS
	mDL_LMS DL_TEXT_4|DL_DLI,PLAYFIELD_MEM9                ; (102-109) Beach. 
	;                                                                  DLI 3/12 sets boats right (row 8) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (110)     One scan line 

PF_LMS10 = [* + 1] ; Right
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM10+8         ; (111-118) Boats Right (row 8)

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (119)     One scan line 
	;                                                                  DLI 3/13 sets boats left (row 7) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (120)     One scan line free time for DLI

PF_LMS11 = [* + 1] ; Left
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM11+12        ; (121-128) Boats Left (row 7)

; ========== 5

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (129)     One scan line 
	;                                                                  DLI 2/14 sets COLPF0,1,2,3,BK for Beach (row 6) 

PF_LMS12 = [* + 1]                                         ;           Plus 1 is the address of the display list LMS
	mDL_LMS DL_TEXT_4|DL_DLI,PLAYFIELD_MEM12               ; (130-137) Beach. 
	;                                                                  DLI 3/15 sets boats right (row 5) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (138)     One scan line 

PF_LMS13 = [* + 1] ; Right
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM13           ; (139-146) Boats Right (row 5)

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (147)      One scan line 
	;                                                                  DLI 3/16 sets boats left (row 4) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (148)     One scan line free time for DLI

PF_LMS14 = [* + 1] ; Left
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM14+4         ; (149-156) Boats Left (row 4)

; ========== 6

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (157)     One scan line 
	;                                                                  DLI 2/17 sets COLPF0,1,2,3,BK for Beach (row 3) 

PF_LMS15 = [* + 1]                                         ;           Plus 1 is the address of the display list LMS
	mDL_LMS DL_TEXT_4|DL_DLI,PLAYFIELD_MEM15               ; (158-165) Beach. 
	;                                                                  DLI 3/18 sets boats right (row 2) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (166)     One scan line 

PF_LMS16 = [* + 1] ; Right
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM16+8         ; (167-174) Boats Right (row 2)

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (175)      One scan line 
	;                                                                  DLI 3/19 sets boats left (row 1) COLPF0,1,2,3,BK,HSCROLL.
	.byte DL_BLANK_1                                       ; (176)     One scan line free time for DLI

PF_LMS17 = [* + 1] ; Left
	mDL_LMS DL_TEXT_4|DL_HSCROLL,PLAYFIELD_MEM17+12        ; (177-184) Boats Left (row 1)

; ========== End Beach 

	mDL_LMS DL_MAP_C|DL_DLI,MODE_C_COLPF0                  ; (185)      One scan line 
	;                                                                  DLI 2/20 sets COLPF0,1,2,3,BK for Beach (row 0) 

PF_LMS18 = [* + 1]                                         ;           Plus 1 is the address of the display list LMS
	mDL_LMS DL_TEXT_4|DL_DLI,PLAYFIELD_MEM18               ; (186-193) Beach. 
	;                                                                  DLI 5/21 HSCROL for credit, calls SPC2 to set COLPF2/COLBK Black

; ========== End 2

	.byte DL_BLANK_1                                       ; (194)     One scan line 

	mDL_JMP DL_SCROLLING_CREDIT                            ; (195-202) End of display. No prompt for button. See Page 0 for the evil.



; Until some other eye candy improvement is conceived, these 
; three  graphics Display Lists are nearly identical with 
; the only difference as the bitmap shown in the graphics 
; section (and the main code color manipulation routines.)

; So, instead of three display lists, just use one.  The VBI
; will know which graphics memory address to use for the
; GFX_LMS in the display list.  And since all the bitmaps are
; in the same page only the LMS low byte needs to be updated.

; FROG SAVED screen, 200 scan lines....:
;    80 scan lines = 20 blank lines (by 4 scan lines each) of color cycling.
; +  24 scan lines = 6 lines (by 4 scan lines each) of big text.
; +  80 scan lines = 20 blank lines (by 4 scan lines each) of color cycling.
; +   8 scan lines = Press A Button Line of text
; +   8 scan lines = infinitely scrolling credit. 
; = 200 scan lines.

FROGSAVED_DISPLAYLIST
FROGDEAD_DISPLAYLIST
GAMEOVER_DISPLAYLIST
	.byte DL_BLANK_8, DL_BLANK_8
	.byte DL_BLANK_4|DL_DLI               ; 20 blank scan lines. DLI 0/0 Set COLBK color

	.rept 20                              ; an empty line. times 20
		.byte DL_BLANK_4|DL_DLI           ; (1 - 80) DLI 0/1 - 0/18 COLBK color, 
	.endr                                 ;          DLI 1/19 COLBK Title, COLPF0 gfx

GFX_LMS = [* + 1]                         ; Label the low byte of the LMS address.
	mDL_LMS DL_MAP_9|DL_DLI,FROGSAVE_MEM  ; (81-84) DLI 1/20   COLPF0 gfx
	.byte DL_MAP_9|DL_DLI                 ; (85-88) DLI 1/21   COLPF0 gfx
	.byte DL_MAP_9|DL_DLI                 ; (89-92) DLI 1/22   COLPF0 gfx
	.byte DL_MAP_9|DL_DLI                 ; (93-96) DLI 1/23   COLPF0 gfx
	.byte DL_MAP_9|DL_DLI                 ; (97-100) DLI 1/24   COLPF0 gfx
	.byte DL_MAP_9|DL_DLI                 ; (101-104) DLI 0/25   COLBK Black

	.rept 20                              ; an empty line. times 20
		.byte DL_BLANK_4|DL_DLI           ; (105-184) DLI 0/26 - 0/43 COLBK color, 
	.endr                                 ;           DLI DLI SPC1/44 sets COLBK, COLPF2, COLPF1 colors.
	
	.byte DL_BLANK_1                                       ; (191)     One scan line 
	
	mDL_JMP BOTTOM_OF_DISPLAY             ; End of display.  See Page 0 for the evil.

