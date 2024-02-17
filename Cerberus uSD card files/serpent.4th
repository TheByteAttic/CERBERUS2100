\ Snake type game in Forth for Agon Light.
\
\ Written by Lennart Benschop: 2023-06-08
\ Copyright 2023 Lennart Benschop, released under GPLv3.
\ Originally submitted to Olimex WPC June 2023
\ 2023-07-02: Adapted to run under both Agon FORTHs.
\ 
\ How to run:
\ load forth.bin
\ run . serpent.4th

FORGET MARKER CREATE MARKER
DECIMAL

VARIABLE SEED 
\G Seed random generator from time.    
: RANDOMIZE	0 ." Press any key." CR BEGIN 1+ KEY? UNTIL KEY DROP SEED ! ;


: RAND ( n1 --- n2)
\G A simple random generator return a number in range 0..n1-1
  SEED @ 3533 * 433 + DUP SEED ! UM* NIP ;

: WAITFRAME ( --- )
    HALT
;

27 CONSTANT PIT-HEIGHT
38 CONSTANT PIT-WIDTH

6 CONSTANT FOOD-ITEMS

\ Playing field, creates byte codes of every item on the screen.
\ 0 = empty, 1=food, 2=serpent, 3=wall.
CREATE PLAYING-FIELD PIT-WIDTH 2+ PIT-HEIGHT 2+  * ALLOT

4096 CONSTANT MAX-LEN \ The absolute maximum length our snake could have.
\ Power of 2
MAX-LEN 1- CONSTANT IDX-MASK \ So we can mask index into the array.

CREATE SNAKE-POSITIONS MAX-LEN 2* ALLOT
\ Array containing x,y positions of each segment of the snake.
\ Pairs of x,y coordinates are sometimes read as one 16-bit number to
\ compare them in one operation.
VARIABLE HEAD-IDX 
VARIABLE TAIL-IDX 
VARIABLE ORIENTATION \ Direction in which snake is moving.
\ 0 = to the right.
\ 1 = to the left
\ 2 = up
\ 3 = down

: UDG ( charcode ---)
    \ Defining word for a user defined graphic that automatically draws itself.
    \ in the desired colour. After defining you have to allot 8 bytes of the
    \ character bitmap using C,
  CREATE 0 C, C,
  DOES> DUP C@ 0= \ character was not yet programmed.
    IF  
	DUP 1+ C@ \ get desired char code.
	OVER C! \ store it at 0 position.
	DUP 2+ OVER C@ 8 * $F000 + 8 CMOVE \ Store the UDG bytes in RAM
    THEN
    C@ EMIT
;

26 UDG EMPTY \ will be green
$00 C, $00 C, $00 C, $18 C, $18 C, $00 C, $00 C, $00 C,
29 UDG FOOD \ will be yellow
$18 C, $3C C, $7E C, $7E C, $7E C, $7E C, $3C C, $18 C,
31 UDG WALL \ wull be magenta
$7E C, $7E C, $7E C, $00 C, $E7 C, $E7 C, $E7 C, $00 C,
\ All remaining UDGs are segments of the serpent (white).
131 UDG HORIZ
$00 C, $FF C, $FF C, $E7 C, $E7 C, $FF C, $FF C, $00 C,
132 UDG VERT
$7E C, $7E C, $7E C, $66 C, $66 C, $7E C, $7E C, $7E C,
133 UDG TAIL-LEFT
$00 C, $03 C, $1F C, $7F C, $7F C, $1F C, $03 C, $00 C,
134 UDG TAIL-RIGHT
$00 C, $C0 C, $F8 C, $FE C, $FE C, $F8 C, $C0 C, $00 C,
135 UDG TAIL-UP
$00 C, $18 C, $18 C, $3C C, $3c C, $3C C, $7E C, $7E C,
136 UDG TAIL-DOWN
$7E C, $7E C, $3C C, $3C C, $3C C, $18 C, $18 C, $00 C,
137 UDG HEAD-LEFT
$18 C, $3F C, $E7 C, $FF C, $FF C, $E7 C, $3F C, $18 C,
138 UDG HEAD-RIGHT
$18 C, $FC C, $E7 C, $FF C, $FF C, $E7 C, $FC C, $18 C,
139 UDG HEAD-UP
$3C C, $3C C, $7E C, $DB C, $DB C, $7E C, $7E C, $7E C,
140 UDG HEAD-DOWN
$7E C, $7E C, $7E C, $DB C, $DB C, $7E C, $3C C, $3C C,
141 UDG TOP-LEFT
$00 C, $3F C, $7F C, $67 C, $67 C, $7F C, $7F C, $7E C,
142 UDG TOP-RIGHT
$00 C, $FC C, $FE C, $E6 C, $E6 C, $FE C, $FE C, $7E C,
143 UDG BOTTOM-LEFT
$7E C, $7F C, $7F C, $67 C, $67 C, $7F C, $3F C, $00 C,
144 UDG BOTTOM-RIGHT
$7E C, $FE C, $FE C, $E6 C, $E6 C, $FE C, $FC C, $00 C,

VARIABLE SCORE
: SHOW-SCORE 15 29 AT-XY
    ." SCORE: " SCORE @ 4 .R ;

: >PLAYFIELD ( x y --- addr)
    PIT-WIDTH 2+ * + PLAYING-FIELD +
;

\ Add food item to a random empty cell.
: ADD-FOOD
    0 0
    BEGIN
	2DROP
	PIT-WIDTH RAND 1+ \ x coord.
	PIT-HEIGHT RAND 1+ \ y coord.
	2DUP >PLAYFIELD C@ 0= \ Check for empty cell.
    UNTIL
    2DUP AT-XY FOOD
    >PLAYFIELD 1 SWAP C! \ Store food item in playing field.
;

\ Store x y as new head position.
: HEAD! ( x y ---)
    2DUP >PLAYFIELD 2 SWAP C!
    SNAKE-POSITIONS HEAD-IDX @ IDX-MASK AND 2* + SWAP OVER 1+ C!  C! 
;

\ Show the head depending on its orientation.
: SHOW-HEAD ( ---)
    SNAKE-POSITIONS HEAD-IDX @ IDX-MASK AND 2* + DUP C@ SWAP 1+ C@ AT-XY
    CASE ORIENTATION @
	0 OF HEAD-LEFT ENDOF
	1 OF HEAD-RIGHT ENDOF
	2 OF HEAD-UP ENDOF
	3 OF HEAD-DOWN ENDOF
    ENDCASE
;

\ Show the tail depending on its orientation wrt next segment.
: SHOW-TAIL ( ---)
    SNAKE-POSITIONS TAIL-IDX @ IDX-MASK AND 2* + DUP C@ SWAP 1+ C@ AT-XY
    CASE
	SNAKE-POSITIONS TAIL-IDX @ IDX-MASK AND 2* + @ 
	SNAKE-POSITIONS TAIL-IDX @ 1+ IDX-MASK AND 2* + @ - $FFFF AND
	$FF00 OF TAIL-UP ENDOF
	$0100 OF TAIL-DOWN ENDOF
	$FFFF OF TAIl-LEFT ENDOF
	$0001 OF TAIL-RIGHT ENDOF
    ENDCASE	
;

\ Check if the head and neck segment are on horizontal line.
: HEAD-HORIZ-NECK ( --- f)
    SNAKE-POSITIONS HEAD-IDX @ IDX-MASK AND 2* + @
    SNAKE-POSITIONS HEAD-IDX @ 1- IDX-MASK AND 2* + @ - $FF AND 0= ;

: CHANGE-NECK \ Change the segment right behind the head.
    SNAKE-POSITIONS HEAD-IDX @ IDX-MASK AND 2* + @ \ Head position. 
    SNAKE-POSITIONS HEAD-IDX @ 1- IDX-MASK AND 2* + \ position right behind head
    DUP C@ SWAP 1+ C@ AT-XY \ Position the cursor at neck segment.
    SNAKE-POSITIONS HEAD-IDX @ 2- IDX-MASK AND 2* + @ \ position behind that
    - $FFFF AND \ differnce between head and third segment.
    CASE
	$FE00 OF VERT ENDOF
	$0200 OF VERT ENDOF
	$FFFE OF HORIZ ENDOF
	$0002 OF HORIZ ENDOF
	$0101 OF HEAD-HORIZ-NECK IF TOP-RIGHT ELSE BOTTOM-LEFT THEN ENDOF
	$FEFF OF HEAD-HORIZ-NECK IF BOTTOM-LEFT ELSE TOP-RIGHT THEN ENDOF
	$00FF OF HEAD-HORIZ-NECK IF TOP-LEFT ELSE BOTTOM-RIGHT THEN ENDOF
	$FF01 OF HEAD-HORIZ-NECK IF BOTTOM-RIGHT ELSE TOP-LEFT THEN ENDOF
    ENDCASE	
;

: EMPTY-TAIL
    SNAKE-POSITIONS TAIL-IDX @ IDX-MASK AND 2* + DUP C@ SWAP 1+ C@
    2DUP AT-XY EMPTY
    >PLAYFIELD 0 SWAP C!
;

: NEXT-CELL
    SNAKE-POSITIONS HEAD-IDX @ IDX-MASK AND 2* + DUP C@ SWAP 1+ C@
    CASE
	ORIENTATION @
	0 OF SWAP 1- SWAP ENDOF
	1 OF SWAP 1+ SWAP ENDOF
	2 OF 1- ENDOF
	3 OF 1+ ENDOF
    ENDCASE
;  

: FILL-INITIAL
    0 SCORE !
    PLAYING-FIELD PIT-WIDTH 2+ PIT-HEIGHT 2+  * ERASE
    PLAYING-FIELD PIT-WIDTH 2+ 3 FILL \ Fill edge with wall segments.
    PLAYING-FIELD PIT-WIDTH 2+ PIT-HEIGHT 1+  * +
                  PIT-WIDTH 2+ 3 FILL 
    PIT-HEIGHT 0 DO
	3 PLAYING-FIELD PIT-WIDTH 2+ I 1+ * + C!
	3 PLAYING-FIELD PIT-WIDTH 2+ I 2+ * + 1- C!
    LOOP
    PAGE
    PLAYING-FIELD PIT-WIDTH 2+ PIT-HEIGHT 2+ *  BOUNDS
    DO
	I C@ IF WALL ELSE EMPTY THEN
    LOOP

    1 HEAD-IDX !
    0 TAIl-IDX !
    4 RAND ORIENTATION !
    15 10 RAND + \ initial X position
    10 6 RAND + \ INitial y position.
    HEAD! SHOW-HEAD
    ORIENTATION @ 1 XOR ORIENTATION ! NEXT-CELL
    \ reverse orientation, to get previous cell.
    ORIENTATION @ 1 XOR ORIENTATION ! \ And flip it back
    2DUP >PLAYFIELD 2 SWAP C! \ Mark field as occupied by tail. 
    SNAKE-POSITIONS 1+ C!
    SNAKE-POSITIONS C!      \ Store tail in snake-positions array.
    SHOW-TAIL
    FOOD-ITEMS 0 DO ADD-FOOD LOOP
    SHOW-SCORE
;

: CHANGE-DIR ( n ---)
    \ change the moving direction to the specified one, but do not allow
    \ reversing.
    ORIENTATION @ OVER 1 XOR =
    IF
	DROP
    ELSE
	ORIENTATION !
    THEN ;

: PLAY-GAME
    BEGIN
	5 0 DO WAITFRAME LOOP
	    CASE $201 C@ \ Read the key code.
		27 OF EXIT ENDOF
		8 OF 0 CHANGE-DIR ENDOF \ move to left.
		21 OF 1 CHANGE-DIR ENDOF \ move to right
		11 OF 2 CHANGE-DIR ENDOF \ move up
		10 OF 3 CHANGE-DIR ENDOF \ move down
	    ENDCASE
	NEXT-CELL 2DUP >PLAYFIELD C@
	DUP 2 >= IF
	    DROP 2DROP EXIT \ Hit wall or self, game over
	ELSE
	    1 HEAD-IDX +!
	    >R HEAD! SHOW-HEAD
	    CHANGE-NECK
	    R>
	    1 = IF \ Had some food?
		1 SCORE +! SHOW-SCORE
		ADD-FOOD
	    ELSE
		EMPTY-TAIL \ If no food, advance tail, remain the same length.
		1 TAIL-IDX +!
		SHOW-TAIL
	    THEN
	THEN	
    0 UNTIL
;

: INSTRUCTIONS
    PAGE
    20 0 AT-XY  ." S-E-R-P-E-N-T" 
    0 4 AT-XY ." Move your serpent " TAIl-LEFT HORIZ HORIZ HEAD-RIGHT
               ."  around by" CR ." pressing the cursor keys"
    CR         ." Do not collide with the wall " WALL WALL 
               ."  or with yourself"
    CR         ." The game will be over when you collide."
    CR         ." The serpent  will grow each time you" CR ." swallow some food "
                 FOOD 
    CR         ." You will always keep moving, even when" CR ." no key is pressed."
    CR         ." Try to grow as long as you can!"
    CR         ." ESC quits the game prematurely."
    0 24 AT-XY ." Press any key to start the game." KEY DROP ;

: ASK-QUIT ( --- f)
    1 12 AT-XY
    ." GAME OVER!!!! Play another one? (Y/n)"
    50 0 DO WAITFRAME LOOP
    0 $200 C! \ Clear key code.
    KEY DUP [CHAR] N = SWAP [CHAR] n = OR ;

	
: SERPENT
    RANDOMIZE
    INSTRUCTIONS
    BEGIN 
	FILL-INITIAL
	PLAY-GAME
    ASK-QUIT UNTIL
    PAGE
;

SERPENT
