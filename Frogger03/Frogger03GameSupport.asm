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
; GAME SUPPORT
;
; Miscellaneous supporting data.
; Clear game scores.
; Add 500 to game score (and increment saved Frogs)
; Add 10 to game score.
; Determine if current score is high score
; Move the frog up a row.
; Automatic, logical frog horizontal movement when boats move.
; Set boats' speed based on number of frogs saved.
;
; --------------------------------------------------------------------------


; ==========================================================================
; Originally, this was coarse scroll movement and the frog moved the 
; width of a character.  
; Based on number of frogs, how many frames between the boats' 
; character-based coarse scroll movement:
; ANIMATION_FRAMES .byte 30,25,20,18,15,13,11,10,9,8,7,6,5,4,3
;
; Fine scroll increments 4 times to equal one character 
; movement per timer above. Frog movement is two color clocks,
; or half a character per horizontal movement.
;
; Minimum coarse scroll speed was 2 characters per second, or 8 
; color clocks per second, or between 7 and 8 frames per color clock.
; The fine scroll will start at 7 frames per color clock.
;
; Maximum coarse scroll speed (3 frames == 20 character movements 
; per second) was the equivalent of 4 color clocks in 3 frames.
; The fine scroll speed will max out at 3 color clockw per frame.
;
; The Starting speed is slower than the coarse scrolling version.
; It ramps up to maximum speed in fewer levels/rescued frogs, and 
; the maximum speed is faster than the fastest coarse scroll
; speed (60 FPS fine scroll is faaast.)

; FYI -- SCROLLING RANGE
; Boats Right ;   64
; Start Scroll position = LMS + 12 (decrement), HSCROL 0  (Increment)
; End   Scroll position = LMS + 0,              HSCROL 15
; Boats Left ; + 64 
; Start Scroll position = LMS + 0 (increment), HSCROL 15  (Decrement)
; End   Scroll position = LMS + 12,            HSCROL 0

; Difficulty Progression Enhancement.... Each row can have its own frame 
; counter and scroll distance. 
; (and by making rows closer to the bottom run faster it produces a 
; kind of parallax effect. almost).

MAX_FROG_SPEED = 13 ; Number of difficulty levels (which means 14)

; About the arrays below.  18 bytes per row instead of 19:
; FrogRow ranges from 0 to 18 which is 19 rows.  The first and
; last rows are always have values 0.  When reading a row from the array,
; the index will overshoot the end of a row (18th entry) and read the 
; beginning of the next row as the 19th entry.  Since both always 
; use values 0, they are logically overlapped.  Therefore, each array 
; row needs only 18 bytes instead of 19.  Only the last row needs 
; the trailing 19th 0 added.
; 14 difficulty levels is the max, because of 6502 indexing.
; 18 bytes per row * 14 levels is 252 bytes.
; More levels would require more pointer expression to reach each row
; rather than simply (BOAT_FRAMES),Y.

BOAT_FRAMES ; Number of frames to wait to move boat. (top to bottom) (Difficulty 0 to 13)
	.by 0 7 7 0 7 7 0 7 7 0 7 7 0 7 7 0 7 7   ; Difficulty 0 
	.by 0 7 7 0 7 7 0 7 7 0 5 5 0 5 5 0 5 5   ; Difficulty 1 
	.by 0 7 7 0 7 7 0 5 5 0 5 5 0 3 3 0 3 3   ; Difficulty 2
	.by 0 7 7 0 7 5 0 5 5 0 3 3 0 3 2 0 2 2   ; Difficulty 3 
	.by 0 5 5 0 5 3 0 3 3 0 2 2 0 2 2 0 1 1   ; Difficulty 4 
	.by 0 5 5 0 3 3 0 3 2 0 2 2 0 1 1 0 1 1   ; Difficulty 5 
	.by 0 5 3 0 3 3 0 2 2 0 2 1 0 1 1 0 1 0   ; Difficulty 6 
	.by 0 3 3 0 3 2 0 2 2 0 1 1 0 1 0 0 0 0   ; Difficulty 7
	.by 0 3 3 0 2 2 0 1 1 0 1 1 0 0 0 0 0 0   ; Difficulty 8
	.by 0 3 2 0 2 1 0 1 1 0 0 0 0 0 0 0 0 0   ; Difficulty 9
	.by 0 2 2 0 1 1 0 1 0 0 0 0 0 0 0 0 0 0   ; Difficulty 10
	.by 0 2 1 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0   ; Difficulty 11
	.by 0 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0   ; Difficulty 12
	.by 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ; Difficulty 13

BOAT_SHIFT  ; Number of color clocks to scroll boat. (add or subtract)
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1   ; Difficulty 0
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1   ; Difficulty 1
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1   ; Difficulty 2
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1   ; Difficulty 3
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1   ; Difficulty 4
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1   ; Difficulty 5
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1   ; Difficulty 6
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1   ; Difficulty 7
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1   ; Difficulty 8
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 1 2 0 2 2   ; Difficulty 9
	.by 0 1 1 0 1 1 0 1 1 0 1 1 0 2 2 0 2 2   ; Difficulty 10
	.by 0 1 1 0 1 1 0 1 1 0 2 2 0 2 2 0 2 2   ; Difficulty 11
	.by 0 1 1 0 1 1 0 2 2 0 2 2 0 2 2 0 2 2   ; Difficulty 12
	.by 0 1 1 0 2 2 0 2 2 0 2 3 0 2 3 0 3 3 0 ; Difficulty 13

MOVING_ROW_STATES ; 19 entries describing boat directions. Beach (0), Right (1), Left (FF) directions.
	.by 0 1 $FF 0 1 $FF 0 1 $FF 0 1 $FF 0 1 $FF 0 1 $FF 0

PM_OFFS=26 ; offset to line up P/M Vertical Y line to Playfield scan line

FROG_PMY_TABLE ; 19 entries providing Frog Y position for each row.  (Each row is no longer equal size.)
	.by [ 17+PM_OFFS] [ 26+PM_OFFS] [ 36+PM_OFFS]  ; Beach, Boat Right, Boat Left
	.by [ 45+PM_OFFS] [ 54+PM_OFFS] [ 64+PM_OFFS] 
	.by [ 73+PM_OFFS] [ 82+PM_OFFS] [ 92+PM_OFFS] 
	.by [101+PM_OFFS] [110+PM_OFFS] [120+PM_OFFS] 
	.by [129+PM_OFFS] [138+PM_OFFS] [148+PM_OFFS] 
	.by [157+PM_OFFS] [166+PM_OFFS] [176+PM_OFFS] 
	.by [185+PM_OFFS]                             ; Home Beach


; ==========================================================================
; FROG MOVE UP
;
; Add 10 to the score.
; Decrement the Row counter.
; Set new Frog screen position.
;
; On return BEQ means the frog has reached safety. (Row 0)
; Thus BNE means continue game.
;
; FROG_PMY_TABLE is the lookup for vertical positions, because each row 
; on screen is not equal height.  Rather than a pile of logical comparisons
; and math the resulting values are put in the table.
; 
; Uses A, X
;
; Returns Row number, and Z flag indicates game can continue.
; --------------------------------------------------------------------------
FrogMoveUp
	jsr Add10ToScore     ; 10 points for moving forward.

	ldx FrogRow          ; Get the current Row number
	dex                  ; Minus 1 row.
	stx FrogNewRow       ; Save new Row Number. 
	lda FROG_PMY_TABLE,x ; Get the new Player/Missile Y position based on row number.
	sta FrogNewPMY       ; Update Frog position on screen. 

	lda FrogNewRow       ; Tell caller the new row number.
	rts


; ==========================================================================
; ZERO FROG PAGE ZERO
;
; Zero a group of page 0 values: 
; (coordinates, and current shape index.)
; FrogPMY, FrogPMX, FrogShape, FrogNewPMY, FrogNewPMX, FrogNewShape
; --------------------------------------------------------------------------
ZeroFrogPageZero

	ldx #5
bPMAZClearCoords 
	sta FrogPMY,x
	dex
	bpl bPMAZClearCoords

	rts


; ==========================================================================
; FROG EYE FOCUS
;
; The Frog's eyes move based on the joystick input direction.
; Default position for the eyes is #1.
;
; Eye positions:
;  - 3 -
;  0 1 2
;  - - -
;
; Set the eye position.
; Set the Timer for how long the eye will remain at that position 
; before returning to the default.
; Flag the mandatory redraw notification for the VBI.
;
; A is the Eye position.
; --------------------------------------------------------------------------
FrogEyeFocus

	sta FrogEyeball ; Set the eyeball shape.
	lda #60         ; Set one second timer.
	sta FrogRefocus
	inc FrogUpdate  ; Set mandatory Frog Update on next frame.

	rts


; ==========================================================================
; Clear the score digits to zeros.
; That is, internal screen code for "0"
; If a high score is flagged, then do not clear high score.
; And some other things at game start.
; --------------------------------------------------------------------------
ClearGameScores
	ldx #$07            ; 8 digits. 7 to 0
	lda #INTERNAL_0     ; Atari internal code for "0"

LoopClearScores
	sta MyScore,x       ; Put zero/"0" in score buffer.

	ldy FlaggedHiScore  ; Has a high score been flagged? ($FF)
	bmi NextScoreDigit  ; If so, then skip clearing Hi score and go to the next digit.

	sta HiScore,x       ; Also put zero/"0" in the high score.

NextScoreDigit
	dex                 ; decrement index to score digits.
	bpl LoopClearScores ; went from 0 to $FF? no, loop for next digit.

;	lda #3              ; Reset number of
	lda #1              ; Reset number of
	sta NumberOfLives   ; lives to 3.

;	lda #0
;	sta FrogsCrossed         ; Zero the number of successful crossings.
;	sta FrogsCrossedIndex    ; And the index lookup for the boat/row settings.
;	jsr MultiplyFrogsCrossed ; Multiply by 18, make index base, set difficulty address pointers.

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

	inc FrogsCrossed         ; Add to frogs successfully crossed the rivers.
	jsr MultiplyFrogsCrossed ; Multiply by 18, make index base, set difficulty address pointers.

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
; Add value in ScoreToAdd to the score at index position
; NumberOfChars in the score digits.
;
; A, Y, X registers  are preserved.
; --------------------------------------------------------------------------
AddToScore
	mRegSaveAYX          ; Save A, X, and Y.

	ldx NumberOfChars    ; index into "00000000" to add score.
	lda ScoreToAdd       ; value to add to the score
	clc
	adc MyScore,x
	sta MyScore,x

EvaluateCarry            ; (re)evaluate if carry occurred for the current position.
	lda MyScore,x
	cmp #[INTERNAL_0+10] ; Did math carry past the "9"?
	bcc ExitAddToScore   ; less than.  it did not carry. go to exit.

; The score carried past "9", so it must be adjusted and
; the next/greater position is added.
	sbc #10              ; Subtract 10 from current value (carry is already set)
	sta MyScore,x        ; update current position.
	dex                  ; Go to previous position in score.
	inc MyScore,x        ; Add 1 to carry to the previous digit.
	bne EvaluateCarry    ; This cannot go from $FF to 0, so it must be not zero.

ExitAddToScore           ; All done.
	jsr HighScoreOrNot   ; If My score is high score, then copy to high score.

	mRegRestoreAYX       ; Restore Y, X, and A

	rts


; ==========================================================================
; HIGH SCORE OR NOT
;
; Figure out if My Score is the High Score.
; If so, then copy My Score to High Score.
;
; A  and  X  used.
; --------------------------------------------------------------------------
HighScoreOrNot
	ldx #0

CompareScoreToHighScore
	lda HiScore,x
	cmp MyScore,x
	beq ContinueCheckingScores  ; They are the same, keep trying
	bcc CopyNewHighScore        ; Hi score less than My score.
	rts                         ; Hi score greater than My Score.  stop checking.

ContinueCheckingScores
	inx
	cpx #7                      ; Are all 7 digits tested?
	bne CompareScoreToHighScore ; No, then go do next digit.
	rts                         ; Yes.  Done.

CopyNewHighScore                ; It is a high score.
	lda MyScore,x               ; Copy my score to high score
	sta HiScore,x
	inx
	cpx #7                      ; Copy until the remaining 7 digits are done.
	bne CopyNewHighScore

	lda #$FF
	sta FlaggedHiScore         ; Flag the high score. Score must have changed to get here.

ExitHighScoreOrNot
	rts


; ==========================================================================
; MULTIPLY FROGS CROSSED
;
; Multiply FroggsCrossed times 18 and save to FrogsCrossesIndex, to 
; determine the base entry in the difficulty arrays that control each 
; boat's speed on screen.
;
; Uses A
; -------------------------------------------------------------------------- 
MultiplyFrogsCrossed
	lda FrogsCrossed
	cmp #MAX_FROG_SPEED+1         ; Number of difficulty levels. 0 to 10 OK.  11 not so much
	bcc SkipLimitCrossed
	lda #MAX_FROG_SPEED

SkipLimitCrossed
	asl              ; Times 2
	sta FrogsCrossedIndex
	asl              ; Times 4
	asl              ; Times 8
	asl              ; Times 16
	clc
	adc FrogsCrossedIndex ; Add to self (*2) + (*16) == (*18)
	sta FrogsCrossedIndex ; And Save Times 18

	jsr MakeDifficultyPointers ; Set pointers to the array row for the difficulty values.

	rts


; ==========================================================================
; MAKE DIFFICULTY POINTERS
;
; Get the Address of the start of the current difficulty data.
; These are the BOAT_FRAMES and BOAT_SHIFT base addresses plus the 
; FrogsCrossedIndex. 
; From Here the code can use the FrogRow as Y index and reference the 
; master data by (ZeroPage),Y.
;
; Uses A
; -------------------------------------------------------------------------- 
MakeDifficultyPointers
	lda #<BOAT_FRAMES
	clc
	adc FrogsCrossedIndex
	sta BoatFramesPointer
	lda #>BOAT_FRAMES
	adc #0
	sta BoatFramesPointer+1

	lda #<BOAT_SHIFT
	clc
	adc FrogsCrossedIndex
	sta BoatMovePointer
	lda #>BOAT_SHIFT
	adc #0
	sta BoatMovePointer+1

	rts

	
