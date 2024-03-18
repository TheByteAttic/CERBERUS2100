/*********************************************/
/**         CERBERUS 2100's BIOS code       **/
/**      Brought to you by The Byte Attic   **/
/**        For the ATmega328PB              **/
/**     To be compiled in the arduino IDE   **/
/** (use MiniCore library with 328PB MCU)   **/
/** Copyright 2020-2023 by Bernardo Kastrup **/
/**            All rights reserved          **/
/**      Code distributed under license     **/
/*********************************************/

/**
 * How to compile:
 *  - Use minicore library(https://github.com/MCUdude/MiniCore)
 *  - Select board ATmega328
 *  - Clock: External 16MHz
 *  - BOD: 4.3V
 *  - Varian: 328PB
 */

/** Provided AS-IS, without guarantees of any kind                        **/
/** This is NOT a commercial product as has not been exhaustively tested  **/

/** The directive "F()", which tells the compiler to put strings in code memory **/
/** instead of dynamic memory, is used as often as possible to save dynamic     **/
/** memory, the latter being the bottleneck of this code.                       **/

/** Updated By:		Dean Belfield	**/
/** Created:		31/07/2021		**/
/** Last Updated:	23/11/2021 		**/

//	Modinfo:
//	10/08/2021:	All recognised keystrokes sent to mailbox, F12 now returns to BIOS, 50hz NMI starts when code runs
//	11/08/2021:	Memory map now defined in configs, moved code start to 0x0205 to accomodate inbox
//	12/08/2021:	Refactored load, save and delFile. Now handles incoming messages from Z80/6502
//	21/08/2021:	Tweaks for sound command, bug fixes in incoming message handler
//  06/10/2021: Tweaks for cat command
//	23/11/2021:	Moved PS2Keyboard library from Arduino library to src subdirectory

/** Updated By:    Aleksandr Sharikhin **/
/** Created:    22/07/2023             **/
/** Last Updated: 22/07/2023           **/

// Modinfo:
// 22/07/2023: Working on Cerberus 2100. 
//             PS2 keyboard resets on start(more keyboards will work). 
//             Optimizing loading splash screen. 
//             Removed unused keymaps. 
//             One command basic loading. Non blocking sound API.
//             Updated load command - returning how many bytes was actually read
// 27/08/2023: EEPROM-based persistent settings for mode and CPU speed

/** Updated By: Jeroen Venema **/

// ModInfo:
// 03/02/2024: Native AVR Port statements used where possible in these functions:
//             setShiftRegister / readShiftRegister
//             cpoke / cpeek
// 03/02/2024: Changed cpeekW to use bitshifting for performance

/** These libraries are built into the arduino IDE  **/

#include <SPI.h>
#include <SD.h>
#include <TimerOne.h>
#include <EEPROM.h>

// Working with patched PS2 keyboard library
// Patches required for BBC Basic and for keeping more keyboards compatible
#include "src/PS2Keyboard/PS2Keyboard.h"

/** Compilation defaults **/
#define	config_dev_mode	0			// Turn off various BIOS outputs to speed up development, specifically uploading code
#define config_silent 0				// Turn off the startup jingle
#define config_enable_nmi 1			// Turn on the 50hz NMI timer when CPU is running. If set to 0 will only trigger an NMI on keypress
#define config_outbox_flag 0x0200	// Outbox flag memory location (byte)
#define config_outbox_data 0x0201	// Outbox data memory location (byte)
#define config_inbox_flag 0x0202	// Inbox flag memory location (byte)
#define config_inbox_data 0x0203	// Inbox data memory location (word)
#define config_code_start 0x0205	// Start location of code
#define config_eeprom_address_mode    0 // First EEPROM location
#define config_eeprom_address_speed   1 // Second EEPROM location

/** The next pins go to FAT-SPACER **/
#define SI 19      /** Serial Input, pin 28 on FAT-CAT **/
#define SI_PORT    PORTC
#define SI_PORTPIN PC5
#define SI_INPORT  PINC
#define SO 18      /** Serial Output, pin 27 on FAT-CAT **/
#define SO_PORT    PORTC
#define SO_PORTPIN PC4
#define SC 17      /** Shift Clock, pin 26 on FAT-CAT **/
#define SC_PORT    PORTC
#define SC_PORTPIN PC3
#define AOE 16     /** Address Output Enable, pin 25 on FAT-CAT **/
#define AOE_PORT   PORTC
#define AOE_PORTPIN PC2
#define RW 15      /** Memory Read/!Write, pin 24 on FAT-CAT **/
#define RW_PORT    PORTC
#define RW_PORTPIN PC1
#define LD 14      /** Latch Data, pin 23 on FAT-CAT **/
#define LD_PORT    PORTC
#define LD_PORTPIN PC0
#define CPUSLC 5   /** CPU SeLeCt, pin 9 on FAT-CAT **/
#define CPUIRQ 6   /** CPU Interrupt ReQuest, pin 10 on FAT-CAT **/
#define CPUGO 7    /** CPU Go/!Halt, pin 11 on FAT-CAT **/
#define CPURST 8   /** CPU ReSeT, pin 12 on FAT-CAT **/
#define CPUSPD 9    /** CPU CLocK Speed, pin 13 on FAT-CAT **/
#define FREE 25   /** Bit 2 of CPU CLocK Speed, pin 19 on FAT-CAT **/
/** The next pins go to I/O devices **/
#define KCLK 2     /** CLK pin connected to PS/2 keyboard (FAT-CAT pin 32) **/
#define KDAT 3     /** DATA pin connected to PS/2 keyboard (FAT-CAT pin 1) **/
#define SOUND 4    /** Sound output to buzzer, pin 2 on FAT-CAT **/
#define CS 10      /** Chip Select for SD Card, pin 14 on FAT-CAT **/
/** The next pins go to/come from the expansion port **/
#define XBUSACK 23 /** eXpansion BUS ACKnowledgment, pin 3 on FAT-CAT, active LOW **/
#define XBUSREQ 24 /** eXpansion BUS REQuest, pin 6 on FAT-CAT, active LOW **/
#define XIRQ 26    /** eXpansion Interrupt ReQuest, pin 22 on FAT-CAT, active LOW **/
/** MISO, MOSI and SCK for uSD-card are hardwired in FAT-CAT **/
/** SCK  -> pin 17 on FAT-CAT **/
/** MISO -> pin 16 on FAT-CAT **/
/** MOSI -> pin 15 on FAT-CAT **/

/** Now some stuff required by the libraries in use **/
const int chipSelect = CS;
const int DataPin = KDAT;
const int IRQpin = KCLK;

/* Status constants */
#define STATUS_DEFAULT 0
#define STATUS_BOOT 1
#define STATUS_READY 2
#define STATUS_UNKNOWN_COMMAND 3
#define STATUS_NO_FILE 4
#define STATUS_CANNOT_OPEN 5  
#define STATUS_MISSING_OPERAND 6
#define STATUS_SCROLL_PROMPT 7
#define STATUS_FILE_EXISTS 8
#define STATUS_ADDRESS_ERROR 9
#define STATUS_POWER 10
#define STATUS_EOF 11

/** Next is the string in CAT's internal memory containing the edit line, **/
/** intialized in startup.                              **/
volatile char editLine[38];
volatile char previousEditLine[38];
volatile uint16_t bytesRead;

/** The above is self-explanatory: it allows for repeating previous command **/
volatile byte pos = 1;						/** Position in edit line currently occupied by cursor **/
volatile bool mode = false;	/** false = 6502 mode, true = Z80 mode**/
volatile bool cpurunning = false;			/** true = CPU is running, CAT should not use the buses **/
volatile bool interruptFlag = false;		/** true = Triggered by interrupt **/
volatile bool fast = true;	/** true = 8 MHz CPU clock, false = 4 MHz CPU clock **/
 File cd;							/** Used by BASIC directory commands **/
 File fileHandle;                   /** Used by file open command **/
volatile bool expflag = false;
void(* resetFunc) (void) = 0;       		/** Software reset fuction at address 0 **/

PS2Keyboard keyboard;

// Interrupt service routine attached to pin XIRQ
ISR(PCINT3_vect) {
  expflag = true;
}


void setup() {
  /** Read previous settings from EEPROM**/
  mode = EEPROM.read(config_eeprom_address_mode);
  if((mode != 0) && (mode != 1))
  {
    mode = 0;
    EEPROM.write(config_eeprom_address_mode,0);
  }
  fast = EEPROM.read(config_eeprom_address_speed);
  if((fast != 0) && (fast != 1))
  {
    fast = 0;
    EEPROM.write(config_eeprom_address_speed,0);
  }
	/** First, declaring all the pins **/
  	pinMode(SO, OUTPUT);
  	pinMode(SI, INPUT);               /** There will be pull-up and pull-down resistors in circuit **/
  	pinMode(SC, OUTPUT);
  	pinMode(AOE, OUTPUT);
  	pinMode(LD, OUTPUT);
  	pinMode(RW, OUTPUT);
  	pinMode(CPUSPD, OUTPUT);
  	pinMode(KCLK, INPUT_PULLUP);      /** But here we need CAT's internal pull-up resistor **/
  	pinMode(KDAT, INPUT_PULLUP);      /** And here too **/
  	pinMode(CPUSLC, OUTPUT);
  	pinMode(CPUIRQ, OUTPUT);
  	pinMode(CPUGO, OUTPUT);
  	pinMode(CPURST, OUTPUT);
  	pinMode(SOUND, OUTPUT);
        pinMode(XBUSACK, OUTPUT);
  	/** Writing default values to some of the output pins **/
  	digitalWrite(RW, HIGH);
  	digitalWrite(SO, LOW);
  	digitalWrite(AOE, LOW);
  	digitalWrite(LD, LOW);
  	digitalWrite(SC, LOW);
  	digitalWrite(CPUSPD, fast);
  	digitalWrite(CPUSLC, mode);
  	digitalWrite(CPUIRQ, LOW);
  	digitalWrite(CPUGO, LOW);
  	digitalWrite(CPURST, LOW);
    digitalWrite(XBUSACK, HIGH);
	  // Attach an interrupt to XIRQ so to react to the expansion card timely
  	cli();	
	PCICR  |= 0b00001000;  // Enables Port E Pin Change Interrupts
	PCMSK3 |= 0b00001000;  // Enable Pin Change Interrupt on XIRQ
	sei();
  	/** Now reset the CPUs **/
  	resetCPUs();
  	/** Clear edit line **/
  	clearEditLine();
  	storePreviousLine();
  	Serial.begin(115200);
	/** Initialize keyboard library **/
  	keyboard.begin(DataPin, IRQpin);
	/** Reset keyboard */
    keyboard.send(0xFF);
  	/** Now access uSD card and load character definitions so we can put something on the screen **/
  	if (!SD.begin(chipSelect)) {
    	/** SD Card has either failed or is not present **/
    	/** Since the character definitions thus can't be uploaded, accuse error with repeated tone and hang **/
    	while(true) {
      		tone(SOUND, 50, 150);
      		delay(500);
    	}
  	}
  	/** Load character defs into memory **/
  	if(load("chardefs.bin", 0xf000) != STATUS_READY) {
		tone(SOUND, 50, 150);
	  }
  	/**********************************************************/
  	/** Now prepare the screen **/
  	ccls();
  	cprintFrames();
    cprintBanner();
  	
  	/**********************************************************/
  	cprintStatus(STATUS_BOOT);
  	/** Play a little jingle while keyboard finishes initializing **/
  	#if config_silent == 0
  	playJingle();
  	#endif
  	delay(1000);
  	cprintStatus(STATUS_DEFAULT);
  	cprintEditLine();
}

char readKey() {
	char ascii = 0;
	if(keyboard.available()) {
		ascii = keyboard.read();
    	tone(SOUND, 750, 5);            	/** Clicking sound for auditive feedback to key presses **/
		#if config_dev_mode == 0        	
  		if(!cpurunning) {
			cprintStatus(STATUS_DEFAULT);	/** Update status bar **/	
		}
		#endif 
	}
	else if(Serial.available()) {
		ascii = Serial.read();
	}
	return ascii;
}

// The main loop
//
void loop() {
	char ascii = readKey();	/** Stores ascii value of key pressed **/
	byte i;     			/** Just a counter **/

  	/** Wait for a key to be pressed, then take it from there... **/
	if(ascii > 0) {
    	if(cpurunning) {
    		if (ascii == PS2_F12) {  /** This happens if F1 has been pressed... and so on... **/
	    		stopCode();
    		}
    		else {
				cpurunning = false;						/** Just stops interrupts from happening **/
        		digitalWrite(CPUGO, LOW);   			/** Pause the CPU and tristate its buses to high-Z **/
      			byte mode = cpeek(config_outbox_flag);
      			cpoke(config_outbox_data, ascii);       /** Put token code of pressed key in the CPU's mailbox, at config_outbox_data **/
	         	cpoke(config_outbox_flag, 0x01);		/** Flag that there is new mail for the CPU waiting at the mailbox **/
      			digitalWrite(CPUGO, HIGH);  			/** Let the CPU go **/
				cpurunning = true;
      			#if config_enable_nmi == 0
      			digitalWrite(CPUIRQ, HIGH); /** Trigger an interrupt **/
      			digitalWrite(CPUIRQ, LOW);
      			#endif
    		}
    	}
    	else {
	 	   switch(ascii) {
	    		case PS2_ENTER:
		    		enter();
	    			break;
	    		case PS2_UPARROW:
		     	   	for (i = 0; i < 38; i++) editLine[i] = previousEditLine[i];
	        		i = 0;
        			while (editLine[i] != 0) i++;
        			pos = i;
        			cprintEditLine();
        			break;
        		case PS2_DOWNARROW:
		        	clearEditLine();
        			break;
        		case PS2_DELETE:
        		case PS2_LEFTARROW:
			        editLine[pos] = 32; /** Put an empty space in current cursor position **/
        			if (pos > 1) pos--; /** Update cursor position, unless reached left-most position already **/
        			editLine[pos] = 0;  /** Put cursor on updated position **/
        			cprintEditLine();   /** Print the updated edit line **/
        			break;
        		default:
		        	editLine[pos] = ascii;  /** Put new character in current cursor position **/
        			if (pos < 37) pos++;    /** Update cursor position **/
        			editLine[pos] = 0;      /** Place cursor to the right of new character **/
    				#if config_dev_mode == 0        	
		       		cprintEditLine();       /** Print the updated edit line **/
	       			#endif
        			break;        
			}
		}    
	}
	if(interruptFlag) {						/** If the interrupt flag is set then **/
		interruptFlag = false;
		messageHandler();					/** Run the inbox message handler **/
	}
	// Now we deal with bus access requests from the expansion card
  if (digitalRead(XBUSREQ) == LOW) { // The expansion card is requesting bus access... 
    if (cpurunning) { // If a CPU is running (the internal buses being therefore not tristated)...
      digitalWrite(CPUGO, LOW); // ...first pause the CPU and tristate the buses...
      digitalWrite(XBUSACK, LOW); // ...then acknowledge request; buses are now under the control of the expansion card
      while (digitalRead(XBUSREQ) == LOW); // Wait until the expansion card is done...
      digitalWrite(XBUSACK, HIGH); // ...then let the expansion card know that the buses are no longer available to it
      digitalWrite(CPUGO, HIGH); // Finally, let the CPU run again
    } else { // If a CPU is NOT running...
      digitalWrite(XBUSACK, LOW); // Acknowledge request; buses are now under the control of the expansion card
      while (digitalRead(XBUSREQ) == LOW); // Wait until the expansion card is done...
      digitalWrite(XBUSACK, HIGH); // ...then let the expansion card know that the buses are no longer available to it
    }
  }
  // And finally, deal with the expansion flag (which will be 'true' if there has been an XIRQ strobe from an expansion card)
  if (expflag) {
    if (cpurunning) {
      digitalWrite(CPUGO, LOW); // Pause the CPU and tristate its buses **/
      cpoke(0xEFFF, 0x01); // Flag that there is data from the expansion card waiting for the CPU in memory
      digitalWrite(CPUGO, HIGH); // Let the CPU go
      digitalWrite(CPUIRQ, HIGH); // Trigger an interrupt so the CPU knows there's data waiting for it in memory
      digitalWrite(CPUIRQ, LOW);
    }
    expflag = false; // Reset the flag
  }
}

// CPU Interrupt Routine (50hz)
//
void cpuInterrupt(void) {
  	if(cpurunning) {							// Only run this code if cpu is running 
	   	digitalWrite(CPUIRQ, HIGH);		 		// Trigger an NMI interrupt
	   	digitalWrite(CPUIRQ, LOW);
  	}
	interruptFlag = true;
}

// Inbox message handler
//
void messageHandler(void) {
  	int	flag, status;
  	byte retVal = 0x00;							// Return status; default is OK
  	unsigned int address;						// Pointer for data

 	if(cpurunning) {							// Only run this code if cpu is running 
	 	cpurunning = false;						// Just to prevent interrupts from happening
		digitalWrite(CPUGO, LOW); 				// Pause the CPU and tristate its buses to high-Z
		flag = cpeek(config_inbox_flag);		// Fetch the inbox flag 
		if(flag > 0 && flag < 0x80) {
			address = cpeekW(config_inbox_data);
			switch(flag) {
				case 0x01:
					cmdSound(address);
					break;
				case 0x02: 
					status = cmdLoad(address);
					if(status != STATUS_READY) {
						retVal = (byte)(status + 0x80);
					}
					break;
				case 0x03:
					status = cmdSave(address);
					if(status != STATUS_READY) {
						retVal = (byte)(status + 0x80);
					}
					break;
				case 0x04:
					status = cmdDelFile(address);
					if(status != STATUS_READY) {
						retVal = (byte)(status + 0x80);
					}
					break;
				case 0x05:
					status = cmdCatOpen(address);
					if(status != STATUS_READY) {
						retVal = (byte)(status + 0x80);
					}
					break;
				case 0x06:
					status = cmdCatEntry(address);
					if(status != STATUS_READY) {
						retVal = (byte)(status + 0x80);
					}
					break;
				case 0x07: 
					status = cmdFileOpen(address);
					if(status != STATUS_READY) {
						retVal = (byte)(status + 0x80);
					}
					break;
				case 0x08: 
					status = cmdFileClose(address);
					if(status != STATUS_READY) {
						retVal = (byte)(status + 0x80);
					}
					break;
				case 0x09: 
					status = cmdFileRead(address);
					if(status != STATUS_READY) {
						retVal = (byte)(status + 0x80);
					}
					break;
				case 0x0A: 
					status = cmdFileSeek(address);
					if(status != STATUS_READY) {
						retVal = (byte)(status + 0x80);
					}
					break;
        case 0x7E:
          cmdSoundNb(address);
          status = STATUS_READY;
          break;
				case 0x7F:
					resetFunc();
					break;
			}
			cpoke(config_inbox_flag, retVal);	// Flag we're done - values >= 0x80 are error codes
		}
		digitalWrite(CPUGO, HIGH);   			// Restart the CPU 
		cpurunning = true;
 	}
}

// Handle SOUND command from BASIC
//
void cmdSound(unsigned int address) {
  cmdSoundNb(address);
  
  unsigned int duration = cpeekW(address + 2) * 50;
	delay(duration);
}

// Non blocking SOUND command.
// Can be used for games/demos
void cmdSoundNb(unsigned int address) {
  unsigned int frequency = cpeekW(address);
  unsigned int duration = cpeekW(address + 2) * 50;
  tone(SOUND, frequency, duration);
}

// Handle ERASE command from BASIC
//
int cmdDelFile(unsigned int address) {
	cpeekStr(address, editLine, 38);
	return delFile((char *)editLine);	
}

// Handle LOAD command from BASIC
//
int cmdLoad(unsigned int address) {
  int result;
  unsigned int startAddr = cpeekW(address);
  cpeekStr(address + 4, editLine, 38);
  result = load((char *)editLine, startAddr);
  cpokeW(address+2, bytesRead);
  
  return result;
}

// Handle SAVE command from BASIC
//
int cmdSave(unsigned int address) {
	unsigned int startAddr = cpeekW(address);
	unsigned int length = cpeekW(address + 2);
	cpeekStr(address + 4, editLine, 38);
	return save((char *)editLine, startAddr, startAddr + length - 1);
}

// Handle CAT command from BASIC
//
int cmdCatOpen(unsigned int address) {
	cd = SD.open("/");						// Start the process first by opening the directory
	return STATUS_READY;
}

int cmdCatEntry(unsigned int address) {		// Subsequent calls to this will read the directory entries
	File entry;
	entry = cd.openNextFile();				// Open the next file
	if(!entry) {							// If we've read past the last file in the directory
		cd.close();							// Then close the directory
		return STATUS_EOF;					// And return end of file
	}
	cpokeL(address, entry.size());			// First four bytes are the length
	cpokeStr(address + 4, entry.name());	// Followed by the filename, zero terminated
	entry.close();							// Close the directory entry
	return STATUS_READY;					// Return READY
}

// Handle opening a file
int cmdFileOpen(unsigned int address) {
    cpeekStr(address, editLine, 38);
    return fileOpen((char *)editLine);
}

// Handle closing a file
int cmdFileClose(unsigned int address) {
    fileHandle.close();
    return STATUS_READY;
}

// Handle reading from a file
int cmdFileRead(unsigned int address) {
    int result;
    unsigned int startAddr = cpeekW(address);
    unsigned int byteCount = cpeekW(address+2);
    result = fileRead(startAddr, byteCount);
    cpokeW(address+2, bytesRead);
    return result;
}

// Handle seeking in a file
int cmdFileSeek(unsigned int address) {
    unsigned long filePosition = cpeekL(address);
    return fileHandle.seek(filePosition) ? STATUS_READY : STATUS_EOF;
}

/************************************************************************************************/
void enter() {  /** Called when the user presses ENTER, unless a CPU program is being executed **/
/************************************************************************************************/
  unsigned int addr;                /** Memory addresses **/
  byte data;                        /** A byte to be stored in memory **/
  byte i;                           /** Just a counter **/
  String nextWord, nextNextWord, nextNextNextWord; /** General-purpose strings **/
  nextWord = getNextWord(true);     /** Get the first word in the edit line **/
  nextWord.toLowerCase();           /** Ignore capitals **/
  if( nextWord.length() == 0 ) {    /** Ignore empty line **/
    Serial.println(F("OK"));
    return;
  }
  /** MANUAL ENTRY OF OPCODES AND DATA INTO MEMORY *******************************************/
  if ((nextWord.charAt(0) == '0') && (nextWord.charAt(1) == 'x')) { /** The user is entering data into memory **/
    nextWord.remove(0,2);                       /** Removes the "0x" at the beginning of the string to keep only a HEX number **/
    addr = strtol(nextWord.c_str(), NULL, 16);  /** Converts to HEX number type **/
    nextNextWord = getNextWord(false);          /** Get next byte **/
    byte chkA = 1;
    byte chkB = 0;
    while (nextNextWord != "") {                /** For as long as user has typed in a byte, store it **/
      if(nextNextWord.charAt(0) != '#') {
        data = strtol(nextNextWord.c_str(), NULL, 16);/** Converts to HEX number type **/
        while( cpeek(addr) != data ) {          /** Serial comms may cause writes to be missed?? **/
          cpoke(addr, data);
        }
        chkA += data;
        chkB += chkA;
        addr++;
      }
      else {
        nextNextWord.remove(0,1);
        addr = strtol(nextNextWord.c_str(), NULL, 16);
        if( addr != ((chkA << 8) | chkB) ) {
          cprintString(28, 26, nextWord);
          tone(SOUND, 50, 50);
        }
      }
      nextNextWord = getNextWord(false);  /** Get next byte **/
    }
    #if config_dev_mode == 0
    cprintStatus(STATUS_READY);
    cprintString(28, 27, nextWord);
    #endif
    Serial.print(nextWord);
    Serial.print(' ');
    Serial.println((uint16_t)((chkA << 8) | chkB), HEX);
    
  /** LIST ***********************************************************************************/
  } else if (nextWord == F("list")) {     /** Lists contents of memory in compact format **/
    cls();
    nextWord = getNextWord(false);        /** Get address **/
    list(nextWord);
    cprintStatus(STATUS_READY);
  /** CLS ************************************************************************************/
  } else if (nextWord == F("cls")) {      /** Clear the main window **/
    cls();
    cprintStatus(STATUS_READY);
  /** TESTMEM ********************************************************************************/
  } else if (nextWord == F("testmem")) {  /** Checks whether all four memories can be written to and read from **/
    cls();
    testMem();
    cprintStatus(STATUS_READY);
  /** 6502 ***********************************************************************************/
  } else if (nextWord == F("6502")) {     /** Switches to 6502 mode **/
    mode = false;
    EEPROM.write(config_eeprom_address_mode,0);
    digitalWrite(CPUSLC, LOW);            /** Tell CAT of the new mode **/
    cprintStatus(STATUS_READY);
  /** Z80 ***********************************************************************************/
  } else if (nextWord == F("z80")) {      /** Switches to Z80 mode **/
    mode = true;
    EEPROM.write(config_eeprom_address_mode,1);
    digitalWrite(CPUSLC, HIGH);           /** Tell CAT of the new mode **/
    cprintStatus(STATUS_READY);
  /** RESET *********************************************************************************/
  } else if (nextWord == F("reset")) {
    resetFunc();						  /** This resets CAT and, therefore, the CPUs too **/
  /** FAST **********************************************************************************/
  } else if (nextWord == F("fast")) {     /** Sets CPU clock at 8 MHz **/
    digitalWrite(CPUSPD, HIGH);
    fast = true;
    EEPROM.write(config_eeprom_address_speed,1);
    cprintStatus(STATUS_READY);
  /** SLOW **********************************************************************************/
  } else if (nextWord == F("slow")) {     /** Sets CPU clock at 4 MHz **/
    digitalWrite(CPUSPD, LOW);
    fast = false;
    EEPROM.write(config_eeprom_address_speed,0);
    cprintStatus(STATUS_READY);
  /** DIR ***********************************************************************************/
  } else if (nextWord == F("dir")) {      /** Lists files on uSD card **/
    dir();
  /** DEL ***********************************************************************************/
  } else if (nextWord == F("del")) {      /** Deletes a file on uSD card **/
    nextWord = getNextWord(false);
    catDelFile(nextWord);
  /** LOAD **********************************************************************************/
  } else if (nextWord == F("load")) {     /** Loads a binary file into memory, at specified location **/
    nextWord = getNextWord(false);        /** Get the file name from the edit line **/
    nextNextWord = getNextWord(false);    /** Get memory address **/
    catLoad(nextWord, nextNextWord, false);
  /** RUN ***********************************************************************************/
  } else if (nextWord == F("run")) {      /** Runs the code in memory **/
    for (i = 0; i < 38; i++) previousEditLine[i] = editLine[i]; /** Store edit line just executed **/
    runCode();
  /** SAVE **********************************************************************************/
  } else if (nextWord == F("basic6502")) {
    mode = false;
    digitalWrite(CPUSLC, LOW);
    catLoad("basic65.bin","", false); 
    runCode();
  } else if (nextWord == F("basicz80")) {
    mode = true;
    digitalWrite(CPUSLC, HIGH);
    catLoad("basicz80.bin","", false); 
    runCode();
  } else if (nextWord == F("save")) {
    nextWord = getNextWord(false);						/** Start start address **/
    nextNextWord = getNextWord(false);					/** End address **/
    nextNextNextWord = getNextWord(false);				/** Filename **/
    catSave(nextNextNextWord, nextWord, nextNextWord);
  /** MOVE **********************************************************************************/
  } else if (nextWord == F("move")) {
    nextWord = getNextWord(false);
    nextNextWord = getNextWord(false);
    nextNextNextWord = getNextWord(false);
    binMove(nextWord, nextNextWord, nextNextNextWord);
  /** HELP **********************************************************************************/
  } else if ((nextWord == F("help")) || (nextWord == F("?"))) {
    help();
    cprintStatus(STATUS_POWER);
  /** ALL OTHER CASES ***********************************************************************/
  } else cprintStatus(STATUS_UNKNOWN_COMMAND);
  if (!cpurunning) {
    storePreviousLine();
    clearEditLine();                   /** Reset edit line **/
  }
}

String getNextWord(bool fromTheBeginning) {
  /** A very simple parser that returns the next word in the edit line **/
  static byte initialPosition;    /** Start parsing from this point in the edit line **/
  byte i, j, k;                   /** General-purpose indices **/
  if (fromTheBeginning) initialPosition = 1; /** Starting from the beginning of the edit line **/
  i = initialPosition;            /** Otherwise, continuing on from where we left off in previous call **/
  while ((editLine[i] == 32) || (editLine[i] == 44)) i++; /** Ignore leading spaces or commas **/
  j = i + 1;                      /** Now start indexing the next word proper **/
  /** Find the end of the word, marked either by a space, a comma or the cursor **/
  while ((editLine[j] != 32) && (editLine[j] != 44) && (editLine[j] != 0)) j++;
  char nextWord[j - i + 1];       /** Create a buffer (the +1 is to make space for null-termination) **/
  for (k = i; k < j; k++) nextWord[k - i] = editLine[k]; /** Transfer the word to the buffer **/
  nextWord[j - i] = 0;            /** Null-termination **/
  initialPosition = j;            /** Next time round, start from here, unless... **/
  return (nextWord);              /** Return the contents of the buffer **/
}

void help() {
  cls();
  cprintString(3, 2,  F("The Byte Attic's CERBERUS 2100 (tm)"));
  cprintString(3, 3,  F("        AVAILABLE COMMANDS:"));
  cprintString(3, 4,  F(" (All numbers must be hexadecimal)"));
  cprintString(3, 6,  F("0xADDR BYTE: Writes BYTE at ADDR"));
  cprintString(3, 7,  F("list ADDR: Lists memory from ADDR"));
  cprintString(3, 8,  F("cls: Clears the screen"));
  cprintString(3, 9,  F("testmem: Reads/writes to memories"));
  cprintString(3, 10, F("6502: Switches to 6502 CPU mode"));
  cprintString(3, 11, F("z80: Switches to Z80 CPU mode"));
  cprintString(3, 12, F("fast: Switches to 8MHz mode"));
  cprintString(3, 13, F("slow: Switches to 4MHz mode"));
  cprintString(3, 14, F("reset: Resets the system"));
  cprintString(3, 15, F("dir: Lists files on uSD card"));
  cprintString(3, 16, F("del FILE: Deletes FILE"));
  cprintString(3, 17, F("load FILE ADDR: Loads FILE at ADDR"));
  cprintString(3, 18, F("save ADDR1 ADDR2 FILE: Saves memory"));
  cprintString(5, 19, F("from ADDR1 to ADDR2 to FILE"));
  cprintString(3, 20, F("run: Executes code in memory"));
  cprintString(3, 21, F("move ADDR1 ADDR2 ADDR3: Moves bytes"));
  cprintString(5, 22, F("between ADDR1 & ADDR2 to ADDR3 on"));
  cprintString(3, 23, F("help / ?: Shows this help screen"));
  cprintString(3, 24, F("F12 key: Quits CPU program"));
}

void binMove(String startAddr, String endAddr, String destAddr) {
  unsigned int start, finish, destination;                /** Memory addresses **/
  unsigned int i;                                         /** Address counter **/
  if (startAddr == "") cprintStatus(STATUS_MISSING_OPERAND);                   /** Missing the file's name **/
  else {
    start = strtol(startAddr.c_str(), NULL, 16);          /** Convert hexadecimal address string to unsigned int **/
    if (endAddr == "") cprintStatus(STATUS_MISSING_OPERAND);                   /** Missing the file's name **/
    else {
      finish = strtol(endAddr.c_str(), NULL, 16);         /** Convert hexadecimal address string to unsigned int **/
      if (destAddr == "") cprintStatus(STATUS_MISSING_OPERAND);                /** Missing the file's name **/
      else {
        destination = strtol(destAddr.c_str(), NULL, 16); /** Convert hexadecimal address string to unsigned int **/
        if (finish < start) cprintStatus(STATUS_ADDRESS_ERROR);              /** Invalid address range **/
        else if ((destination <= finish) && (destination >= start)) cprintStatus(STATUS_ADDRESS_ERROR); /** Destination cannot be within original range **/  
        else {
          for (i = start; i <= finish; i++) {
            cpoke(destination, cpeek(i));
            destination++;
          }
          cprintStatus(STATUS_READY);
        }
      }
    }
  }
}

void list(String address) {
  /** Lists the contents of memory from the given address, in a compact format **/
  byte i, j;                      /** Just counters **/
  unsigned int addr;              /** Memory address **/
  if (address == "") addr = 0;
  else addr = strtol(address.c_str(), NULL, 16); /** Convert hexadecimal address string to unsigned int **/
  for (i = 2; i < 25; i++) {
    cprintString(3, i, "0x");
    cprintString(5, i, String(addr, HEX));
    for (j = 0; j < 8; j++) {
      cprintString(12+(j*3), i, String(cpeek(addr++), HEX)); /** Print bytes in HEX **/
    }
  }
}

void runCode() {
  byte runL = config_code_start & 0xFF;
  byte runH = config_code_start >> 8;

  ccls();
  /** REMEMBER:                           **/
  /** Byte at config_outbox_flag is the new mail flag **/
  /** Byte at config_outbox_data is the mail box      **/
  cpoke(config_outbox_flag, 0x00);	/** Reset outbox mail flag	**/
  cpoke(config_outbox_data, 0x00);	/** Reset outbox mail data	**/
  cpoke(config_inbox_flag, 0x00);	/** Reset inbox mail flag	**/
  if (!mode) {            /** We are in 6502 mode **/
    /** Non-maskable interrupt vector points to 0xFCB0, just after video area **/
    cpoke(0xFFFA, 0xB0);
    cpoke(0xFFFB, 0xFC);
    /** The interrupt service routine simply returns **/
    // FCB0        RTI             40
    cpoke(0xFCB0, 0x40);
    /** Set reset vector to config_code_start, the beginning of the code area **/
    cpoke(0xFFFC, runL);
    cpoke(0xFFFD, runH);
  } else {                /** We are in Z80 mode **/
    /** The NMI service routine of the Z80 is at 0x0066 **/
    /** It simply returns **/
    // 0066   ED 45                  RETN 
    cpoke(0x0066, 0xED);
    cpoke(0x0067, 0x45);
    /** The Z80 fetches the first instruction from 0x0000, so put a jump to the code area there **/
    // 0000   C3 ll hh               JP   config_code_start
	#if config_code_start != 0x0000
    cpoke(0x0000, 0xC3);
    cpoke(0x0001, runL);
    cpoke(0x0002, runH);
	#endif
  }
  cpurunning = true;
  digitalWrite(CPURST, HIGH); /** Reset the CPU **/
  digitalWrite(CPUGO, HIGH);  /** Enable CPU buses and clock **/
  delay(50);
  digitalWrite(CPURST, LOW);  /** CPU should now initialize and then go to its reset vector **/
  #if config_enable_nmi == 1
  Timer1.initialize(20000);
  Timer1.attachInterrupt(cpuInterrupt); /** Interrupt every 0.02 seconds - 50Hz **/
  #endif
}

void stopCode() {
    cpurunning = false;         /** Reset this flag **/
    Timer1.detachInterrupt();
    digitalWrite(CPURST, HIGH); /** Reset the CPU to bring its output signals back to original states **/ 
    digitalWrite(CPUGO, LOW);   /** Tristate its buses to high-Z **/
    delay(50);                   /** Give it some time **/
    digitalWrite(CPURST, LOW);  /** Finish reset cycle **/

    load("chardefs.bin", 0xf000);/** Reset the character definitions in case the CPU changed them **/
    ccls();                     /** Clear screen completely **/
    cprintFrames();             /** Reprint the wire frame in case the CPU code messed with it **/
    cprintBanner();
    cprintStatus(STATUS_DEFAULT);            /** Update status bar **/
    clearEditLine();            /** Clear and display the edit line **/
}

void dir() {
  /** Lists the files in the root directory of uSD card, if available **/
  byte y = 2;                     /** Screen line **/
  byte x = 0;                     /** Screen column **/
  File root;                      /** Root directory of uSD card **/
  File entry;                     /** A file on the uSD card **/
  cls();
  root = SD.open("/");            /** Go to the root directory of uSD card **/
  while (true) {
    entry = root.openNextFile();  /** Open next file **/
    if (!entry) {                 /** No more files on the uSD card **/
      root.close();               /** Close root directory **/
      cprintStatus(STATUS_READY);            /** Announce completion **/
      break;                      /** Get out of this otherwise infinite while() loop **/
    }
    cprintString(3, y, entry.name());
    cprintString(20, y, String(entry.size(), DEC));
    entry.close();                /** Close file as soon as it is no longer needed **/
    if (y < 24) y++;              /** Go to the next screen line **/
    else {
      cprintStatus(STATUS_SCROLL_PROMPT);            /** End of screen has been reached, needs to scrow down **/
      for (x = 2; x < 40; x++) cprintChar(x, 29, ' '); /** Hide editline while waiting for key press **/
      while (!keyboard.available());/** Wait for a key to be pressed **/
      if (keyboard.read() == PS2_ESC) { /** If the user pressed ESC, break and exit **/
        tone(SOUND, 750, 5);      /** Clicking sound for auditive feedback to key press **/
        root.close();             /** Close the directory before exiting **/
        cprintStatus(STATUS_READY);
        break;
      } else {
        tone(SOUND, 750, 5);      /** Clicking sound for auditive feedback to key press **/
        cls();                    /** Clear the screen and... **/
        y = 2;                    /** ...go back tot he top of the screen **/
      }
    }
  }
}

void catDelFile(String filename) {
	cprintStatus(delFile(filename));
}

int delFile(String filename) {
	int status = STATUS_DEFAULT;
  	/** Deletes a file from the uSD card **/
  	if (!SD.exists(filename)) {
		status = STATUS_NO_FILE;		/** The file doesn't exist, so stop with error **/
	}
  	else {
	    SD.remove(filename);          /** Delete the file **/
	    status = STATUS_READY;
  	}
	return status;
}

void catSave(String filename, String startAddress, String endAddress) {
	unsigned int startAddr;
	unsigned int endAddr;
	int status = STATUS_DEFAULT;
   	if (startAddress == "") {
		status = STATUS_MISSING_OPERAND;               /** Missing operand **/
	}
	else {
		startAddr = strtol(startAddress.c_str(), NULL, 16);
		if(endAddress == "") {
			status = STATUS_MISSING_OPERAND;
		}
		else {
			endAddr = strtol(endAddress.c_str(), NULL, 16);
			status = save(filename, startAddr, endAddr);
		}
	}
	cprintStatus(status);
}

int save(String filename, unsigned int startAddress, unsigned int endAddress) {
  	/** Saves contents of a region of memory to a file on uSD card **/
	int status = STATUS_DEFAULT;
  	unsigned int i;                                     /** Memory address counter **/
  	byte data;                                          /** Data from memory **/
  	File dataFile;                                      /** File to be created and written to **/
	if (endAddress < startAddress) {
		status = STATUS_ADDRESS_ERROR;            		/** Invalid address range **/
	}
	else {
		if (filename == "") {
			status = STATUS_MISSING_OPERAND;          	/** Missing the file's name **/
		}
		else {
			if (SD.exists(filename)) {
				status = STATUS_FILE_EXISTS;   				/** The file already exists, so stop with error **/
			}
			else {
				dataFile = SD.open(filename, FILE_WRITE); /** Try to create the file **/
				if (!dataFile) {
					status = STATUS_CANNOT_OPEN;           /** Cannot create the file **/
				}
				else {                                    /** Now we can finally write into the created file **/
					for(i = startAddress; i <= endAddress; i++) {
						data = cpeek(i);
						dataFile.write(data);
					}
					dataFile.close();
					status = STATUS_READY;
				}
			}
		}
	}
	return status;
}

void catLoad(String filename, String startAddress, bool silent) {
	unsigned int startAddr;
	int status = STATUS_DEFAULT;
	if (startAddress == "") {
		startAddr = config_code_start;	/** If not otherwise specified, load file into start of code area **/
	}
	else {
		startAddr = strtol(startAddress.c_str(), NULL, 16);	/** Convert address string to hexadecimal number **/
	}
	status = load(filename, startAddr);
	if(!silent) {
		cprintStatus(status);
	}
}

int load(String filename, unsigned int startAddr) {
  /** Loads a binary file from the uSD card into memory **/
  File dataFile;                                /** File for reading from on SD Card, if present **/
  unsigned int addr = startAddr;                /** Address where to load the file into memory **/
  int status = STATUS_DEFAULT;
  if (filename == "") {
	  status = STATUS_MISSING_OPERAND;
  }
  else {
    if (!SD.exists(filename)) {
		status = STATUS_NO_FILE;				/** The file does not exist, so stop with error **/
	} 
    else {
      	dataFile = SD.open(filename);           /** Open the binary file **/
      	if (!dataFile) {
			status = STATUS_CANNOT_OPEN; 		/** Cannot open the file **/
	  	}
      	else {
			bytesRead = 0;
        	while (dataFile.available()) {		/** While there is data to be read... **/
          	bytesRead++;
          	cpoke(addr++, dataFile.read());     /** Read data from file and store it in memory **/
          	if (addr == 0) {                    /** Break if address wraps around to the start of memory **/
            	dataFile.close();
            	break;
          	}
        }
        dataFile.close();
		status = STATUS_READY;
      }
    }
  }
  return status;
}

int fileOpen(String filename)
{
    int status = STATUS_DEFAULT;
    if (filename == "") {
	    status = STATUS_MISSING_OPERAND;
    } else {
        if (!SD.exists(filename)) {
            status = STATUS_NO_FILE;
        } else {
            fileHandle = SD.open(filename);
            if (!fileHandle) {
                status = STATUS_CANNOT_OPEN;
            } else {
                status = STATUS_READY;
            }
        }
    }
    return status;
}

int fileRead(unsigned int address, unsigned int byteCount)
{
    bytesRead = 0;
    while (byteCount > 0 && fileHandle.available()) {   /** While we haven't read enough data and there is data to be read... **/
        byteCount--;
        bytesRead++;
        cpoke(address++, fileHandle.read());   /** Read data from file and store it in memory **/
        if (address == 0) {                    /** Break if address wraps around to the start of memory **/
           	break;
        }
    }
    return STATUS_READY;
}

void cprintEditLine () {
  	byte i;
  	for (i = 0; i < 38; i++) cprintChar(i + 2, 29, editLine[i]);
}

void clearEditLine() {
  	/** Resets the contents of edit line and reprints it **/
  	byte i;
  	editLine[0] = 62;
  	editLine[1] = 0;
  	for (i = 2; i < 38; i++) editLine[i] = 32;
  	pos = 1;
  	cprintEditLine();
}

void storePreviousLine() {
	for (byte i = 0; i < 38; i++) previousEditLine[i] = editLine[i]; /** Store edit line just executed **/
}

void cprintStatus(byte status) {
  	/** REMEMBER: The macro "F()" simply tells the compiler to put the string in code memory, so to save dynamic memory **/
  	switch( status ) {
    	case STATUS_BOOT:
      		center(F("Here we go! Hang on..."));
      		break;
    	case STATUS_READY:
      		center(F("Alright, done!"));
      		break;
    	case STATUS_UNKNOWN_COMMAND:
      		center(F("Darn, unrecognized command"));
      		tone(SOUND, 50, 150);
      		break;
    	case STATUS_NO_FILE:
      		center(F("Oops, file doesn't seem to exist"));
      		tone(SOUND, 50, 150);
      		break;
    	case STATUS_CANNOT_OPEN:
      		center(F("Oops, couldn't open the file"));
      		tone(SOUND, 50, 150);
      		break;
    	case STATUS_MISSING_OPERAND:
      		center(F("Oops, missing an operand!!"));
      		tone(SOUND, 50, 150);
      		break;
    	case STATUS_SCROLL_PROMPT:
      		center(F("Press a key to scroll, ESC to stop"));
      		break;
    	case STATUS_FILE_EXISTS:
      		center(F("The file already exists!"));
      	break;
    		case STATUS_ADDRESS_ERROR:
      	center(F("Oops, invalid address range!"));
      		break;
    	case STATUS_POWER:
      		center(F("Feel the power of Dutch design!!"));
      		break;
    	default:
      		cprintString(2, 27, F("      CERBERUS 2100: "));
      		if (mode) cprintString(23, 27, F(" Z80, "));
      		else cprintString(23, 27, F("6502, "));
      		if (fast) cprintString(29, 27, F("8 MHz"));
      		else cprintString(29, 27, F("4 MHz"));
      		cprintString(34, 27, F("     "));
  	}
}

void center(String text) {
  	clearLine(27);
  	cprintString(2+(38-text.length())/2, 27, text);
}

void playJingle() {
  	delay(500);           /** Wait for possible preceding keyboard click to end **/
  	tone(SOUND, 261, 50);
  	delay(150);
  	tone(SOUND, 277, 50);
  	delay(150);
  	tone(SOUND, 261, 50);
  	delay(150);
  	tone(SOUND, 349, 500);
  	delay(250);
  	tone(SOUND, 261, 50);
  	delay(150);
  	tone(SOUND, 349, 900);
}

void cls() {
  	/** This clears the screen only WITHIN the main frame **/
  	unsigned int y;
  	for (y = 2; y <= 25; y++) {
    	clearLine(y);
	}
}

void clearLine(byte y) {
  	unsigned int x;
  	for (x = 2; x <= 39; x++) {
    	cprintChar(x, y, 32);
	}
}

void ccls() {
  	/** This clears the entire screen **/
  	unsigned int x;
  	for (x = 0; x < 1200; x++) {
	    cpoke(0xF800 + x, 32);        /** Video memory addresses start at 0XF800 **/
	}
}

void cprintFrames() {
  unsigned int x;
  unsigned int y;
  /** First print horizontal bars **/
  for (x = 2; x <= 39; x++) {
    cprintChar(x, 1, 3);
    cprintChar(x, 30, 131);
    cprintChar(x, 26, 3);
  }
  /** Now print vertical bars **/
  for (y = 1; y <= 30; y++) {
    cprintChar(1, y, 160);
    cprintChar(40, y, 160);
  }
}

void cprintBanner() {
	/** Load the CERBERUS icon image on the screen ************/
  	int inChar;
  	if(!SD.exists("cerbicon.img")) {
		tone(SOUND, 50, 150); /** Tone out an error if file is not available **/
	}
  	else {
    	File dataFile2 = SD.open("cerbicon.img"); /** Open the image file **/
    	if (!dataFile2) {
			tone(SOUND, 50, 150);     /** Tone out an error if file can't be opened  **/
		}
    	else {
      		for (byte y = 3; y <= 25; y++) {
        		for (byte x = 2; x <= 39; x++) {
					inChar = dataFile2.read();
					
          			cprintChar(x, y, inChar);
        		}
			}
      		dataFile2.close();
    	}
  	}
}

void cprintString(byte x, byte y, String text) {
  	unsigned int i;
  	for (i = 0; i < text.length(); i++) {
	    if (((x + i) > 1) && ((x + i) < 40)) {
			cprintChar(x + i, y, text[i]);
		}
  	}
}

void cprintChar(byte x, byte y, byte token) {
  	/** First, calculate address **/
  	unsigned int address = 0xF800 + ((y - 1) * 40) + (x - 1); /** Video memory addresses start at 0XF800 **/
  	cpoke(address, token);
}

void testMem() {
  	/** Tests that all four memories are accessible for reading and writing **/
  	unsigned int x;
  	byte i = 0;
    for (x = 0; x < 874; x++) {
    	cpoke(x, i);                                           /** Write to low memory **/
    	cpoke(0x8000 + x, cpeek(x));                           /** Read from low memory and write to high memory **/
    	cpoke(addressTranslate(0xF800 + x), cpeek(0x8000 + x));/** Read from high mem, write to VMEM, read from character mem **/
    	if (i < 255) i++;
    	else i = 0;
  	}
}

unsigned int addressTranslate (unsigned int virtualAddress) {
  	byte numberVirtualRows;
  	numberVirtualRows = (virtualAddress - 0xF800) / 38;
  	return((virtualAddress + 43) + (2 * (numberVirtualRows - 1)));
}

void resetCPUs() {            	/** Self-explanatory **/
  	digitalWrite(CPURST, LOW);
  	digitalWrite(CPUSLC, LOW);  /** First reset the 6502 **/
  	digitalWrite(CPUGO, HIGH);
  	delay(50);
  	digitalWrite(CPURST, HIGH);
  	digitalWrite(CPUGO, LOW);
  	delay(50);
  	digitalWrite(CPURST, LOW);
  	digitalWrite(CPUSLC, HIGH); /** Now reset the Z80 **/
  	digitalWrite(CPUGO, HIGH);
  	delay(50);
  	digitalWrite(CPURST, HIGH);
  	digitalWrite(CPUGO, LOW);
  	delay(50);
  	digitalWrite(CPURST, LOW);
  	if (!mode) {
		  digitalWrite(CPUSLC, LOW);
	}
}

byte readShiftRegister() {
  uint8_t data = 0;
  uint8_t mask = 0x80;

  for (uint8_t i = 0; i < 8; ++i) {
    digitalWrite(SC, HIGH);       // timing issues, if we use direct port access here (spacer might not be ready)
    if(SI_INPORT & (1 << SI_PORTPIN)) data |= mask;
    SC_PORT &= ~(1 << SC_PORTPIN);
    mask = mask >> 1;
  }
  return data;
}

void shiftOutFast(uint8_t val) {
  // Fast shiftOut
  // clockPin == SO (PORTC / PC4)
  // dataPin  == SC (PORTC / PC3)
  // LSBFIRST ONLY

  for(uint8_t i = 0; i< 8; i++) {
    if(val & 1) {
      SO_PORT |= (1 << SO_PORTPIN);
    }
    else {
      SO_PORT &= ~(1 << SO_PORTPIN);
    }
    val >>= 1;
    SC_PORT |= (1 << SC_PORTPIN);
    SC_PORT &= ~(1 << SC_PORTPIN);
  }
}

void setShiftRegister(unsigned int address, byte data) { 
  shiftOutFast(address);      /** First 8 bits of address **/
  shiftOutFast(address >> 8); /** Then the remaining 8 bits **/
  shiftOutFast(data);         /** Finally, a byte of data **/
}

void cpoke(unsigned int address, byte data) {
 	setShiftRegister(address, data);
  AOE_PORT |= (1 << AOE_PORTPIN); //digitalWrite(AOE, HIGH);      /** Enable address onto bus **/
  RW_PORT &= ~(1 << RW_PORTPIN);  //digitalWrite(RW, LOW);        /** Begin writing **/
  RW_PORT |= (1 << RW_PORTPIN);   //digitalWrite(RW, HIGH);       /** Finish up**/
  AOE_PORT &= ~(1 << AOE_PORTPIN);
}

void cpokeW(unsigned int address, unsigned int data) {
	cpoke(address, data & 0xFF);
	cpoke(address + 1, (data >> 8) & 0xFF);
}

void cpokeL(unsigned int address, unsigned long data) {
	cpoke(address, data & 0xFF);
	cpoke(address + 1, (data >> 8) & 0xFF);
	cpoke(address + 2, (data >> 16) & 0xFF);
	cpoke(address + 3, (data >> 24) & 0xFF);
}

boolean cpokeStr(unsigned int address, String text) {
	unsigned int i;
	for(i = 0; i < text.length(); i++) {
		cpoke(address + i, text[i]);
	}
	cpoke(address + i, 0);
	return true;
}

byte cpeek(unsigned int address) {
 	byte data = 0;
 	setShiftRegister(address, data);
  AOE_PORT |= (1 << AOE_PORTPIN); //digitalWrite(AOE, HIGH);      /** Enable address onto bus **/
 	/** This time we do NOT enable the data outputs of the shift register, as we are reading **/
 	LD_PORT |= (1 << LD_PORTPIN);   //digitalWrite(LD, HIGH);       /** Prepare to latch byte from data bus into shift register **/
 	SC_PORT |= (1 << SC_PORTPIN);   //digitalWrite(SC, HIGH);       /** Now the clock tics, so the byte is actually latched **/
 	LD_PORT &= ~(1 << LD_PORTPIN);  //digitalWrite(LD, LOW);
  AOE_PORT &= ~(1 << AOE_PORTPIN);//digitalWrite(AOE, LOW);
 	data = readShiftRegister();
 	return data;
}

unsigned int cpeekW(unsigned int address) {
  return (cpeek(address) | (cpeek(address+1) << 8));
}

unsigned long cpeekL(unsigned int address) {
  return (((unsigned long)cpeek(address)) | (((unsigned long)cpeek(address+1)) << 8) | (((unsigned long)cpeek(address+2)) << 16) | (((unsigned long)cpeek(address+3)) << 24));
}

boolean cpeekStr(unsigned int address, volatile char * dest, int max) {
	unsigned int i;
	byte c;
	for(i = 0; i < max; i++) {
		c = cpeek(address + i);
		dest[i] = c;
		if(c == 0) return true;
	}
	return false;
}
