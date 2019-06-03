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
; Miscellaneous:
; Clear game scores.
; Add 500 to game score (and increment saved Frogs)
; Add 10 to game score.
; Determine if current score is high score
; Move the frog up a row.
; Automatic, logical frog horizontal movement when boats move.
; Set boat speed based on number of frogs saved.
;
; --------------------------------------------------------------------------


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

	lda #3              ; Reset number of
	sta NumberOfLives   ; lives to 3.

	lda #0
	sta FrogsCrossed      ; Zero the number of successful crossings.
	sta FrogsCrossedIndex ; And the index lookup for the boat/row settings.
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
	jsr MultiplyFrogsCrossed ; Multiply by 18 to get the new index base.

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
; FROG MOVE UP
;
; Add 10 to the score.
; Decrement the Row counter.
; Set new Frog screen position.
; Update Playfield pointer based from table based on row number.
;
; On return BEQ means the frog has reached safety.
; Thus BNE means continue game.
;
; Uses A, X
; --------------------------------------------------------------------------
FrogMoveUp
	jsr Add10ToScore

	sec
	lda FrogPMY    ; Old Frog vertical screen position.
	sbc #9         ; 9 scan lines per row.
	sta FrogNewPMY ; New location is one row higher.

	dec FrogNewRow

	ldx FrogNewRow ; Make sure CPU flags reflect X = 0 or !0

	rts


	; This has no direct purpose since the frog is not in screen memory.
	; But, position adjustment/calculation is a thing for the P/M frog
	; which is similar to this function.

; ==========================================================================
; Determine the new, real memory location of the frog.
;
; Given the row, logical X coordinate, and scrolling factor of the row
; determine where the frog really is in screen memory.
; Note that FrogMoveUp established the pointer to the frog's row.
; Two positions need to be calculated separated by 40 bytes.  
; If the first calculation produces a number less than 40, then the 
; second position is +40.   Otherwise the second position is -40
; --------------------------------------------------------------------------
;WhereIsThePhysicalFrog
;;	clc
;;;	lda FrogColumn          ; Logical position (where visible on screen)
;;	ldx FrogRow             ; Get the current row number.
;;	ldy MOVING_ROW_STATES,x ; Get the movement flag for the row.
;;	beq FrogOnTheBeach      ; Zero is no scrolling, so no math.
;;	bpl FrogOnBoatRight     ; +1 is boats going right

;;	; Determine frog on boats going left.
;;	adc CurrentLeftOffset      ; Add scroll position to the logical column
;;	bcc NormalizeFrogPositions ; Calculate second frog position

;FrogOnBoatRight
;;;	adc CurrentRightOffset

;NormalizeFrogPositions
;;;	sta FrogRealColumn1
;;	cmp #40                   ; Where is the first calculated position
;;	bcs PhysicalFrogMinus40   ; Greater than, equal to 40, so subtract 40 

;;	; BCC == Less than 40, so add 40. 
;;	adc #40
;;	bpl SaveSecondPosition    ; We know the maximum value is 79

;PhysicalFrogMinus40           ; Got here due to BCS, so no SEC needed.
;;	sbc #40 
;;	bpl SaveSecondPosition

;FrogOnTheBeach                ; No alternate position for beach rows.  Trick the
;;;	sta FrogRealColumn1       ; future use by keeping the same value for both...

;SaveSecondPosition
;;;	sta FrogRealColumn2       ; 

;ExitWhereIsThePhysicalFrog
;;	jsr GetScreenMemoryUnderFrog ; Update the cached character where the frog resides.

;	rts


; This does not have direct purpose.
; VBI detects the conditions for Frog Death: 
; 1) Frog is on a boat row, and there is no collision with 
;    the special boat color.
; 2) Frog is on a boat row, and the automatic movement would move
;    the frog past the minimum or maximum screen position.
; When these occur the VBI sets FrogSafety.
; Main is expected to observe FrogSafety and engage the Frog Death.
; 
; ==========================================================================
; ANTICIPATE FROG DEATH
; If the boat moves will the frog die?
;
; Due to the change to scrolling by LMS the frog must be shown dead in its
; current position BEFORE the boat would move it off screen.
; Therefore the game logic tilts a little from collision detection to
; collision avoidance.
;
; Data to drive AutoMoveFrog routine.
; Byte value indicates direction of row movement.
; 0   = Beach line, no movement.
; 1   = first boat/river row, move right
; 255 = second boat/river row, move left.
;
; FrogSafety (and Z flag) indicates frog is now dead.
; --------------------------------------------------------------------------
;AnticipateFrogDeath
;	ldy FrogColumn          ; Logical position (where visible on screen)
;	ldx FrogRow             ; Get the current row number.
;	lda MOVING_ROW_STATES,x ; Get the movement flag for the row.
;	beq ExitFrogNowAlive    ; Is it 0?  Beach. Nothing to do.  Bail.
;	bpl CheckFrogGoRight    ; is it $1?  then check right move.

; Check Frog Go Left
;	cpy #0
;	bne ExitFrogNowAlive      ; Not at limit means frog is still alive.
;	beq FrogDemiseByWallSplat ; At zero means frog will leave screen.

;CheckFrogGoRight
;	cpy #39                   ; 39 is limit or frog would leave screen
;	bne ExitFrogNowAlive      ; Not at limit means frog is still alive.

;FrogDemiseByWallSplat
;	inc FrogSafety            ; Schrodinger's frog is known to be dead.

;;ExitFrogNowAlive
;	lda FrogSafety            ; branching here is no change, so we assume frog is alive.
;	rts


; This is N/A for the game.
; The VBI now moves the frog with the boats.
; Main only need wait for FrogSafety to be flagged.
; ==========================================================================
; AUTO MOVE FROG
; Process automagical movement on the frog in the moving boat lines
;
; The code must call AnticipateFrogDeath first, so it knows the auto
; movement will be safe.
;
; Data to drive AutoMoveFrog routine.
; Byte value indicates direction of row movement.
; 0   = Beach line, no movement.
; 1   = first boat/river row, move right
; 255 = second boat/river row, move left.
; --------------------------------------------------------------------------
;AutoMoveFrog
;	ldy FrogColumn          ; Logical position (where visible on screen)
;	ldx FrogRow             ; Get the current row number
;	lda MOVING_ROW_STATES,x ; Get the movement flag for the row.
;	beq ExitAutoMoveFrog    ; Is it 0?  Nothing to do.  Bail.
;	bpl AutoFrogRight       ; is it $1?  then automatic right move.

; Auto Frog Left
;	dec FrogColumn            ; It is not 0, so move Frog left one character
;	rts                       ; Done, successful move.

;AutoFrogRight
;	inc FrogColumn            ; Move Frog right one character

;ExitAutoMoveFrog
	rts                       ; Done, successful move.


; This is managed by the VBI moving the boats.
; Whatever the value of Frogs crossed is sets the boat movement
; speed when the next frame counter is acquired for the boat row.
; ==========================================================================
; SET BOAT SPEED
; Set the animation timer for the game screen based on the
; number of frogs that have been saved.
;
; NOTE ANIMATION_FRAMES is in the TimerStuff.asm file.
; A  and  X  will be saved.
; --------------------------------------------------------------------------
;SetBoatSpeed

;	mRegSaveAX

;	ldx FrogsCrossed
;	cpx #MAX_FROG_SPEED+1         ; 0 to 10 OK.  11 not so much
;	bcc FrogsCrossedIsOK
;	ldx #MAX_FROG_SPEED

;FrogsCrossedIsOK
;	lda BOAT_FRAMES,x             ; Reset Frame counter based on number of frogs saves.
;	sta BoatFrames

;	jsr ResetTimers

;	mRegRestoreAX

	rts
