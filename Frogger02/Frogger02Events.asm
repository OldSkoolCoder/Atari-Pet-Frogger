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
; Frogger EVENTS
;
; All the routines to run for each screen/state.
; --------------------------------------------------------------------------

; Note that there is no mention in this code for scrolling the credits
; text.  This is entirely handled by the Vertical blank routine.  Every
; display list is the same length and every Display List ends with an LMS
; pointing to the Credit text.  The VBI routine updates the current
; Display List's LMS pointer to the current scroll value.  Since the VBI
; also controls what display is current it always means whatever is on
; Display is guaranteed to have the correct scroll value.  It should seem
; like the credit text is independent of the rest of the display as it will
; update continuously no matter what else is happening.

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


; ==========================================================================
; Event Process TRANSITION TO TITLE
; The setup for Transition to Title will turned on the Title Display.
; Stage 1: Scroll in the Title graphic. (three lines, one at a time.)
; Stage 2: Brighten line 4 luminance.
; Stage 3: Initialize setup for Press Button on Title screen.
; --------------------------------------------------------------------------
EventTransitionToTitle
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne EndTransitionToTitle ; Nope.  Nothing to do.
	lda #TITLE_SPEED         ; yes.  Reset it.
	jsr ResetTimers

	lda EventCounter         ; What stage are we in?
	cmp #1
	bne TestTransTitle2      ; Not the Title Scroll, try next stage

	; === STAGE 1 ===
	; Each line is 40 spaces followed by the graphics.
	; Scroll each one one at a time.
	lda SCROLL_TITLE_LMS0
	cmp #<[TITLE_MEM1+40]
	beq NowScroll2
	inc SCROLL_TITLE_LMS0
	bne EndTransitionToTitle

NowScroll2
	lda SCROLL_TITLE_LMS1
	cmp #<[TITLE_MEM2+40]
	beq NowScroll3
	inc SCROLL_TITLE_LMS1
	bne EndTransitionToTitle

NowScroll3
	lda SCROLL_TITLE_LMS2
	cmp #<[TITLE_MEM3+40]
	beq FinishedNowSetupStage2
	inc SCROLL_TITLE_LMS2
	bne EndTransitionToTitle

FinishedNowSetupStage2
	lda #2
	sta EventCounter
	bne EndTransitionToTitle

	; === STAGE 2 ===
	; Ramp up luminance of line 4.

TestTransTitle2
	cmp #2
	bne TestTransTitle3

	lda COLPF1_TABLE+3
	cmp #$0E               ; It is maximum brightness?
	beq FinishedNowSetupStage3
	inc COLPF1_TABLE+3
	bne EndTransitionToTitle

FinishedNowSetupStage3
	lda #3
	sta EventCounter
	bne EndTransitionToTitle

	; === STAGE 3 ===
	; Set Up Press Any Button  and get ready to runtitle.

TestTransTitle3
	cmp #3
	bne EndTransitionToTitle  ; Really shouldn't get to that point

	lda #SCREEN_START         ; Yes, change to event to start new game.
	sta CurrentScreen

	lda #BLINK_SPEED          ; Text Blinking speed for prompt on Title screen.
	jsr ResetTimers

EndTransitionToTitle
	lda CurrentScreen

	rts


; ==========================================================================
; Event process SCREEN START/NEW GAME
; Clear the Game Scores and get ready for the Press A Button prompt.
;
; Sidebar: This is oddly inserted between Transition to Title and the
; Title to finish internal initialization per game, due to doofus-level
; lack of design planning, blah blah.
; The title screen has already been presented by Transition To Title.
; --------------------------------------------------------------------------
EventScreenStart            ; This is New Game and Transition to title.

	jsr ClearGameScores     ; Zero the score.  And high score if not set.
	jsr CopyScoreToScreen   ; And put into screen memory.

	jsr ClearSavedFrogs     ; Erase the saved frogs from the screen. (Zero the count)
	jsr PrintFrogsAndLives  ; Update the screen memory.

	lda #SCREEN_TITLE       ; Next step is operating the title screen input.
	sta CurrentScreen

	rts


; ==========================================================================
; Event Process TITLE SCREEN
; The activity on the title screen is
; 1) Blink Prompt for ANY key.
; 2) Wait for joystich button.
; 3) Setup for next transition.
; --------------------------------------------------------------------------
EventTitleScreen
	jsr RunPromptForButton     ; Blink Prompt to press ANY key.  check button.
	beq EndTitleScreen         ; Nothing pressed, done with title screen.

ProcessTitleScreenInput        ; Button pressed. Prepare for the screen transition.
	jsr SetupTransitionToGame

EndTitleScreen
	lda CurrentScreen

	rts


; ==========================================================================
; Event Process TRANSITION TO GAME SCREEN
; The Activity in the transition area, based on timer.
; Stage 1) Fade out text lines  from bottom to top.
;          Decrease COLPF1 brightness from bottom   to top.
;          When COLPF1 reaches 0 change COLPF2 to COLOR_BLACK.
; Stage 2) Setup Game screen display.  Set all colors to black.
; Stage 3) Fade in text lines from top to bottom.
;          Decrease COLPF1 brightness from top to bottom.
;          When COLPF1 reaches 0 change COLPF2 to COLOR_BLACK.
; --------------------------------------------------------------------------
EventTransitionToGame
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne EndTransitionToGame  ; Nope.  Nothing to do.
	lda #TITLE_WIPE_SPEED    ; yes.  Reset it.
	jsr ResetTimers

	lda EventCounter         ; What stage are we in?
	cmp #1
	bne TestTransGame2       ; Not the fade out, try next stage

	; === STAGE 1 ===
	; Fade out text lines  from bottom to top.
	; Decrease COLPF1 brightness.
	; When COLPF1 reaches 0 change COLPF2 to COLOR_BLACK.
	; Decrement twice here, because once was not fast enough.
	; The fade and wipe was becoming boring.
	ldx EventCounter2
	lda COLPF1_TABLE,x
	beq ZeroCOLPF2
	dec COLPF1_TABLE,x
	beq ZeroCOLPF2
	dec COLPF1_TABLE,x
	bne EndTransitionToGame
ZeroCOLPF2
	lda #0
	sta COLPF2_TABLE,x

	dec EventCounter2
	bpl EndTransitionToGame

	; Finished stage 1, now setup Stage 2
	lda #2
	sta EventCounter
	inc EventCounter2 ; return to 0.
	beq EndTransitionToGame

	; === STAGE 2 ===
	; Setup Game screen display.
	; Set all colors to black.
TestTransGame2
	cmp #2
	bne TestTransGame3

	; Reset the game screen positions, Scrolling LMS offsets
	jsr ResetGamePlayfield

	lda #DISPLAY_GAME        ; Tell VBI to change screens.
	jsr ChangeScreen         ; Then copy the color tables.

	jsr ZeroCurrentColors    ; Need the screen to start black.

	; Finished stage 2, now setup Stage 3
	lda #3
	sta EventCounter
	lda #0
	sta EventCounter2 ; return to 0.
	beq EndTransitionToGame

	; === STAGE 3 ===
	; Fade in text lines from top to bottom.
	; change COLPF2 to target color.
	; Increase COLPF1 brightness.
	; When COLPF1 reaches target move to next line.
	; Increment twice here, because once was not fast enough.
	; The fade and wipe was becoming boring.
TestTransGame3
	cmp #3
	bne EndTransitionToGame

	ldx EventCounter2
	lda GAME_BACK_COLORS,x ; (redundantly) copy the background color.
	sta COLPF2_TABLE,x

	lda COLPF1_TABLE,x
	cmp GAME_TEXT_COLORS,x
	beq TransGameNextLine

	inc COLPF1_TABLE,x

	lda COLPF1_TABLE,x
	cmp GAME_TEXT_COLORS,x
	beq TransGameNextLine

	inc COLPF1_TABLE,x
	bne EndTransitionToGame

TransGameNextLine
	inc EventCounter2
	lda EventCounter2
	cmp #25
	bne EndTransitionToGame

	; Finished stage 3, now go to the main event.
	lda #SCREEN_START         ; Yes, change to event to start new game.
	sta CurrentScreen

	lda #BLINK_SPEED          ; Text Blinking speed for prompt on Title screen.
	jsr ResetTimers

	jsr SetupGame

EndTransitionToGame
	lda CurrentScreen

	rts


; ==========================================================================
; Event Process GAME SCREEN
; Play the game.
; 1) When the input timer allows, get controller input.
; 2) Evaluate frog Movement
; 2.a) Determine exit to Win screen
; 2.b) Determine exit to Dead screen.
; 3) When the animation timer expires, shift the boat rows.
; 3.a) Determine if frog hits screen border to go to Dead screen.
; As a timer based pattern the controller input is first.
; Joystick input updates the frog's logical and physical position
; and updates screen memory.
; The animation update forces an automatic logical movement of the
; frog as the frog moves with the boats and remains static relative
; to the boats.
; --------------------------------------------------------------------------
EventGameScreen
; ==========================================================================
; GAME SCREEN - Keyboard Input Section
; --------------------------------------------------------------------------
	jsr CheckInput           ; Get cooked stick or trigger if timer permits.
	beq CheckForAnim         ; Nothing pressed, Skip the input section.

	jsr RemoveFrogOnScreen   ; Remove the frog from the screen (duh)

ProcessJoystickInput         ; Reminder: Input Bits: "0 0 0 Trigger Right Left 0 Up"
	lda InputStick           ; Get the cooked joystick state... 

UpStickTest
	ror                      ; Roll out low bit. UP
	bcc LeftStickTest        ; No bit. Try Left.

	jsr FrogMoveUp           ; Yes, go do UP. Subtract from FrogRow.
	beq DoSetupForFrogWins   ; No more rows to cross. Update to frog Wins!
	bne SaveNewFrogLocation  ; Row greater than 0.  Evaluate good/bad position.

LeftStickTest
	ror                      ; Roll out empty bit. DOWN (it is unused)
	ror                      ; Roll out low bit. LEFT
	bcc RightStickTest       ; No bit. Try Right.

	ldy FrogColumn           ; Get "logical" apparent screen position.
	beq SaveNewFrogLocation  ; Already 0. Can't move left. Redraw frog.
	dey                      ; Move Y to left.
	sty FrogColumn
	bpl SaveNewFrogLocation  ; Place frog on screen

RightStickTest
	ror                      ; Roll out low bit. RIGHT
	bcc ReplaceFrogOnScreen  ; No bit.  Replace Frog on screen.  Try boat animation.

	ldy FrogColumn           ; Get "logical" apparent screen position.
	cpy #39                  ; Is it at limit?
	beq SaveNewFrogLocation  ; At limit. Can't move right. Redraw frog.
	iny                      ; Move Y to right.
	sty FrogColumn

; Row greater than 0.  Evaluate good/bad jump.
SaveNewFrogLocation
	jsr WhereIsThePhysicalFrog ; Update Frog Real Positions and the LastCharacter found there.

; These are all safe characters...
; I_SEATS   = $0B ; +, boat seats

; I_BEACH1  = $0D ; -, beach rocks
; I_BEACH2  = $0F ; /, beach rocks
; I_BEACH3  = $1B ; ;, beach rocks
; I_SPACE   = $00 ; space, also safe beach spot.

; Will the Pet Frog land on the Beach or a seat in the boat?
	cmp #I_SPACE             ; = $00 ; space, also safe beach spot.
	beq ReplaceFrogOnScreen  ; The beach is safe. Draw the frog.
	cmp #I_BEACH1            ; = $02 ;  beach rocks
	beq ReplaceFrogOnScreen  ; The beach is safe. Draw the frog.
	cmp #I_BEACH2            ; = $0F ;  beach rocks
	beq ReplaceFrogOnScreen  ; The beach is safe. Draw the frog.
	cmp #I_BEACH3            ; = $1B ;  beach rocks
	beq ReplaceFrogOnScreen  ; The beach is safe. Draw the frog.
	cmp #I_SEATS             ; I_SEATS   = $0B ; +, boat seats
	beq ReplaceFrogOnScreen  ; Yes.  Safe!  Draw the frog.

; Safe locations have been accounted.
; Wherever the Frog will land now, it is Baaaaad.
DoSetupForYerDead
	jsr SetupTransitionToDead
	bne EndGameScreen        ; last action in function is lda/sta a non-zero value.

	; Safe location at the far beach.  the Frog is saved.
DoSetupForFrogWins
	jsr SetupTransitionToWin
	bne EndGameScreen        ; last action in function is lda/sta a non-zero value.

; Replace frog on screen, continue with boat animation.
ReplaceFrogOnScreen
	jsr SetFrogOnScreen ; redraw the frog where it belongs


; ==========================================================================
; GAME SCREEN - Screen Animation Section
; --------------------------------------------------------------------------
CheckForAnim
	lda AnimateFrames        ; Does the timer allow the boats to move?
	bne EndGameScreen        ; Nothing at this time. Exit.

	jsr SetBoatSpeed         ; Reset timer for animation based on number of saved frogs.

	jsr AnticipateFrogDeath  ; Will the frog die when the boat moves?
	bne DoSetupForYerDead    ; Shrodinger says apparently so.  dead frog.

	jsr AnimateBoats         ; Move the boats around.
	jsr AutoMoveFrog         ; Move the frog relative to boats.

EndGameScreen
	lda CurrentScreen

	rts


; ==========================================================================
; Event Process TRANSITION TO WIN
; The Activity in the transition area, based on timer.
; 1) wipe screen from top to middle, and bottom to middle
; 2) Display the Frogs SAVED!
; 3) Setup to do the Win screen event.
; --------------------------------------------------------------------------
EventTransitionToWin
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne EndTransitionToWin   ; Nope.  Nothing to do.

	lda #WIN_FILL_SPEED      ; yes.  Reset it. (60 / 6 == 10 updates per second)
	jsr ResetTimers

;	ldx EventCounter         ; Row number for text.
;	cpx #13                  ; From 2 to 12, erase from top to middle
;	beq DoSwitchToWins       ; When at 13 then fill screen is done.

;	ldy #PRINT_BLANK_TXT_INV ; inverse blanks.
;	jsr PrintToScreen

;	lda #26                  ; Subtract Row number for text from 26 (26-2 = 24)
;	sec
;	sbc EventCounter
;	tax

;	jsr PrintToScreen        ; And print the inverse blanks again.

;	inc EventCounter
;	bne EndTransitionToWin   ; Nothing else to do here.

; Clear screen is done.   Display the big prompt.
DoSwitchToWins
;	jsr PrintWinFrogGfx      ; Copy the big text announcement to screen

	jsr SetupWin             ; Setup for Wins screen (which only waits for input )

EndTransitionToWin
	lda CurrentScreen

	rts


; ==========================================================================
; Event Process WIN SCREEN
; The Activity in the transition area, based on timer.
; Blink Prompt for ANY key.
; Wait for Key.
; Setup for next transition.
; --------------------------------------------------------------------------
EventWinScreen
	jsr RunPromptForButton     ; Blink Prompt to press ANY key.  check button.
	beq EndWinScreen           ; Nothing pressed, done with title screen.

ProcessWinScreenInput          ; a key is pressed. Prepare for the screen transition.
	jsr SetupTransitionToGame

EndWinScreen
	lda CurrentScreen          ; Yeah, redundant to when a key is pressed.

	rts


; ==========================================================================
; Event Process TRANSITION TO DEAD
; The Activity in the transition area, based on timer.
; 0) On Entry, wait (1.5 sec) to observe splattered frog. (timer set in 
;    the setup event)
; 1) Black background for all playfield lines, turn frog's line red.
; 2) Fade playfield text to black.
; 2) Launch the Dead Frog Display.
; --------------------------------------------------------------------------
EventTransitionToDead
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne EndTransitionToDead  ; Nope.  Nothing to do.
	lda #DEAD_FADE_SPEED     ; yes.  Reset it. (fade speed)
	jsr ResetTimers

	lda EventCounter         ; What stage are we in?
	cmp #1
	bne TestTransDead2       ; Not the Playfield blackout, try next stage

; ======== Stage 1 ========
; Black the playfield background.   Make frog line red.
	ldx #18

LoopDeadToBlack
	cpx FrogRow             ; Is X the same as Frog Row?
	bne SkipRedFrog         ; No.  Skip setting row to red.
	lda #COLOR_PINK         ; Really, it is like red.
	bne SkipBlackFrog       ; Skip over choosing black.
SkipRedFrog
	lda #COLOR_BLACK        ; Choose black instead.
SkipBlackFrog
	sta COLPF2_TABLE+3,x    ; Set playfield row to black (or red)
	dex                     ; Next row.
	bpl LoopDeadToBlack     ; 18 to 0...

	; Do the empty green grass rows, too.  Logically, the frog cannot die 
	; on row 18 or row 0, so we must know that A still contains #BLACK.  
	sta COLPF2_TABLE+2
	sta COLPF2_TABLE+21

	lda #2
	sta EventCounter         ; Identify Stage 2
	lda #$18
	sta EventCounter2        ; Prep the instance count.
	; Fade speed was set earlier. 
	bne EndTransitionToDead  ; Nothing else to do.

; ======== Stage 2 ========
; Fade the text out on all playfield lines EXCEPT the frog line.
TestTransDead2
	ldx #18

LoopDeadFadeText
	cpx FrogRow             ; Is X the same as Frog Row?
	beq SkipDeadFade        ; Yes.  Skip fading this row.
	ldy COLPF1_TABLE+3,x    ; Get text color. 
	beq SkipDeadFade        ; If it is 0 now, then do not decrement.
	dey
	sty COLPF1_TABLE+3,x    ; Save text color. 
SkipDeadFade
	dex                     ; Next row.
	bpl LoopDeadFadeText    ; 18 to 0...

	; Fade the empty green grass rows, too.
	ldy COLPF1_TABLE+2
	beq SkipFadeGrass1
	dey 
	sty COLPF1_TABLE+2
SkipFadeGrass1
	ldy COLPF1_TABLE+21
	beq SkipFadeGrass2
	dey 
	sty COLPF1_TABLE+21
SkipFadeGrass2

; Control loop, exit from stage 2
	dec EventCounter2        ; Decrement counter.
	bpl EndTransitionToDead  ; It was not zero before.  So, just exit here. 

TestTransDead3 ; Used up the fading iterations. Go to Dead screen now. 
	jsr SetupDead            ; Setup for Dead screen (wait for input loop)

EndTransitionToDead
	lda CurrentScreen

	rts


; ==========================================================================
; Event Process DEAD SCREEN
; The Activity in the transition area, based on timer.
;
; --------------------------------------------------------------------------
EventDeadScreen
	jsr RunPromptForButton     ; Blink Prompt to press ANY key.  check button.
	bne ProcessDeadScreenInput ; Button pressed.  Run the dead exit section..

	; While there is no input, then animate colors.
	lda AnimateFrames        ; Did animation counter reach 0 ?
	bne EndDeadScreen        ; Nope.  Nothing to do.
	lda #DEAD_CYCLE_SPEED    ; yes.  Reset it.
	jsr ResetTimers

	ldx EventCounter
	inx
	cpx #20
	bne SkipZeroDeadCycle
	ldx #0
SkipZeroDeadCycle
	stx EventCounter

	ldy #



ProcessDeadScreenInput         ; a key is pressed. Prepare for the next screen.
	lda NumberOfLives          ; Have we run out of frogs?
	beq SwitchToGameOver       ; Yes.  Game Over.

	jsr SetupTransitionToGame  ; Go back to game screen.
	bne EndDeadScreen

SwitchToGameOver
	jsr SetupTransitionToGameOver

EndDeadScreen
	lda CurrentScreen          ; Yeah, redundant to when a key is pressed.

	rts


DEAD_COLOR_SINE 
	.byte COLOR_RED_ORANGE+7, COLOR_RED_ORANGE+9, COLOR_RED_ORANGE+11,COLOR_RED_ORANGE+13
	.byte COLOR_RED_ORANGE+14,COLOR_RED_ORANGE+14,COLOR_RED_ORANGE+14,COLOR_RED_ORANGE+13
	.byte COLOR_RED_ORANGE+11,COLOR_RED_ORANGE+9, COLOR_RED_ORANGE+7, COLOR_RED_ORANGE+5
	.byte COLOR_RED_ORANGE+3, COLOR_RED_ORANGE+1, COLOR_RED_ORANGE+0, COLOR_RED_ORANGE+0
	.byte COLOR_RED_ORANGE+0, COLOR_RED_ORANGE+1, COLOR_RED_ORANGE+3, COLOR_RED_ORANGE+5
	.byte COLOR_RED_ORANGE+7, COLOR_RED_ORANGE+9, COLOR_RED_ORANGE+11,COLOR_RED_ORANGE+13
	.byte COLOR_RED_ORANGE+14,COLOR_RED_ORANGE+14,COLOR_RED_ORANGE+14,COLOR_RED_ORANGE+13
	.byte COLOR_RED_ORANGE+11,COLOR_RED_ORANGE+9, COLOR_RED_ORANGE+7, COLOR_RED_ORANGE+5
	.byte COLOR_RED_ORANGE+3, COLOR_RED_ORANGE+1, COLOR_RED_ORANGE+0, COLOR_RED_ORANGE+0
	.byte COLOR_RED_ORANGE+0, COLOR_RED_ORANGE+1, COLOR_RED_ORANGE+3, COLOR_RED_ORANGE+5

	
; ==========================================================================
; Event Process TRANSITION TO OVER
; The Activity in the transition area, based on timer.
; 1) Progressively reprint the credits on lines from the top of the screen
; to the bottom.
; 2) follow with a blank line to erase the highest line of trailing text.
; --------------------------------------------------------------------------
EventTransitionGameOver
	lda AnimateFrames          ; Did animation counter reach 0 ?
	bne EndTransitionGameOver  ; Nope.  Nothing to do.

;	dec EventCounter                ; Decrement pass counter.
;	beq DoTransitionToGameOverPart2 ; When this reaches 0 finish the screen

	lda #RES_IN_SPEED          ; Running animation loop. Reset timer.
	jsr ResetTimers

	; Randomize display of Game Over
;	ldy #16                    ; Do 16 random characters per pass.
GetRandomX
;	lda RANDOM                 ; Get a random value.
;	and #$7F                   ; Mask it down to 0 to 127 value
;	cmp #118                   ; Is it more than 118?
;	bcs GetRandomX             ; Yes, retry it.
;	tax                        ; The index into the image and screen buffers.
;	lda GAME_OVER_GFX,x        ; Get image byte
;	beq SkipGameOverEOR        ; if this is 0 just copy to screen
;	eor SCREENMEM+400,x        ; Exclusive Or with screen
SkipGameOverEOR
;	sta SCREENMEM+400,x        ; Write to screen
;	dey
;	bne GetRandomX             ; Do another random character in this turn.
;	beq EndTransitionGameOver

	; Finish up.
DoTransitionToGameOverPart2
;	jsr PrintGameOverGfx       ;  Draw Big Game Over

	jsr SetupGameOver

EndTransitionGameOver
	lda CurrentScreen

	rts


; ==========================================================================
; Event Process GAME OVER SCREEN
; The Activity in the transition area, based on timer.
;
; --------------------------------------------------------------------------
EventGameOverScreen
	jsr RunPromptForButton     ; Blink Prompt to press ANY key.  check button.
	beq EndGameOverScreen      ; Nothing pressed, done with title screen.

ProcessGameOverScreenInput     ; a key is pressed. Prepare for the screen transition.
	jsr SetupTransitionToTitle

EndGameOverScreen
	lda CurrentScreen          ; Yeah, redundant to when a key is pressed.

	rts


