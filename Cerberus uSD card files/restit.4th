\
\ restit.4th	Tetris-like game for AGON, redone in ANSI-Forth.
\		Original FORTH version Written 05Apr94 by Dirk Uwe Zoller, e-mail:
\			duz@roxi.rz.fht-mannheim.de.
\		Look&feel stolen from Mike Taylor's "TETRIS FOR TERMINALS"
\
\		Please copy and share this program, modify it for your system
\		and improve it as you like. But don't remove this notice.
\
\		Thank you.
\
\               Adapted for Agon Light by Lennart Benschop 2023-07-17
\		Changes:
\               - Optimized for 40 column screen.
\               - user-defined tiles, in colour for Agon
\               - counterclockwise rotate
\               - Controls using arrow keys.
\               - Show next brick
\               - Add sound effects
\

ONLY FORTH DEFINITIONS
FORGET FORGET-TT
CREATE FORGET-TT

DECIMAL

WORDLIST CONSTANT TETRIS
GET-ORDER TETRIS DUP ROT 2 + SET-ORDER DEFINITIONS


\ Variables, constants

VARIABLE WIPING			\ if true: wipe brick, else draw brick
2 CONSTANT COL0			\ position of the pit on screen
0 CONSTANT ROW0

10 CONSTANT WIDE		\ size of pit in brick positions
20 CONSTANT DEEP


8       VALUE LEFT-KEY		\ customize if you don't like them
11	VALUE ROT-KEY-R
CHAR X  VALUE ROT-KEY-R2
CHAR Z  VALUE ROT-KEY-L
21	VALUE RIGHT-KEY
BL	VALUE DROP-KEY
10      VALUE DROP-KEY2
CHAR P	VALUE PAUSE-KEY
27	VALUE QUIT-KEY

VARIABLE SCORE 
VARIABLE PIECES 
VARIABLE LEVELS 
VARIABLE DELAY 

VARIABLE BROW			\ where the brick is
VARIABLE BCOL


\ stupid random number generator

VARIABLE SEED
: RANDOMIZE	0 ." Press any key." CR BEGIN 1+ KEY? UNTIL KEY DROP SEED ! ;

: RANDOM	\ max --- n ; return random number < max
		SEED @ 1103515245 * 12345 + [ HEX ] 07FFF [ DECIMAL ] AND
		DUP SEED !  SWAP MOD ;


\ Emit 16-bit number as 2 bytes.
: 2EMIT ( n ---)
    DUP EMIT 8 RSHIFT EMIT ;


127 VALUE VOLUME
\ Generate a tone.
: TONE ( chan wf vol freq dur --- )
      2DROP 2DROP DROP
;


\ Drawing primitives:

: UDG
    CREATE C,
    DOES> DUP C@ 8 * $F000 + SWAP 1+ SWAP 8 CMOVE ;

\ Wall edge of pit
31 UDG WALL $7E C, $7E C, $7E C, $00 C, $E7 C, $E7 C, $E7 C, $00 C,

\ Bit patterns for each of the seven bricks.
9  UDG BR1  $00 C, $7E C, $7E C, $7E C, $7E C, $7E C, $7E C, $00 C,
8  UDG BR2  $FF C, $E7 C, $C3 C, $81 C, $81 C, $C3 C, $E7 C, $FF C,
11 UDG BR3  $55 C, $AA C, $55 C, $AA C, $55 C, $AA C, $55 C, $AA C,
10 UDG BR4  $FF C, $FF C, $FF C, $FF C, $FF C, $FF C, $FF C, $FF C,
13 UDG BR5  $FF C, $E7 C, $DB C, $BD C, $BD C, $DB C, $E7 C, $FF C,
12 UDG BR6  $00 C, $66 C, $66 C, $00 C, $00 C, $66 C, $66 C, $00 C,
7  UDG BR7  $FF C, $99 C, $99 C, $FF C, $FF C, $99 C, $99 C, $FF C,

137 UDG LEFTARROW  $00 C, $00 C, $20 C, $40 C, $FE C, $40 C, $20 C, $00 C, 
138 UDG RIGHTARROW $00 C, $00 C, $08 C, $04 C, $FE C, $04 C, $08 C, $00 C,   
139 UDG UPARROW    $10 C, $38 C, $54 C, $10 C, $10 C, $10 C, $10 C, $00 C,
140 UDG DOWNARROW  $10 C, $10 C, $10 C, $10 C, $54 C, $38 C, $10 C, $00 C, 
  
: POSITION	\ row col --- ; cursor to the position in the pit
	        COL0 + SWAP ROW0 + AT-XY ;


CREATE BRICKCODES 9 C, 8 C, 11 C, 10 C, 13 C, 12 C, 7 C,	    
: PR-CHAR      \ c1 ---
               DUP BL = IF EMIT ELSE  65 - BRICKCODES + C@ EMIT THEN ;
: STONE	       \ c1 --- ; draw or undraw this character
	       WIPING @ IF DROP BL THEN PR-CHAR ;


\ Define the pit where bricks fall into:

: DEF-PIT	CREATE	WIDE DEEP * ALLOT
		DOES>	ROT WIDE * ROT + CHARS + ;

DEF-PIT PIT

: EMPTY-PIT	DEEP 0 DO WIDE 0 DO  BL J I PIT C!
		LOOP LOOP ;


\ Displaying:

: DRAW-BOTTOM	\ --- ; redraw the bottom of the pit
		DEEP -1 POSITION
                39 0 DO  31 EMIT LOOP
                ;

: DRAW-FRAME	\ --- ; draw the border of the pit
		DEEP 0 DO
		    I -1   POSITION  31 EMIT
		    I WIDE POSITION  31 EMIT
		LOOP  DRAW-BOTTOM ;

: BOTTOM-MSG	\ addr cnt --- ; output a message in the bottom of the pit
		DEEP OVER 2/ WIDE SWAP - 2/ POSITION TYPE ;

: DRAW-LINE	\ line ---
    DUP 0 POSITION  WIDE 0 DO  DUP I PIT C@ PR-CHAR  LOOP  DROP
    ;

: DRAW-PIT	\ --- ; draw the contents of the pit
		DEEP 0 DO  I DRAW-LINE  LOOP ;

: SHOW-KEY	\ char --- ; visualization of that character
		DUP BL <
		IF  [CHAR] @ OR  [CHAR] ^ EMIT  EMIT  SPACE
		ELSE  [CHAR] ` EMIT  EMIT  [CHAR] ' EMIT
		THEN ;

: WALLS ( n --- ) \ draw n wall characters
   0 DO 31 EMIT LOOP ;



: SHOW-HELP	\ --- ; display some explanations
                20  0 AT-XY 20 WALLS    
		20  1 AT-XY 3 WALLS ."  R E S T I T " 4 WALLS
		13  2 AT-XY 27 WALLS
		16  5 AT-XY ." Use keys:"
		16  6 AT-XY 137 EMIT        ."          Move left"
		16  7 AT-XY 139 EMIT        ." or X     Rotate right"
		16  8 AT-XY [CHAR] Z EMIT   ."          Rotate left"
		16  9 AT-XY 138 EMIT        ."          Move right"
		16 10 AT-XY 140 EMIT        ." or Space Drop"
		16 11 AT-XY [CHAR] P EMIT   ."          Pause"
		16 12 AT-XY ." Esc       Quit"
		13 13 AT-XY 27 WALLS
		16 16 AT-XY ." Score:"
		16 17 AT-XY ." Pieces:"
                16 18 AT-XY ." Levels:"
                0 22 AT-XY ." Original by Dirk Uwe Zoller 1994"
                0 23 AT-XY ." Modified for Agon Lennart Benschop 2023"
              ;

	     : UPDATE-SCORE	\ --- ; display current score
		24 16 AT-XY SCORE @ 3 .R
		24 17 AT-XY PIECES @ 3 .R
		24 18 AT-XY LEVELS @ 3 .R ;

: REFRESH	\ --- ; redraw everything on screen
		PAGE DRAW-FRAME DRAW-PIT SHOW-HELP UPDATE-SCORE ;


\ Define shapes of bricks:

: DEF-BRICK	CREATE	4 0 DO
			    ' EXECUTE  0 DO  DUP I CHARS + C@ C,  LOOP DROP
			    REFILL DROP
			LOOP
		DOES>	ROT 4 * ROT + CHARS + ;

DEF-BRICK BRICK1	S"     "
			S" AAA "
			S"  A  "
			S"     "

DEF-BRICK BRICK2	S"     "
			S" BBBB"
			S"     "
			S"     "

DEF-BRICK BRICK3	S"     "
			S"  CCC"
			S"  C  "
			S"     "

DEF-BRICK BRICK4	S"     "
			S" DDD "
			S"   D "
			S"         "

DEF-BRICK BRICK5	S"     "
			S"  EE "
			S"  EE "
			S"     "

DEF-BRICK BRICK6	S"     "
			S" FF  "
			S"  FF "
			S"     "

DEF-BRICK BRICK7	S"     "
			S"  GG "
			S" GG  "
			S"     "

\ this brick is actually in use:

DEF-BRICK BRICK		S"     "
			S"     "
			S"     "
			S"     "

DEF-BRICK SCRATCH	S"     "
			S"     "
			S"     "
			S"     "

CREATE BRICKS	' BRICK1 ,  ' BRICK2 ,  ' BRICK3 ,  ' BRICK4 ,
		' BRICK5 ,  ' BRICK6 ,  ' BRICK7 ,

CREATE BRICK-VAL 1 C, 2 C, 3 C, 3 C, 4 C, 5 C, 5 C,


VARIABLE NEXT-BRICK	      

: IS-BRICK	\ brick --- ; activate a shape of brick
		>BODY ['] BRICK >BODY 16 CMOVE ;

: NEW-BRICK	\ --- ; select a new brick by random, count it
		1 PIECES +!  NEXT-BRICK @
		BRICKS OVER CELLS + @ IS-BRICK
                BRICK-VAL SWAP CHARS + C@ SCORE +!
                7 RANDOM NEXT-BRICK !
                BRICKS NEXT-BRICK @ CELLS + @ >BODY 4 +
                2 0 DO
	          15 I AT-XY 
		    4 0 DO
			DUP C@ STONE 1+
		    LOOP
		LOOP DROP
;            

: ROTLEFT	4 0 DO 4 0 DO
		    J I BRICK C@  3 I - J SCRATCH C!
		LOOP LOOP
		['] SCRATCH IS-BRICK ;

: ROTRIGHT	4 0 DO 4 0 DO
		    J I BRICK C@  I 3 J - SCRATCH C!
		LOOP LOOP
		['] SCRATCH IS-BRICK ;

: DRAW-BRICK	\ row col ---
		4 0 DO 4 0 DO
		    J I BRICK C@ BL <>
		    IF  OVER J + OVER I +  POSITION
			J I BRICK C@ STONE
		    THEN
		LOOP LOOP  2DROP ;

	
: SHOW-BRICK	FALSE WIPING ! DRAW-BRICK ;
: HIDE-BRICK	TRUE  WIPING ! DRAW-BRICK ;

: PUT-BRICK	\ row col --- ; put the brick into the pit
		4 0 DO 4 0 DO
		    J I BRICK C@  BL <>
		    IF  OVER J +  OVER I +  PIT
			J I BRICK C@ SWAP C!
		    THEN
		LOOP LOOP  2DROP ;

: REMOVE-BRICK	\ row col --- ; remove the brick from that position
		4 0 DO 4 0 DO
		    J I BRICK C@  BL <>
		    IF  OVER J + OVER I + PIT BL SWAP C!  THEN
		LOOP LOOP  2DROP ;

: TEST-BRICK	\ row col --- flag ; could the brick be there?
		4 0 DO 4 0 DO
		    J I BRICK C@ BL <>
		    IF  OVER J +  OVER I +
			OVER DUP 0< SWAP DEEP >= OR
			OVER DUP 0< SWAP WIDE >= OR
			2SWAP PIT C@  BL <>
			OR OR IF  UNLOOP UNLOOP 2DROP FALSE  EXIT  THEN
		    THEN
		LOOP LOOP  2DROP TRUE ;

: MOVE-BRICK	\ rows cols --- flag ; try to move the brick
		BROW @ BCOL @ REMOVE-BRICK
		SWAP BROW @ + SWAP BCOL @ + 2DUP TEST-BRICK
		IF  BROW @ BCOL @ HIDE-BRICK
		    2DUP BCOL ! BROW !  2DUP SHOW-BRICK PUT-BRICK  TRUE
		ELSE  2DROP BROW @ BCOL @ PUT-BRICK  FALSE
		THEN ;

: ROTATE-BRICK	\ flag --- flag ; left/right, success
		BROW @ BCOL @ REMOVE-BRICK
		DUP IF  ROTRIGHT  ELSE  ROTLEFT  THEN
		BROW @ BCOL @ TEST-BRICK
		OVER IF  ROTLEFT  ELSE  ROTRIGHT  THEN
		IF  BROW @ BCOL @ HIDE-BRICK
		    IF  ROTRIGHT  ELSE  ROTLEFT  THEN
		    BROW @ BCOL @ PUT-BRICK
		    BROW @ BCOL @ SHOW-BRICK  TRUE
		ELSE  DROP FALSE  THEN ;

: INSERT-BRICK	\ row col --- flag ; introduce a new brick
		2DUP TEST-BRICK
		IF  2DUP BCOL ! BROW !
		    2DUP PUT-BRICK  DRAW-BRICK  TRUE
		ELSE  2DROP FALSE  THEN ;

: DROP-BRICK	\ --- ; move brick down fast
		BEGIN  1 0 MOVE-BRICK 0=  UNTIL ;

: MOVE-LINE	\ from to ---
		OVER 0 PIT  OVER 0 PIT  WIDE  CMOVE  DRAW-LINE
		DUP 0 PIT  WIDE BLANK  DRAW-LINE ;

: LINE-FULL	\ line-no --- flag
		TRUE  WIDE 0
		DO  OVER I PIT C@ BL =
		    IF  DROP FALSE  LEAVE  THEN
		LOOP NIP ;

VARIABLE FREQ	    
: REMOVE-LINES	\ ---
                500 FREQ !		
		DEEP DEEP
		BEGIN
		    SWAP
		    BEGIN  1- DUP 0< IF
			    FREQ @ 500 = IF 0 0 VOLUME 200 50 TONE THEN
			    2DROP EXIT
	            THEN  DUP LINE-FULL
		    WHILE
			    0 0 VOLUME FREQ @ 100 TONE
			    FREQ @ 105 100 */ FREQ !
			    1 LEVELS +!  10 SCORE +!
		    REPEAT
		    SWAP 1-
		    2DUP <> IF  2DUP MOVE-LINE  THEN
		AGAIN ;

: TO-UPPER	\ char --- char ; convert to upper case
		DUP [CHAR] a >= OVER [CHAR] z <= AND
		IF  [ CHAR A CHAR a - ] LITERAL +  THEN ;

: DISPATCH	\ key --- flag
		CASE  TO-UPPER
		    LEFT-KEY	OF  0 -1 MOVE-BRICK DROP  ENDOF
		    RIGHT-KEY	OF  0  1 MOVE-BRICK DROP  ENDOF
		    ROT-KEY-R	OF  1 ROTATE-BRICK DROP  ENDOF
		    ROT-KEY-R2	OF  1 ROTATE-BRICK DROP  ENDOF
		    ROT-KEY-L	OF  0 ROTATE-BRICK DROP  ENDOF
		    DROP-KEY	OF  DROP-BRICK  ENDOF
		    DROP-KEY2	OF  DROP-BRICK  ENDOF
		    PAUSE-KEY	OF  S"  Paused " BOTTOM-MSG  KEY DROP
				    DRAW-BOTTOM  ENDOF
		    QUIT-KEY	OF  FALSE EXIT  ENDOF
		ENDCASE  TRUE ;

: INITIALIZE	\ --- ; prepare for playing
                \ Define the UDGs
                WALL BR1 BR2 BR3 BR4 BR5 BR6 BR7
                LEFTARROW RIGHTARROW UPARROW DOWNARROW
		RANDOMIZE EMPTY-PIT REFRESH
                0 SCORE !  0 PIECES !  0 LEVELS !  100 DELAY !
                7 RANDOM NEXT-BRICK ! ;

: ADJUST-DELAY	\ --- ; make it faster with increasing score
		LEVELS @
		DUP  50 < IF  100 OVER -  ELSE
		DUP 100 < IF   62 OVER 4 / -  ELSE
		DUP 500 < IF   31 OVER 16 / -  ELSE  0  THEN THEN THEN
		DELAY !  DROP ;

: PLAY-GAME	\ --- ; play one tetris game
		BEGIN
		    NEW-BRICK
		    -1 3 INSERT-BRICK
		WHILE
		    BEGIN  4 0
			DO  35 13 AT-XY
			    DELAY @ MS KEY?
			    IF  BEGIN  KEY KEY? WHILE  DROP  REPEAT
				DISPATCH 0=
				IF  UNLOOP EXIT  THEN
			    THEN
			LOOP
			1 0 MOVE-BRICK  0=
		    UNTIL
		    REMOVE-LINES
		    UPDATE-SCORE
		    ADJUST-DELAY
	    REPEAT
	    100 300 DO 0 0 VOLUME I 200 TONE -50 +LOOP 
	;

FORTH DEFINITIONS

: TT		\ --- ; play the tetris game
		INITIALIZE
		S"  Press any key " BOTTOM-MSG KEY DROP DRAW-BOTTOM
		BEGIN
		    PLAY-GAME
		    S"  Again? " BOTTOM-MSG KEY TO-UPPER [CHAR] N <>
		WHILE  INITIALIZE  REPEAT
;

ONLY FORTH ALSO DEFINITIONS
TT	    

	    
