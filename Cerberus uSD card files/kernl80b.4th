\ created 1994 by L.C. Benschop.
\ copyleft (c) 1994-2014 by the sbc09 team, see AUTHORS for more details.
\ copyleft (c) 2022-2023 L.C. Benschop for Cerberus 2080/2100.
\ license: GNU General Public License version 3, see LICENSE for more details.
\ Change: 2023-08-11: top address of edit buffer moved 2 bytes down,
\         so as not to collide with expansion card mailbox. 
CROSS-COMPILE

\ PART 4: Constants and variables

00 CONSTANT 0
01 CONSTANT 1
02 CONSTANT 2
-1 CONSTANT -1


00
CONSTANT FALSE ( --- 0)
\G Constant 0, indicates FALSE

-01
CONSTANT TRUE ( --- -1)
\G Constant -1, indicates TRUE
 
32
CONSTANT BL ( --- 32 )
\G Constant 32, the blank character

VARIABLE S0 ( --- a-addr)
\G Variable that holds the bottom address of the stack.
 -2 ALLOT-T
LABEL S0ADDR ENDASM \ Create an assembler label at cfa
 02 ALLOT-T

VARIABLE R0 ( --- a-addr)
\G Variable that holds the bottom address of the return stack.
 -2 ALLOT-T
LABEL R0ADDR ENDASM \ Create an assembler label at cfa
 02 ALLOT-T

\ PART 5: Simple colon definitions.

: <>   ( x1 x2 --- f)
\G f is true if and only if x1 is not equal to x2.
  = 0= ;

: >    ( n1 n2 --- f)
\G f is true if and only if the signed number n1 is less than n2.
  SWAP < ;

: 0>  ( n --- f)
\G f is true if and only if n is greater than 0.
  0 > ;

: U>  ( u1 u2 --- f)
\G f is true if and only if the unsigned number u1 is greater than u2.
  SWAP U< ;


: ALIGNED ( c-addr --- a-addr )
\G a-addr is the first aligned address after c-addr.
   ;

: DEPTH ( --- n )
\G n is the number of cells on the stack (before DEPTH was executed).
  SP@ S0 @ SWAP - 2/ ;

: OFF ( a-addr ---)
\G Store FALSE at a-addr.
   0 SWAP ! ;

: ON ( a-addr ---)
\G Store TRUE at a-addr.
   -1 SWAP ! ;

\ The next few words manipulate addresses in a system-independent way.
\ Use CHAR+ instead of 1+ and it will be portable to systems where you
\ have to add something different from 1.

: CHAR+ ( c-addr1 --- c-addr2)
\G c-addr2 is the next character address after c-addr1.
   1+ ;

: CHARS ( n1 --- n2)
\G n2 is the number of address units occupied by n1 characters.
; \ A no-op.

: CHAR-  ( c-addr1 --- c-addr2)
\G c-addr2 is the previous character address before c-addr1.
   1- ;

: CELL+ ( a-addr1 --- a-addr2)
\G a-addr2 is the address of the next cell after a-addr2.
    2+ ;

: CELLS ( n2 --- n1)
\G n2 is the number of address units occupied by n1 cells.
   2* ;

: CELL- ( a-addr1 --- a-addr2)
\G a-addr2 is the address of the previous cell before a-addr1.
   2- ;

: ?DUP ( n --- 0 | n n)
\G Duplicate the top cell on the stack, but only if it is nonzero.
   DUP IF DUP THEN ;

: MOVE ( c-addr1 c-addr2 u --- )
\G Copy a block of u bytes starting at c-addr1 to c-addr2. Order is such
\G that partially overlapping blocks are copied intact.
  >R OVER OVER U< IF R> CMOVE> ELSE R> CMOVE THEN ;

\ PART 6: Arithmetic words, colon definitions.

: MIN ( n1 n2 --- n3)
\G n3 is the minimum of n1 and n2.
   OVER OVER > IF SWAP THEN DROP ;

: MAX ( n1 n2 --- n3)
\G n3 is the maximum of n1 and n2.
   OVER OVER < IF SWAP THEN DROP ;

: ABS ( n --- u)
\G u is the absolute value of n.
   DUP 0< IF NEGATE THEN ;

: DABS ( d --- ud)
\G ud is the absolute value of d.
   DUP 0< IF DNEGATE THEN ;

: SM/REM ( d n1 --- nrem nquot )
\G Divide signed double number d by single number n1, giving quotient and
\G remainder. Round towards zero, remainder has same sign as dividend.
  2DUP XOR >R OVER >R \ Push signs of quot and rem.
  ABS >R DABS R>
  UM/MOD
  SWAP R> 0< IF NEGATE THEN SWAP
  R> 0< IF NEGATE THEN ;

: FM/MOD ( d n1 --- nrem nquot )
\G Divide signed double number d by single number n1, giving quotient and
\G remainder. Round always down (floored division),
\G remainder has same sign as divisor.
  DUP >R OVER OVER XOR >R
  SM/REM
  OVER R> 0< AND IF SWAP R@ + SWAP 1 - THEN R> DROP ;

: M* ( n1 n2 --- d )
\G Multiply the signed numbers n1 and n2, giving the signed double number d.
  2DUP XOR >R ABS SWAP ABS UM* R> 0< IF DNEGATE THEN ;

: * ( w1 w2 --- w3)
\G Multiply single numbers, signed or unsigned give the same result.
  UM* DROP ;

: */MOD ( n1 n2 n3 --- nrem nquot)
\G Multiply signed numbers n1 by n2 and divide by n3, giving quotient and
\G remainder. Intermediate result is double.
  >R M* R> FM/MOD ;

: */    ( n1 n2 n3 --- n4 )
\G Multiply signed numbers n1 by n2 and divide by n3, giving quotient n4.
\G Intermediate result is double.
  */MOD SWAP DROP ;

: S>D  ( n --- d)
\G Convert single number to double number.
   DUP 0< ;

: /MOD  ( n1 n2 --- nrem nquot)
\G Divide signed number n1 by n2, giving quotient and remainder.
   SWAP S>D ROT FM/MOD ;

: / ( n1 n2 --- n3)
\G n3 is n1 divided by n2.
 /MOD SWAP DROP ;

: MOD ( n1 n2 --- n3)
\G n3 is the remainder of n1 and n2.
  /MOD DROP ;

\ PART 7: Screen output and string related words.

VARIABLE COL ( --- a-addr)
\G Variable that holds the current screen column (0..40)

VARIABLE LINESTART ( --- a-addr)
\G Variable that holds the start of the current row in video RAM.
 -2 ALLOT-T
LABEL LINESTARTADDR ENDASM \ Add assembler label.
 02 ALLOT-T

: CR ( ---)
\G Start printing at the start of the next new line.    
    0 COL ! 40 LINESTART +! \ Reset column, increase line.
    LINESTART @ $FCB0 = IF
	-40 LINESTART +!       \ Linestart back to last line.
	$F828 $F800 $488 CMOVE \ Scroll up
	$FC88 40 BL FILL       \ Blank bottom line
    THEN ;

: BACKSPACE ( ---)
\G Move the print position one character back.    
    COL @ IF  
	-1 COL +! \ Not at start of line, move 1 column back.
    ELSE
	LINESTART @ $F800 <> IF  
	    39 COL !            \ Not at start of screen, move to
	    -40 LINESTART +!    \ end of previous line.
	THEN
    THEN ;

: EMIT ( c ---)
\G Print character c on the screen. This implementation does not
\G use control characters. There are separate words for CR, BACKSPACE etc.    
    COL @ $28 = IF CR THEN
    LINESTART @ COL @ + C!
    1 COL +! ;

: PAGE ( ---)
\G Clear the screen and move print position to top left.
    $F800 LINESTART ! 0 COL ! $F800 $4B0 BL FILL ;

: AT-XY ( x y -- )
\G Set print position to column x and row y.    
    DUP 30 < IF 40 * $F800 + LINESTART ! ELSE DROP THEN
    DUP 40 < IF COL ! ELSE DROP THEN ;

: ROW@ ( --- y)
\G Return number of current row.    
  LINESTART @ $F800 - 40 / ;

: COUNT  ( c-addr1 --- c-addr2 c)
\G c-addr2 is the next address after c-addr1 and c is the character
\G stored at c-addr1.
\G This word is intended to be used with 'counted strings' where the
\G first character indicates the length of the string.
   DUP 1 + SWAP C@ ;

: TYPE ( c-addr1 u --- )
\G Output the string starting at c-addr and length u to the terminal.
  DUP IF 0 DO DUP I + C@ EMIT LOOP DROP ELSE DROP DROP THEN ;

: (.") ( --- )
\G Runtime part of ."
\ This expects an in-line counted string.
  R> COUNT OVER OVER TYPE + >R ;

: (S")  ( --- c-addr u )
\G Runtime part of S"
\ It returns address and length of an in-line counted string.
  R> COUNT OVER OVER + >R ;

: SPACE  ( ---)
\G Output a space to the terminal.
  32 EMIT ;

: SPACES ( u --- )
\G Output u spaces to the terminal.
  ?DUP IF 0 DO SPACE LOOP THEN ;

\ PART 8: NUMERIC OUTPUT WORDS.

VARIABLE BASE ( --- a-addr)
\G Variable that contains the numerical conversion base.

VARIABLE DP   ( --- a-addr)
\G Variable that contains the dictionary pointer. New space is allocated
\G from the address in DP
\ Allocated here because PAD is relative to it.

VARIABLE HLD ( --- a-addr)
\G Variable that holds the address of the numerical output conversion
\G character.

VARIABLE DPL ( --- a-addr)
\G Variable that holds the decimal point location for numerical conversion.

: DECIMAL ( --- )
\G Set numerical conversion to decimal.
  10 BASE ! ;

: HEX     ( --- )
\G Set numerical conversion to hexadecimal.
  16 BASE ! ;

: HERE ( --- c-addr )
\G The address of the dictionary pointer. New space is allocated here.
  DP @ ;

: PAD ( --- c-addr )
\G The address of a scratch pad area. Right below this address there is
\G the numerical conversion buffer.
  DP @ 84 + ;

: MU/MOD ( ud u --- urem udquot )
\G Divide unsigned double number ud by u and return a double quotient and
\G a single remainder.
  >R 0 R@ UM/MOD R> SWAP >R UM/MOD R> ;

\ The numerical conversion buffer starts right below PAD and grows down.
\ Characters are added to it from right to left, as as the div/mod algorithm
\ to convert numbers to an arbitrary base produces the digits from right to
\ left.

: HOLD ( c ---)
\G Insert character c into the numerical conversion buffer.
  1 NEGATE HLD +! HLD @ C! ;

: # ( ud1 --- ud2)
\G Extract the rightmost digit of ud1 and put it into the numerical
\G conversion buffer.
  BASE @ MU/MOD ROT DUP 9 > IF 7 + THEN 48 + HOLD ;

: #S ( ud --- 0 0 )
\G Convert ud by repeated use of # until ud is zero.
  BEGIN # OVER OVER OR 0= UNTIL ;

: SIGN ( n ---)
\G Insert a - sign in the numerical conversion buffer if n is negative.
  0< IF 45 HOLD THEN ;

: <# ( --- )
\G Reset the numerical conversion buffer.
  PAD HLD ! ;

: #> ( ud --- addr u )
\G Discard ud and give the address and length of the numerical conversion
\G buffer.
  DROP DROP HLD @ PAD OVER - ;

: D. ( d --- )
\G Type the double number d to the terminal.
  SWAP OVER DABS <# #S ROT SIGN #> TYPE SPACE ;

: U. ( u ---)
\G Type the unsigned number u to the terminal.
  0 D. ;

: . ( n ---)
\G Type the signed number n to the terminal.
  S>D D. ;

\ PART 9: Character Input

: KEY ( --- c)
\G Wait until a key is pressed and return the ASCII code    
   BEGIN  $200 C@ UNTIL $201 C@ 0 $200 C!  ;

: KEY? ( --- f)
\G Check if a key is pressed. Return a flag    
    $200 C@ 0= 0= ;

: ACCEPT ( c-addr n1 --- n2 )
\G Read a line from the terminal to a buffer starting at c-addr with
\G length n1. n2 is the number of characters read,
    >R 0
    BEGIN
	0 EMIT BACKSPACE
	KEY DUP 127 = 
	IF \ Backspace/delete
	    DROP DUP IF 1-  BL EMIT BACKSPACE BACKSPACE THEN 
	ELSE
	    DUP 13 = 
	    IF \ CR
		DROP SWAP DROP R> DROP SPACE EXIT      
	    ELSE
		DUP EMIT 
		OVER R@ - IF   
		    >R OVER OVER + R> SWAP C! 1+
		ELSE
		    DROP
		THEN
	    THEN 
	THEN 
    0 UNTIL         
;

\ PART 10: Source loading and parsing.
\ A single file can be loaded in memory from $8000 to $EFFE.

$8000 CONSTANT FILESTART ( --- addr)
\G Address where source file is stored in memory.

VARIABLE FILEEND ( --- addr)
\G Length of in-memory source file in bytes

VARIABLE FILEPTR ( --- addr)
\G Current address to load from in-memory source file.

$80 CONSTANT TIB ( --- addr)
\G is the standard terminal input buffer.

$FCB0 CONSTANT LINEBUF ( --- addr)
\G is the line buffer for line loaded from file.

VARIABLE SPAN ( --- addr)
\G This variable holds the number of characters read by EXPECT.

VARIABLE #TIB ( --- addr)
\G This variable holds the number of characters in the terminal input buffer.

VARIABLE >IN  ( --- addr)
\G This variable holds an index in the current input source where the next word
\G will be parsed.

VARIABLE SID  ( --- addr)
\G This variable holds the source i.d. returned by SOURCE-ID.

VARIABLE SRC  ( --- addr)
\G This variable holds the address of the current input source.

VARIABLE #SRC ( --- addr)
\G This variable holds the length of the current input source.

VARIABLE LOADLINE ( --- addr)
\G This variable holds the line number in the file being included.


: EXPECT ( c-addr u --- )
\G Read a line from the terminal to a buffer at c-addr with length u.
\G Store the length of the line in SPAN.
  ACCEPT SPAN ! ;

: QUERY ( --- )
\G Read a line from the terminal into the terminal input buffer.
  TIB 128 ACCEPT #TIB ! ;

: SOURCE ( --- addr len)
\G Return the address and length of the current input source.
   SRC @ #SRC @ ;

: SOURCE-ID ( --- sid)
\G Return the i.d. of the current source i.d., 0 for terminal, -1
\G for EVALUATE and positive number for INCLUDE file.
   SID @ ;

: REFILL ( --- f)
\G Refill the current input source when it is exhausted. f is
\G true if it was successfully refilled.
  SOURCE-ID -1 = IF
   0 \ Not refillable for EVALUATE
  ELSE
      SOURCE-ID IF
	  FILEPTR @ FILEEND @ OVER - 10 SCAN DROP
	  DUP  FILEEND @  = IF
	      DROP 0 EXIT
	  THEN
	  FILEPTR @ LINEBUF 2 PICK 2 PICK - DUP #SRC ! CMOVE
	  1+ FILEPTR !
	  LINEBUF SRC !
	  #SRC @ IF SOURCE OVER + SWAP DO
		  I C@ DUP 9 = SWAP 13 = OR  IF
		      32 I C!
		  THEN LOOP
	  THEN
	  1 LOADLINE +! 
      ELSE
	  QUERY #TIB @ #SRC !  \ Always successful from terminal.
      THEN
      0 >IN ! -1
  THEN
;

: PARSE ( c --- addr len )
\G Find a character sequence in the current source that is delimited by
\G character c. Adjust >IN to 1 past the end delimiter character.
  >R SOURCE >IN @ - SWAP >IN @ + R> OVER >R >R SWAP
  R@ SKIP OVER R> SWAP >R SCAN IF 1 >IN +! THEN
  DUP R@ - R> SWAP
  ROT R> - >IN +! ;

: PLACE ( addr len c-addr --- )
\G Place the string starting at addr with length len at c-addr as
\G a counted string.
  OVER OVER C!
  1+ SWAP CMOVE ;

: WORD ( c --- addr )
\G Parse a character sequence delimited by character c and return the
\G address of a counted string that is a copy of it. The counted
\G string is actually placed at HERE. The character after the counted
\G string is set to a space.
  PARSE HERE PLACE HERE BL HERE COUNT + C! ;

VARIABLE CAPS ( --- a-addr)
\G This variable contains a nonzero number if input is case insensitive.

: UPPERCASE? ( --- )
\G Convert the parsed word to uppercase is CAPS is true.
   CAPS @ HERE C@ AND IF
   HERE COUNT 0 DO
    DUP I + C@ DUP 96 > SWAP 123 < AND IF DUP I + DUP C@ 32 - SWAP C! THEN
   LOOP DROP
  THEN
;

\ PART 10: File load routines.
\ Only file load is defined here, file savea and other operations are
\ defined in extend80.4th

VARIABLE  PARAMBLK ( --- addr)
\G Parameter block for BIOS calls
34 ALLOT-T

: BIOSCALL ( code --- stat )
\G Call a Cerberus BIOS function 
    PARAMBLK $203 ! $202 C!
    BEGIN 126 $202 C@ 1- U< UNTIL $202 C@ 
;
: FILEOP ( addr len code "ccc" --- )
\G Do a file operation (load or save). addr is the start address in memory
\G of hte file data. len is the (maximum) file data length in bytes, code
\G is the BIOS function code, "ccc", a parsed word is the file name.    
    ROT PARAMBLK ! SWAP PARAMBLK CELL+ !
    PARAMBLK 4 + 32 0 FILL
    32 WORD COUNT 31 MIN PARAMBLK 4 + SWAP CMOVE
    BIOSCALL IF -38 THROW THEN ;

: BLOAD ( addr len "ccc" ---)
\G Load a file in memory at address addr, filename is the next word parsed.    
    2 FILEOP ;

: OPEN ( --- )
\G Load a file into the source file buffer.    
    FILESTART $EFFE FILESTART -
    2DUP 0 FILL
    2DUP BLOAD
    0 SCAN DROP FILEEND ! ;

\ PART 11: INTERPRETER HELPER WORDS

\ First we need FIND and related words.

\ Each word list consists of a number of linked list of definitions (number
\ is a power of 2). Hashing
\ is used to speed up dictionary search. All names in the dictionary
\ are at aligned addresses and FIND is optimized to compare one 4-byte
\ cell at a time.

\ Dictionary definitions are built as follows:
\
\ LINK field: 1 cell, aligned, contains name field of previous word in thread.
\ NAME field: counted string of at most 31 characters.
\             bits 5-7 of length byte have special meaning.
\                   7 is always set to mark start of name ( for >NAME)
\                   6 is set if the word is immediate.
\ CODE field: first aligned address after name, is execution token for word.
\             here the executable code for the word starts. (is 3 bytes for
\             variables etc.)
\ PARAMETER field: (body) Contains the data of constants and variables etc.

VARIABLE FORTH-WORDLIST ( --- addr)
6 CELLS-T ALLOT-T
\G This array holds pointers to the last definition of each thread in the Forth
\G word list.

VARIABLE LAST ( --- addr)
\G This variable holds a pointer to the last definition created.

VARIABLE CONTEXT 14 ALLOT-T ( --- a-addr)
\G This variable holds the addresses of up to 8 word lists that are
\G in the search order.

VARIABLE #ORDER ( --- addr)
\G This variable holds the number of word list that are in the search order.

VARIABLE CURRENT ( --- addr)
\G This variable holds the address of the word list to which new definitions
\G are added.

: HASH ( c-addr u #threads --- n)
\G Compute the hash function for the name c-addr u with the indicated number
\G of threads.
  >R OVER C@ 1 LSHIFT OVER 1 > IF ROT CHAR+ C@ 2 LSHIFT XOR ELSE ROT DROP
   THEN XOR
  R> 1- AND
;

: SEARCH-WORDLIST ( c-addr u wid --- 0 | xt 1 | xt -1)
\G Search the wordlist with address wid for the name c-addr u.
\G Return 0 if not found, the execution token xt and -1 for non-immediate
\G words and xt and 1 for immediate words.
  2+ >R
  2DUP R@ @ HASH 1+ CELLS R> + @ \ Get the right thread.
  DUP IF
    (FIND) DUP 0= IF 2DROP 0 THEN EXIT
  THEN
  2DROP DROP 0 \ Not found.
;

: FIND ( c-addr --- c-addr 0| xt 1|xt -1 )
\G Search all word lists in the search order for the name in the
\G counted string at c-addr. If not found return the name address and 0.
\G If found return the execution token xt and -1 if the word is non-immediate
\G and 1 if the word is immediate.
  #ORDER @ DUP 1 > IF
   CONTEXT #ORDER @ 1- CELLS + DUP @ SWAP CELL- @ =
  ELSE 0 THEN
  IF 1- THEN \ If last wordlist is double, don't search it twice.
  BEGIN
   DUP
  WHILE
   1- >R
   DUP COUNT
   R@ CELLS CONTEXT + @ SEARCH-WORDLIST
   DUP
   IF
    R> DROP ROT DROP EXIT \ Exit if found.
   THEN
   DROP R>
  REPEAT
;
END-CROSS
