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
; GAME SUPPORT
;
; Miscellaneous:
; Prompt for ANY Key.
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
; TOGGLE BUTTON PROMPT
; Set blinking prompt.
;
; On entry the CPU flags should indicate current toggle state:
;   Z or 0   v   !Z or !0
;
; If toggle 0, then dark background, light text.
; If toggle 1, then light background and dark text.
; 
; Do not allow color black, since the credits are always black.
; --------------------------------------------------------------------------
ToggleButtonPrompt
	bne PromptLightAndDark ; 1 = Light background and dark text

; Therefore, Prompt Dark and Light
PromptDarkAndLight
	lda RANDOM             ; A random color
	and #%11110000         ; Mask out the lumninance for Dark.
	beq PromptDarkAndLight ; Do again if black/color 0 turned up
	sta COLPF2_TABLE+23    ; Set background
	lda #$0C               ; Light text
	sta COLPF1_TABLE+23    ; Set text.
	rts

PromptLightAndDark
	lda RANDOM             ; A random color
	and #%11110000         ; Mask out the lumninance for Dark.
	beq PromptLightAndDark ; Do again if black/color 0 turned up
	ora #$0C               ; Light Background
	sta COLPF2_TABLE+23    ; Set background
	lda #$00               ; Dark text
	sta COLPF1_TABLE+23    ; Set text.
	rts


; ==========================================================================
; RUN PROMPT FOR BUTTON
; Maintain blinking timer.
; Update/blink text on line 23.
; Return 0/BEQ when the any key is not pressed.
; Return !0/BNE when the any key is pressed.
;
; On Exit:
; A  contains key press.
; CPU flags are comparison of key value to $FF which means no key press.
; --------------------------------------------------------------------------
RunPromptForButton
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne CheckButton          ; no, then is a key pressed?

	jsr ToggleFlipFlop       ; Yes! Let's toggle the flashing prompt
	jsr ToggleButtonPrompt   ; Set prompt based on CPU flags from Toggle bit.

ResetPromptBlinking
	lda #BLINK_SPEED         ; Text Blinking speed for prompt on Title screen.
	jsr ResetTimers

CheckButton
	jsr CheckInput           ; Get an input if timer permits. Non Zero is input.

	rts


; ==========================================================================
; Clear the score digits to zeros.
; That is, internal screen code for "0"
; If a high score is flagged, then do not clear high score.
; other one-time things at game start.
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
	sta FrogsCrossed    ; Zero the number of successful crossings.

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

	inc FrogsCrossed  ; Add to frogs successfully crossed the rivers.

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
; Add 10 to the score, move screen memory pointer up one line, and
; finally decrement row counter.
; (packed into a callable routine to shorten the caller's code.)
;
; On return BEQ means the frog has reached safety.
; Thus BNE means continue game.
;
; Uses A
; --------------------------------------------------------------------------
FrogMoveUp
	jsr Add10ToScore

	lda FrogLocation     ; subtract $28/40 (dec) from
	sec                  ; the address pointing to
	sbc #$28             ; the frog.
	sta FrogLocation
	bcs DecrementRows    ; If carry is still set, skip high byte decrement.
	dec FrogLocation+1   ; Smartly done instead of lda/sbc/sta.

DecrementRows            ; decrement number of rows.
	dec FrogRow
	ldx FrogRow

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
	ldy FrogColumn
	ldx FrogRow             ; Get the current row number.
	lda MOVING_ROW_STATES,x ; Get the movement flag for the row.
	beq ExitAutoMoveFrog    ; Is it 0?  Nothing to do.  Bail.
	bpl AutoFrogRight       ; is it $1?  then automatic right move.

; Auto Frog Left
	cpy #0
	beq FrogDemiseByWallSplat ; at zero means we hit the wall.
	dec FrogColumn            ; It is not 0, so move Frog left one character
	rts                       ; Done, successful move.

AutoFrogRight
	cpy #39                   ; 39 is limit
	beq FrogDemiseByWallSplat ; at limit means we hit the wall
	inc FrogColumn            ; Move Frog right one character
	rts                       ; Done, successful move.

FrogDemiseByWallSplat         ; Ran out of river.   Yer Dead!
	inc FrogSafety            ; Schrodinger's frog is known to be dead.

ExitAutoMoveFrog
	rts


MOVING_ROW_STATES
	.rept 6                 ; 6 occurrences of
		.BYTE 0, 1, $FF     ; Beach (0), Right (1), Left (FF) directions.
	.endr
		.BYTE 0             ; starting position on safe beach


; ==========================================================================
; SET BOAT SPEED
; Set the animation timer for the game screen based on the
; number of frogs that have been saved.
;
; NOTE ANIMATION_FRAMES is in the TimerStuff.asm file.
; A  and  X  will be saved.
; --------------------------------------------------------------------------
SetBoatSpeed

	mRegSaveAX

	ldx FrogsCrossed          ; How many frogs crossed?
	cpx #MAX_FROG_SPEED+1     ; Limit this index from 0 to 14.
	bcc GetSpeedByWayOfFrogs  ; Anything bigger than that
	ldx #MAX_FROG_SPEED       ; must be truncated to the limit.

GetSpeedByWayOfFrogs
	lda ANIMATION_FRAMES,x    ; Set timer for animation based on frogs.
	jsr ResetTimers

	mRegRestoreAX

	rts

