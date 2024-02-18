\ Spacer, a 2-d space shooter program written in FORTH for AgonLight.
\ Loosely inspired by TI Parsec.
\ Copyright 2024. L.C. Benschop.
\ Released under GPLv3
\ Requires Agon Forth 0.2x, VDP 1.04 or 2.x.


\ stupid random number generator

FORGET SEED

VARIABLE SEED

: RANDOMIZE	0 ." Press any key to start game." BEGIN 1+ KEY? UNTIL KEY DROP SEED ! ;

: RANDOM	\ max --- n ; return random number < max
    SEED @ 1103515245 * 12345 + 
    DUP SEED ! UM* NIP ;

: VWAIT
    HALT ;

CREATE PLAYFIELD 1200 ALLOT

VARIABLE #SHIPS
VARIABLE SCORE
VARIABLE BONUS-SCORE
VARIABLE FUEL
VARIABLE LIFT
VARIABLE LEVEL
VARIABLE LOCKED \ Lock out the laser hitting the ship immediately again 

VARIABLE QUITTING

: UDG
    CREATE C,
    DOES> DUP C@ 8 * $F000 + SWAP 1+ SWAP 8 CMOVE ;


\ UDGs for background (all yellow).
11 UDG BG0
 $FF C,  $FF C, $FF C, $FF C, $FF C, $FF C, $FF C, $FF C, 

17 UDG BG1
 $80 C, $C0 C, $E0 C, $F0 C, $F8 C, $FC C, $FE C, $FF C,

23 UDG BG2
$01 C, $03 C, $07 C, $0F C, $1F C, $3F C, $7f C, $FF C,

29 UDG BG3
$7E C, $FF C, $FF C, $FF C, $FF C, $FF C, $FF C, $FF C, 

132 UDG LASER-G
$00 C, $00 C, $00 C, $FF C, $00 C, $00 C, $00 C, $00 C, 

133 UDG MIS1
$00 C, $00 C, $7F C, $FF C, $7F C, $00 C, $00 C, $00 C,

134 UDG MIS2
$00 C, $01 C, $FF C, $FE C, $FF C, $01 C, $00 C, $00 C,

8 UDG SHIP1  \ Green
$0F C, $4F C, $6F C, $FF C, $FF C, $6F C, $4F C, $0F C,

14 UDG SHIP2
$F0 C, $F8 C, $FC C, $FF C, $FF C, $FC C, $F8 C, $F0 C,

21 UDG FUEL-GAUGE \ red
$00 C, $00 C, $FF C, $FF C, $FF C, $FF C, $00 C, $00 C,
  
13 UDG EN1-1 \ magenta
$0F C, $3F C, $7F C, $E6 C, $E6 C, $7F C, $3F C, $0F C,

19 UDG EN1-2
$F0 C, $FC C, $FE C, $67 C, $67 C, $FE C, $FC C, $F0 C,

24 UDG EN1-1A \ same ship in cyan
$0F C, $3F C, $7F C, $E6 C, $E6 C, $7F C, $3F C, $0F C,

30 UDG EN1-2A
$F0 C, $FC C, $FE C, $67 C, $67 C, $FE C, $FC C, $F0 C,

20 UDG EN1-1B \ same ship in green
$0F C, $3F C, $7F C, $E6 C, $E6 C, $7F C, $3F C, $0F C,

26 UDG EN1-2B
$F0 C, $FC C, $FE C, $67 C, $67 C, $FE C, $FC C, $F0 C,

12 UDG EN2-1 \ Cyan
$0F C, $3F C, $7F C, $E6 C, $E6 C, $7F C, $31 C, $C1 C,

18 UDG EN2-2
$F0 C, $FC C, $FE C, $67 C, $67 C, $FE C, $8C C, $83 C,

25 UDG EN2-1A \ same ship in magenta
$0F C, $3F C, $7F C, $E6 C, $E6 C, $7F C, $31 C, $C1 C,

31 UDG EN2-2A
$F0 C, $FC C, $FE C, $67 C, $67 C, $FE C, $8C C, $83 C,

10 UDG EN2-1B \ same ship in blue
$0F C, $3F C, $7F C, $E6 C, $E6 C, $7F C, $31 C, $C1 C,

16 UDG EN2-2B
$F0 C, $FC C, $FE C, $67 C, $67 C, $FE C, $8C C, $83 C,

\ Parts of the big ship (white)
141 UDG EN3-1
$1F C, $3F C, $7F C, $FF C, $FF C, $7F C, $3F C, $1F C,

142 UDG EN3-2
$FC C, $FE C, $FF C, $FF C, $FF C, $FF C, $FE C, $FC C,

143 UDG EN3-3
$01 C, $03 C, $07 C, $0F C, $1F C, $3F C, $7f C, $FF C,

144 UDG EN3-4
$FF C, $FE C, $FC C, $F8 C, $F0 C, $E0 C, $C0 C, $80 C,

145 UDG EN3-5
$FF C, $7F C, $3F C, $1F C, $0F C, $07 C, $03 C, $01 C,

146 UDG EN3-6
$80 C, $C0 C, $E0 C, $F0 C, $F8 C, $FC C, $FE C, $FF C,

  
\ Parts of the big ship, dithered (white)
  1 UDG EN3-1A
$15 C, $2A C, $55 C, $AA C, $55 C, $2A C, $15 C, $0A C,

  2 UDG EN3-2A
$54 C, $AA C, $55 C, $AA C, $55 C, $AA C, $54 C, $A8 C,

  3 UDG EN3-3A
$01 C, $02 C, $05 C, $0A C, $15 C, $2A C, $55 C, $AA C,

  4 UDG EN3-4A
$55 C, $AA C, $54 C, $A8 C, $50 C, $A0 C, $40 C, $80 C,

  5 UDG EN3-5A
$55 C, $2A C, $15 C, $0A C, $05 C, $02 C, $01 C, $00 C,

  6 UDG EN3-6A
$00 C, $80 C, $40 C, $A0 C, $50 C, $A8 C, $54 C, $AA C,

  7 UDG EN3-INVIS
$00 C, $00 C, $00 C, $00 C, $00 C, $00 C, $00 C, $00 C,
  
9 UDG EXPL1 \ red
$14 C, $00 C, $8A C, $00 C, $92 C, $00 C, $44 C, $00 C,

15 UDG EXPL2
$00 C, $14 C, $00 C, $8A C, $00 C, $92 C, $00 C, $44 C,

149 UDG ASTEROID1
$0F C, $3F C, $3F C, $7F C, $F7 C, $FF C, $FB C, $FF C,

150 UDG ASTEROID2
$F0 C, $FC C, $FC C, $FE C, $EF C, $FF C, $DF C, $FF C,

151 UDG ASTEROID3
$FF C, $F7 C, $FF C, $FD C, $7F C, $7F C, $3F C, $0F C,

152 UDG ASTEROID4
$FF C, $EF C, $FF C, $7F C, $FE C, $FC C, $EC C, $F0 C,

: ,"
\G Add a counted string to the dictionary.
    [CHAR] " WORD COUNT 1+ ALLOT DROP ;    

CREATE NORMAL-BACKGROUND
," 0003   "
," 0001   "
," 001    "
," 03     "
," 03     "
," 03     "
," 03     "
," 002    "
," 0002   "
," 00002  "
," 00003  "
," 00003  "
," 00003  "
," 00003  "
," 000002 "
," 000003 "
," 000003 "
," 000003 "
," 000003 "
," 000003 "
," 000003 "
," 000001 "
," 00001  "
," 00002  "
," 00001  "
," 00002  "
," 000002 "
," 000003 "
," 000003 "
," 000001 "
," 00001  "
0 C,

CREATE REFUEL-BACKGROUND
," 0003   "
," 0001   "
," 001    "
," 01     "
," 02     "
," 01     "
," 0      "
," 0      "
," 0      "
," 0  02  "
," 0  03  "
," 0  002 "
," 0  003 "
," 0  003 "
," 0  003 "
," 0 0003 "
," 0 0003 "
," 0 0003 "
," 0 0001 "
," 0F003  "
," 0U003  "
," 0E003  "
," 0L0002 "
," 0 0003 "
," 0 0003 "
," 0 0003 "
," 0 0003 "
," 0  003 "
," 0  003 "
," 0  003 "
," 0  003 "
," 0  003 "
," 0  003 "
," 0  003 "
," 0   01 "
," 0      "
," 0      "
," 0      "
," 0      "
," 02     "
," 0002   "
," 00003 "
," 00001  "
0 C,


VARIABLE BGPTR

VARIABLE ROW
VARIABLE SCROLL-TIMER
VARIABLE SCROLL-PERIOD

VARIABLE LASER-TEMP

VARIABLE ADD-ENEMY-TIMER
VARIABLE ADD-ENEMY-PERIOD

VARIABLE ENEMIES-ADDED
VARIABLE ENEMIES-KILLED
VARIABLE ENEMY-MODE 

VARIABLE LAST-CHAR 
: NEWCHAR ( rowaddr row --- c)
    BGPTR @ COUNT
    ROT 27 SWAP - DUP ROT >= IF
	2DROP 20 RANDOM 0= IF [CHAR] . ELSE BL THEN \ star or empty for background
	LAST-CHAR @ 149 151 WITHIN IF
	   DROP LAST-CHAR @ 2+    \ top half char of asteroid, select bottom
	ELSE
	   OVER 38 + DUP C@ 149 = IF
	       2DROP 150          \ previous colum has left top of asteroid, tkae right half.  
	   ELSE
	       ENEMY-MODE @ 3 = IF
		   41 + C@ 149 <> 100 RANDOM 0= AND  ROW @ 19 < AND IF DROP 149 THEN \ start a new asteroid if enemy-mode=3 last colum 1 cell below does not have asteroid and at random.
	       ELSE
		   DROP
	       THEN
	   THEN
       THEN
    ELSE
	+ C@ \ pick char from counted string of background.
    THEN
    NIP \ discard row address
;

: SCROLL-BACKGROUND
    0 ROW !
    0 LAST-CHAR !
    1120 0 DO
	PLAYFIELD I + DUP DUP 1+ SWAP 39 CMOVE \ move row in playfield.
	ROW @ NEWCHAR DUP PLAYFIELD I + 39 + C! \ add new char to the right.
	LAST-CHAR !
	1 ROW +!
    40 +LOOP
    \ select new column of background string array.
    BGPTR @ COUNT + DUP C@ 0=
    IF \ at end.
	FUEL @ 1024 < IF
	    DROP REFUEL-BACKGROUND BGPTR ! \ low on fuel, then add tunnel.
	    10 28 AT-XY  ." Time to refuel in tunnel"
	    4 SCROLL-PERIOD !
        ELSE	    
	    DROP NORMAL-BACKGROUND BGPTR ! \ otherwise normal background.
	    2 SCROLL-PERIOD !
	THEN
    ELSE
	BGPTR ! \ select next string in current array.
    THEN
;

6 CONSTANT MAX-SHIPS
13 CONSTANT BYTES-PER-SHIP
\ Offset 0 state
\          0 not active
\          1 active, wrap around X direction
\          2 active, stop when reaching edge in X direction.
\          3 active, disappear when reaching edge in X direction relaunch.
\        1 X timer
\        2 X dir
\        3 X rate
\        4 X pos
\        5 Y timer
\        6 Y dir
\        7 Y rate
\        8 Y pos
\        9-10 ship-chars
\       11-12 background-chars

MAX-SHIPS BYTES-PER-SHIP * CONSTANT SHIP-ARRAY-SIZE
CREATE SHIP-DATA  SHIP-ARRAY-SIZE ALLOT

: SET-POS-X ( y ship --- )
    BYTES-PER-SHIP * SHIP-DATA + 4 + C! ;
: SET-POS-Y ( y ship --- )
    BYTES-PER-SHIP * SHIP-DATA + 8 + C! ;
: SET-RATE-X ( r ship--- )
    BYTES-PER-SHIP * SHIP-DATA + >R
    DUP 0= IF
	0 R@ 2 + C!
    ELSE
	DUP 0< IF
	    $FF R@ 2 + C!
	    NEGATE
	ELSE
	    1 R@ 2 + C!
	THEN
    THEN
    R> 3 + C! ;

: SET-RATE-Y ( r ship--- )
    BYTES-PER-SHIP * SHIP-DATA + >R
    DUP 0= IF
	0 R@ 6 + C!
    ELSE
	DUP 0< IF
	    $FF R@ 6 + C!
	    NEGATE
	ELSE
	    1 R@ 6 + C!
	THEN
    THEN
    R> 7 + C! ;

: ADD-SHIP ( c1 c2 state ship# --- )
    BYTES-PER-SHIP * SHIP-DATA + >R
    R@ C! R@ 10 + C! R> 9 + C!
;

: HIDE-SHIPS
\G Hide any moving ships and missiles
    SHIP-DATA SHIP-ARRAY-SIZE  BOUNDS DO
	I C@ IF
	  I 11 + @  I 4 + C@ I 8 + C@ 40 * + PLAYFIELD + !
	THEN
    BYTES-PER-SHIP +LOOP    
;


: BOUNCE-BIG-SHIP
\ When in enemy mode 2 our enemy ship cosists of 3 smaller 2-character
\ ships that move in sync. THey move vertically. WHen they reach top or
\ bottom, reverse direction.    
    SHIP-DATA BYTES-PER-SHIP + 6 + C@ $FF =
    SHIP-DATA BYTES-PER-SHIP + 8 + C@ 1 = AND IF
	1 SHIP-DATA BYTES-PER-SHIP + 6 + C!
	1 SHIP-DATA BYTES-PER-SHIP 2* + 6 + C!
	1 SHIP-DATA BYTES-PER-SHIP 3 * + 6 + C!
    THEN
    SHIP-DATA BYTES-PER-SHIP + 6 + C@ 1 =
    SHIP-DATA BYTES-PER-SHIP + 8 + C@ 20 >= AND IF
	$FF SHIP-DATA BYTES-PER-SHIP + 6 + C!
	$FF SHIP-DATA BYTES-PER-SHIP 2* + 6 + C!
	$FF SHIP-DATA BYTES-PER-SHIP 3 * + 6 + C!
    THEN
;

: MOVE-BY-RATE ( addr --- pos)
\ Alter the position of a ship as indicated by its rate.
\ addr offs 0 timer (counter incremented by rate, if exceeds 16, do the move)
\           1 dir 00 no move, 1 increment $FF deccrement    
\           2 rate, to be added to timer each cycle
\                   (if rate==16 move each cycle).
\           3 pos is position in character cells. 
    >R       \ Save address
    R@ 2+ C@ R@ C@  + DUP $0F AND R@ C! \ Increment timer by rate
    4 RSHIFT \ How much to move by (16 translates to 1, anything less to 0).
    R@ 1+ C@ $FF = IF NEGATE THEN \ Decrement depending on direction.
    R@ 3 + C@ + DUP  \ Increment position.
    0 MAX 38 MIN R> 3 + C! \ Clip position and store back (return unclipped position).
;
    
: MOVE-SHIPS
    ENEMY-MODE @ 2 = IF BOUNCE-BIG-SHIP THEN
    SHIP-DATA SHIP-ARRAY-SIZE BOUNDS DO
	I C@ IF \ Is this ship active?
	    \ Adjust X position.
	    I 1+ MOVE-BY-RATE
	    DUP 0< IF
		DROP 
		\ Wrap around X of to the left.
		I C@ 1 = IF
		    38 I 4 + C!
		ELSE
		    I C@ 3 = IF 
			SHIP-DATA BYTES-PER-SHIP + 4 + C@ 2-
			I 4 + C! \ Appear to relaunch from main ship
			SHIP-DATA BYTES-PER-SHIP + 8 + C@ I 8 + C!
		    THEN
		THEN		
	    ELSE
		38 > IF
		    \ Wrap around X of to the right.
		    I C@ 1 = IF
			0 I 4 + C!
		    THEN
		THEN
	    THEN
	    I 5 + MOVE-BY-RATE DROP
	    I C@ IF
		I 4 + C@  I 8 + C@ 40 * + PLAYFIELD + @
		I 11 + !
	    THEN		
	THEN
    BYTES-PER-SHIP +LOOP    
;

: DRAW-SHIPS
    SHIP-DATA SHIP-ARRAY-SIZE BOUNDS DO
	I C@ IF \ Is this ship active?
	   I 9 + @  I 4 + C@ I 8 + C@ 40 * + PLAYFIELD + !
	THEN
    BYTES-PER-SHIP +LOOP    
;    

: SHOW-SCORE
    SCORE @ BONUS-SCORE @ >= IF
	2000 BONUS-SCORE +!
	1 #SHIPS +!
    THEN
    0 29 AT-XY  ." SHIPS " #SHIPS @ 3 .R SPACE
    ." FUEL "  FUEL @ 10 RSHIFT 1+ 0 DO 21 EMIT LOOP 10 SPACES
    29 29 AT-XY  ." SCORE" SCORE @ 5 .R
;


: SHIP-X SHIP-DATA 4 + C@ ;
: SHIP-Y SHIP-DATA 8 + C@ ;

\ Table indexed from 8 translates first char of ship into 16-bit two chars
\ of ship of a different colour and the same shape.
CREATE LEVEL-TRANS1
0 , 0 ,  0 , 0 ,
$100A , $1A14 ,  0 , 0 ,
0 , 0 ,  0 , 0 ,
0 , 0 ,  0 , 0 ,
0 , 0 ,  0 , 0 ,
0 , 0 ,  0 , 0 ,

\ Table indexed from 8 translates first char of ship into 16-bit two chars
\ of ship of a different colour and the same shape. Level 4 and higher.
CREATE LEVEL-TRANS2
0 , 0 ,  0 , 0 ,
$1F19 , $1E18 ,  0 , 0 ,
0 , 0 ,  0 , 0 ,
0 , 0 ,  0 , 0 ,
$1A14 , $100A ,  0 , 0 ,  
0 , 0 ,  0 , 0 ,

: HIT-ENEMY1 ( ship-addr --- f)
    LOCKED @ IF
	DROP FALSE
    ELSE
	LEVEL @ 2 < IF
	    DROP TRUE
	ELSE
	    >R R@ 9 + C@ DUP 10 = SWAP 20 = OR IF
		R> DROP TRUE
	    ELSE
		R@ 9 + C@ 8 - CELLS
		LEVEL @ 4 < IF LEVEL-TRANS1 ELSE LEVEL-TRANS2 THEN
		+ @ R> 9 + !
		FALSE
	    THEN
	THEN
	1 LOCKED !
    THEN ;

: CHANGE-TO-GRAY
    $0201 SHIP-DATA BYTES-PER-SHIP + 9 + DUP >R !
    $0403 R@ BYTES-PER-SHIP + !
    $0605 R> BYTES-PER-SHIP 2* + !
;    

: CHANGE-TO-INVIS
    $0707 SHIP-DATA BYTES-PER-SHIP + 9 + DUP >R !
    $0707 R@ BYTES-PER-SHIP + !
    $0707 R> BYTES-PER-SHIP 2* + !
;    

: HIT-ENEMY2 ( --- f )
    LOCKED @ IF
	FALSE
    ELSE
	LEVEL @ 2 < IF
	    TRUE
	ELSE
	    LEVEL @ 4 < IF
		SHIP-DATA BYTES-PER-SHIP + 9 + C@ 128 > IF
		    CHANGE-TO-GRAY FALSE
		ELSE
		    TRUE
		THEN
	    ELSE
		SHIP-DATA BYTES-PER-SHIP + 9 + C@ 128 > IF
		    CHANGE-TO-GRAY FALSE
		ELSE
		    SHIP-DATA BYTES-PER-SHIP + 9 + C@ 7 = IF
			TRUE
		    ELSE
			CHANGE-TO-INVIS FALSE
		    THEN
		THEN
	    THEN
	THEN
	1 LOCKED !
    THEN ;

: LASER-ON
	SHIP-X 2+ SHIP-Y AT-XY 
	40 SHIP-X 2+ ?DO 132 EMIT LOOP \ show laser beam.
	VWAIT
	5 LASER-TEMP +!
	ENEMY-MODE @ 2 = IF
	    SHIP-DATA BYTES-PER-SHIP +
	    DUP C@ 1 = OVER 8 + C@ SHIP-Y = AND SWAP 4 + C@ SHIP-X > AND
	    IF
		\ Laser has hit main enemy ship.
		HIT-ENEMY2
		IF
		    1 ENEMIES-KILLED +!
		    75 SCORE +! SHOW-SCORE
		    SHIP-DATA BYTES-PER-SHIP + BYTES-PER-SHIP 4 * ERASE
		THEN
	    THEN
	ELSE
	    SHIP-DATA SHIP-ARRAY-SIZE  BOUNDS BYTES-PER-SHIP + DO
		I C@ 1 = IF
		    \ Laser has hit one or more enemy ships
		    I 8 + C@ SHIP-Y = I 4 + C@ SHIP-X > AND IF
			I HIT-ENEMY1
			IF
			    ENEMY-MODE @ 10 * 50 + SCORE +! SHOW-SCORE
			    0 I C!
			    1 ENEMIES-KILLED +!
			THEN
		    THEN
		THEN
	    BYTES-PER-SHIP +LOOP
	THEN
;

\ Reset fuel for a new ship or after refueling. Get less as the game
\ gets harder.
: SET-FUEL
    LEVEL @ 2 < IF
	10000
    ELSE
	LEVEL @ 4 < IF
	    5000
	ELSE
	    2500
	THEN
    THEN FUEL ! ;

: SHOW-EXPL
\ Show exploding ship    
    SHIP-X SHIP-Y AT-XY  9 EMIT 15 EMIT
    2000 MS
;    
   

: COLLISION-DETECT ( --- f)
    PLAYFIELD SHIP-Y 40 * + SHIP-X + @ DUP $455546 =
    IF
	DROP SET-FUEL
	SHOW-SCORE
	10 28 AT-XY 20 SPACES
	FALSE EXIT
    THEN	
    DUP 2* OR $4040 XOR $4040 AND IF
	TRUE
	10 28 AT-XY  ." Crashed into ground"
	SHOW-EXPL
	EXIT
    THEN 
    LASER-TEMP @ 20 > IF
	TRUE
	10 28 AT-XY  ." Laser overheated" 
	SHOW-EXPL
	EXIT
    THEN
    SHIP-DATA SHIP-ARRAY-SIZE  BOUNDS BYTES-PER-SHIP + DO
	I C@ IF
	    I 8 + C@ SHIP-Y = I 4 + C@ SHIP-X - ABS 2 <  AND IF
		10 28 AT-XY 
		I C@ 1 = IF
		    ." Collision with enemy"
		ELSE
		    ." Hit by missile"
		THEN
		SHOW-EXPL
		UNLOOP TRUE
		EXIT
	    THEN
	THEN
    BYTES-PER-SHIP +LOOP
    FALSE
;

: SHOW-LIFT
    0 28 AT-XY   ." LIFT "
    LIFT @ 32 = IF
	3
    ELSE
	LIFT @ 16 = IF
	    2   
	ELSE
	    1
	THEN
    THEN
    .
;

: INITIALIZE-LEVEL
    PAGE
    PLAYFIELD 1200 BLANK
    SHIP-DATA SHIP-ARRAY-SIZE ERASE
    8 14 2 0 ADD-SHIP
    $2020 SHIP-DATA 11 + !
    16 0 SET-POS-X 
    12 0 SET-POS-Y 
    SHOW-SCORE
    16 LIFT !
    SHOW-LIFT 
    0 ENEMIES-ADDED !
    0 ENEMIES-KILLED !
    0 LASER-TEMP !
    QUITTING OFF
    NORMAL-BACKGROUND BGPTR !
    40 0 DO SCROLL-BACKGROUND LOOP
;

: ADD-ENEMY
    ENEMIES-ADDED @ MAX-SHIPS 1- <
    IF
	ENEMY-MODE @ 0= IF
	    13 19 1 ENEMIES-ADDED @ 1+ ADD-SHIP
	    1 ENEMIES-ADDED +!
	    20 RANDOM ENEMIES-ADDED @ SET-POS-Y
	    38 ENEMIES-ADDED @ SET-POS-X
	    -12 ENEMIES-ADDED @ SET-RATE-X
	    0 ENEMIES-ADDED @ SET-RATE-Y
	ELSE
	    ENEMY-MODE @ 1 = IF
		12 18 1 ENEMIES-ADDED @ 1+ ADD-SHIP
		1 ENEMIES-ADDED +!
		20 RANDOM ENEMIES-ADDED @ SET-POS-Y
		0 ENEMIES-ADDED @ SET-POS-X
		12 ENEMIES-ADDED @ SET-RATE-X
		0 ENEMIES-ADDED @ SET-RATE-Y
	    ELSE
		ENEMY-MODE @ 2 = IF
		    \ ENEMY-MODE = 2
		    ENEMIES-ADDED @ ENEMIES-KILLED @ = IF
			141 142 1 1 ADD-SHIP
			1 ENEMIES-ADDED +!
			18 RANDOM 1+ >R
			R@ 1 SET-POS-Y
			37 1 SET-POS-X
			0 1 SET-RATE-X
			4 1 SET-RATE-Y
			143 144 1 2 ADD-SHIP
			R@ 1- 2 SET-POS-Y
			38 2 SET-POS-X
			0 2 SET-RATE-X
			4 2 SET-RATE-Y
			145 146 1 3 ADD-SHIP
			R@ 1+ 3 SET-POS-Y
			38 3 SET-POS-X
			0 3 SET-RATE-X
			4 3 SET-RATE-Y \ Ships 1, 2 and 3 form the big white ship
			\ All are making the same movement.
			133 134 3 4 ADD-SHIP
			R> 4 SET-POS-Y
			35 4 SET-POS-X
			-32 4 SET-RATE-X
			\ 'ship 4' is our missile.
		    THEN
		ELSE
		    1 ENEMIES-ADDED +!
		    ENEMIES-ADDED @ ENEMIES-KILLED !
		    \ Don't have enemy ships in this mode, just asteroids.
		THEN
	    THEN
	THEN
    ELSE	
	ENEMIES-ADDED @ ENEMIES-KILLED @ =
	IF
	    0 ENEMIES-ADDED !
	    0 ENEMIES-KILLED !
	    1 ENEMY-MODE +!
	    ENEMY-MODE @ 3 > IF 0 ENEMY-MODE ! 1 LEVEL +! THEN
	THEN
    THEN
;

: INITIALIZE-GAME
    NORMAL-BACKGROUND REFUEL-BACKGROUND
    2 0 DO
	BGPTR !
	BEGIN
	    BGPTR @ C@
	WHILE
		BGPTR @ COUNT 2DUP + BGPTR !
		BOUNDS DO I C@ 48 58 WITHIN IF I C@ 48 - 6 * 11 + I C! THEN LOOP
		\ Change characters in background array to UDG range.
	REPEAT
    LOOP
    0 LEVEL !
    0 LOCKED !
    0 ENEMY-MODE !
    3 #SHIPS !
    0 SCORE !
    2000 BONUS-SCORE !
    SET-FUEL
    2 SCROLL-PERIOD !
    50 ADD-ENEMY-PERIOD !
;    

: MAINLOOP
    \G Main loop of teh game.
    BEGIN
	VWAIT
	0 0 SET-RATE-X
	0 0 SET-RATE-Y
	HIDE-SHIPS
	CASE $201 C@
	    [CHAR] 1 OF 8 LIFT ! SHOW-LIFT ENDOF
	    [CHAR] 2 OF 16 LIFT ! SHOW-LIFT ENDOF
	    [CHAR] 3 OF 32 LIFT ! SHOW-LIFT ENDOF
	    11       OF LIFT @ NEGATE  0 SET-RATE-Y 0 $201 C! ENDOF
	    10       OF LIFT @  0 SET-RATE-Y 0 $201 C! ENDOF
	    8        OF -16 0 SET-RATE-X 0 $201 C! ENDOF
	    21       OF 16 0 SET-RATE-X 0 $201 C! ENDOF
	    BL       OF LASER-ON 0 $201 C! ENDOF
	    27       OF QUITTING ON 0 #SHIPS ! ENDOF
	ENDCASE
	LASER-TEMP @ IF
	    -1 LASER-TEMP +!
	ELSE
	    0 LOCKED !
	THEN
	1 SCROLL-TIMER +!
	SCROLL-TIMER @ SCROLL-PERIOD @ >= IF
	    SCROLL-BACKGROUND
	    0 SCROLL-TIMER !
	THEN
	1 ADD-ENEMY-TIMER +!
	ADD-ENEMY-TIMER @ ADD-ENEMY-PERIOD @ >= IF
	    ADD-ENEMY
	    0 ADD-ENEMY-TIMER !
	THEN
	FUEL @
	IF
	    -1 FUEL +!
	ELSE
	    2 0 SET-RATE-Y \ Force ship to hit the ground if no more fuel.
	THEN
	FUEL @ $3FF AND $3FF = IF SHOW-SCORE THEN
	MOVE-SHIPS
	COLLISION-DETECT IF QUITTING ON -1 #SHIPS +! SET-FUEL THEN
	DRAW-SHIPS
	PLAYFIELD $F800 1120 CMOVE \ Move the scrolled background to video RAM.
	QUITTING @
    UNTIL ;

: INSTRUCTIONS
    \ Define all UDGs
    PAGE
    BG0 BG1 BG2 BG3 LASER-G MIS1 MIS2 SHIP1 SHIP2
    EN1-1 EN1-2 EN2-1 EN2-2
    EN1-1A EN1-2A EN2-1A EN2-2A
    EN1-1B EN1-2B EN2-1B EN2-2B
    EN3-1 EN3-2 EN3-3 EN3-4 EN3-5 EN3-6
    EN3-1A EN3-2A EN3-3A EN3-4A EN3-5A EN3-6A
    EN3-INVIS
    EXPL1 EXPL2
    FUEL-GAUGE
    ASTEROID1 ASTEROID2 ASTEROID3 ASTEROID4
     14 0 AT-XY ." S-P-A-C-E-R" 
    CR
    CR ." v0.2 Copyright 2024 L.C. Benschop"
    CR
    CR ." Cursor keys to control your ship "  8 EMIT 14 EMIT
    CR ." Keys 1, 2, 3 set rate of ascent/descent"
    CR
    CR ." SPACE fires your laser."
    CR ." Be careful, do not overheat!"
    CR ." Destroy all enemy ships with your laser"
    CR
    CR ." Descend into tunnel when low on fuel"
    CR
    CR ." Asteroids " 149 EMIT 150 EMIT SPACE SPACE ." you cannot destroy"
    CR ."           " 151 EMIT 152 EMIT
    CR ." Navigate around them."
    CR
    CR
    CR 13  EMIT 19  EMIT  10 SPACES ." 50 points"
    CR
    CR 12  EMIT 18  EMIT  10 SPACES ." 60 points"
    CR
    CR SPACE 143 EMIT 144 EMIT 
    CR  141 EMIT 142 EMIT 10 SPACES ." 75 points"
    CR SPACE 145 EMIT 146 EMIT
    0 29 AT-XY RANDOMIZE
;

: SPACER
    INSTRUCTIONS
    BEGIN 
	INITIALIZE-GAME
	BEGIN
	    INITIALIZE-LEVEL
	    MAINLOOP
	    #SHIPS @ 0=
	UNTIL
	3 12 AT-XY  ." Game Over !!! Play again (Y/N)?"
	500 MS 0 $200 C! 
	KEY DUP $4E = SWAP $6E = OR
    UNTIL
    PAGE
;

SPACER
