/**
 * This file prepares startup logo for Cerberus 2100
 **/
#include <stdio.h>

#define F(x) x
#define W 38
#define H 24

char buffer[H][W];

void cprintChar(char x, char y, char token) {
    buffer[y-2][x-2]=token;
}

void cprintString(char x, char y, char* text) {
    unsigned int i;
    for (i = 0; text[i]!=0; i++) {
        if (((x + i) > 1) && ((x + i) < 40)) {
	    cprintChar(x + i, y, text[i]);
	}
    }
}

int main() {
  cprintChar(14, 4, 13);
  cprintChar(16, 4, 22);
  cprintChar(18, 4, 23);
  cprintChar(20, 4, 24);
  cprintChar(22, 4, 25);
  cprintChar(24, 4, 26);
  cprintChar(26, 4, 27);
  cprintString(2, 6,  F("  ___ ___ ___  ___ ___ ___ _   _ ___"));
  cprintString(2, 7,  F(" / __| __| _ \\| _ ) __| _ \\ | | / __|"));
  cprintString(2, 8,  F(" |(__| _||   /| _ \\ _||   / |_| \\__ \\"));
  cprintString(2, 9,  F(" \\___|___|_|_\\|___/___|_|_\\\\___/|___|"));
  //
  cprintString(2, 11, F("   ________  ___________  _______      "));
  cprintString(2, 12, F("   \\_____  \\/_   \\   _  \\ \\   _  \\     "));
  cprintString(2, 13, F("    /  ____/ |   /  / \\  \\/  / \\  \\    "));
  cprintString(2, 14, F("   /       \\ |   \\  \\_/   \\  \\_/   \\   "));
  cprintString(2, 15, F("   \\_______ \\|___|\\_____  /\\_____  /   "));
  cprintString(2, 16, F("           \\/           \\/       \\/    "));
  //
  cprintString(2, 20, F("      Created at The Byte Attic!"));
  cprintString(2, 22, F("     Type basicz80 for Z80 BASIC"));
  cprintString(2, 23, F("    Type basic6502 for 6502 BASIC"));
  cprintString(2, 24, F("   Type help or ? for BIOS commands"));
  
  FILE *fp = fopen("cerbicon.img", "wb");
  for (int i=1;i<H;i++)
    for (int j=0;j<W;j++) {
	char c = buffer[i][j];
	if (c==0) c=32;
	fputc(c, fp);
    }
  fclose(fp);
  
  return 0;
}

