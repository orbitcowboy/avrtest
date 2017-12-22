# Compile for host at build (cross if desired)
CC= gcc
WARN=-W -Wall -Wextra -pedantic -Wstrict-prototypes -Wmissing-prototypes -Wno-unused-parameter
SANITIZER=-fsanitize=address -fsanitize=undefined
CFLAGS_FOR_HOST= -O3 -fomit-frame-pointer -std=c99 ${SANITIZER} -dp $(WARN) $(CFLAGS)

# compile for i386-mingw32 at *-linux-*
WINCC	= i386-mingw32-gcc

ifneq (,$(findstring Window,$(OS)))
# For the host
EXEEXT		= .exe
# For the build
BUILD_EXEEXT	= $(EXEEXT)
endif

# compile for build at build (native)
CC_FOR_BUILD	= gcc$(BUILD_EXEEXT)
CFLAGS_FOR_BUILD= -W -Wall -std=c99 -O2 -g 

# compile for AVR at build
CC_FOR_AVR	= avr-gcc$(BUILD_EXEEXT)
CFLAGS_FOR_AVR	= -Os 

.SUFFIXES:

A	= $(patsubst *%, avrtest%, * *_log *-xmega *-xmega_log *-tiny *-tiny_log)
A_log	= $(patsubst *%, avrtest%, *_log *-xmega_log *-tiny_log)
A_xmega	= $(patsubst *%, avrtest%, *-xmega *-xmega_log)
A_tiny	= $(patsubst *%, avrtest%, *-tiny *-tiny_log)

EXE	= $(A:=$(EXEEXT))

all : all-host all-avr

all-avrtest: $(A:=$(EXEEXT))

all-host : $(EXE)

all-avr	: exit

all-build : flag-tables

EXIT_MCUS = atmega8 atmega168 atmega128 atmega103 atmega2560 \
	    atxmega128a3 atxmega128a1 attiny40

EXIT_O = $(patsubst %,exit-%.o, $(EXIT_MCUS))

exit	: $(EXIT_O)

DEP_OPTIONS	= options.def options.h testavr.h avr-opcode.def Makefile
DEPS_PERF	= $(DEP_OPTIONS) perf.h logging.h avrtest.h
DEPS_GRAPH	= $(DEP_OPTIONS) graph.h
DEPS_LOGGING	= $(DEP_PERF) sreg.h graph.h
DEPS_LOAD_FLASH = $(DEP_OPTIONS)
DEPS		= $(DEP_OPTIONS) sreg.h flag-tables.h

$(A_log:=.s)	: XDEF += -DAVRTEST_LOG
$(A_xmega:=.s)	: XDEF += -DISA_XMEGA
$(A_tiny:=.s)	: XDEF += -DISA_TINY

$(A:=$(EXEEXT))     : XOBJ += options.o load-flash.o flag-tables.o
$(A:=$(EXEEXT))     : options.o load-flash.o flag-tables.o

$(A_log:=$(EXEEXT)) : XOBJ += logging.o graph.o perf.o
$(A_log:=$(EXEEXT)) : XLIB += -lm
$(A_log:=$(EXEEXT)) : logging.o graph.o perf.o

options.o: options.c $(DEP_OPTIONS)
	$(CC) $(CFLAGS_FOR_HOST) -c $< -o $@

logging.o: logging.c $(DEPS_LOGGING)
	$(CC) $(CFLAGS_FOR_HOST) -c $< -o $@ -DAVRTEST_LOG

graph.o: graph.c $(DEPS_GRAPH)
	$(CC) $(CFLAGS_FOR_HOST) -c $< -o $@ -DAVRTEST_LOG

perf.o: perf.c $(DEPS_PERF)
	$(CC) $(CFLAGS_FOR_HOST) -c $< -o $@ -DAVRTEST_LOG

load-flash.o: load-flash.c $(DEPS_LOAD_FLASH)
	$(CC) $(CFLAGS_FOR_HOST) -c $< -o $@

flag-tables.o: flag-tables.c Makefile
	$(CC) $(CFLAGS_FOR_HOST) -c $< -o $@

$(A:=.s) : avrtest.c $(DEPS)
	$(CC) $(CFLAGS_FOR_HOST) -S $< -o $@ $(XDEF)

$(EXE) : avrtest%$(EXEEXT) : avrtest%.s
	$(CC) $< -o $@ $(XOBJ) $(CFLAGS_FOR_HOST) $(XLIB)

# Build some auto-generated files

.PHONY: flag-tables

flag-tables: gen-flag-tables$(BUILD_EXEEXT) Makefile
	./$< 0 > $@.c
	./$< 1 > $@.h

gen-flag-tables$(BUILD_EXEEXT): gen-flag-tables.c sreg.h Makefile
	$(CC_FOR_BUILD) $(CFLAGS_FOR_BUILD) $< -o $@

# Cross-compile Windows executables on Linux

ifneq ($(EXEEXT),.exe)
exe:	avrtest.exe avrtest-xmega.exe avrtest-tiny.exe \
	avrtest_log.exe avrtest-xmega_log.exe avrtest-tiny_log.exe

W=-mingw32

$(A_log:=$(W).s)   : XDEF += -DAVRTEST_LOG
$(A_xmega:=$(W).s) : XDEF += -DISA_XMEGA
$(A_tiny:=$(W).s)  : XDEF += -DISA_TINY

$(A:=.exe)     : XOBJ_W += options$(W).o load-flash$(W).o flag-tables$(W).o
$(A:=.exe)     : options$(W).o load-flash$(W).o flag-tables$(W).o

$(A_log:=.exe) : XOBJ_W += logging$(W).o graph$(W).o perf$(W).o 
$(A_log:=.exe) : XLIB += -lm
$(A_log:=.exe) : logging$(W).o graph$(W).o perf$(W).o


options$(W).o: options.c $(DEP_OPTIONS)
	$(WINCC) $(CFLAGS_FOR_HOST) -c $< -o $@

logging$(W).o: logging.c $(DEPS_LOGGING)
	$(WINCC) $(CFLAGS_FOR_HOST) -c $< -o $@ -DAVRTEST_LOG

graph$(W).o: graph.c $(DEPS_GRAPH)
	$(WINCC) $(CFLAGS_FOR_HOST) -c $< -o $@ -DAVRTEST_LOG

perf$(W).o: perf.c $(DEPS_PERF)
	$(WINCC) $(CFLAGS_FOR_HOST) -c $< -o $@ -DAVRTEST_LOG

load-flash$(W).o: load-flash.c $(DEPS_LOAD_FLASH)
	$(WINCC) $(CFLAGS_FOR_HOST) -c $< -o $@

flag-tables$(W).o: flag-tables.c Makefile
	$(WINCC) $(CFLAGS_FOR_HOST) -c $< -o $@

$(A:=$(W).s) : avrtest.c $(DEPS)
	$(WINCC) $(CFLAGS_FOR_HOST) -S $< -o $@ $(XDEF)

EXE_W = $(A:=.exe)
$(EXE_W) : avrtest%.exe : avrtest%$(W).s
	$(WINCC) $< -o $@ $(XOBJ_W) $(CFLAGS_FOR_HOST) $(XLIB)

endif

all-mingw32: $(EXE_W)

# Cross-compile AVR exit*.o objects

exit-%.o: dejagnuboards/exit.c avrtest.h Makefile
	$(CC_FOR_AVR) $(CFLAGS_FOR_AVR) -mmcu=$* -I. $< -c -o $@ -save-temps -dp

.PHONY: all all-host all-avr clean clean-exit exe exit all-mingw32 all-avrtest

clean: clean-exit
	rm -f $(wildcard *.o *.i *.s)
	rm -f $(EXE)
	rm -f $(A:=.s) $(A:=.i) $(A:=.o)
	rm -f $(wildcard *.exe)
	rm -f gen-flag-tables

clean-exit:
	rm -f $(wildcard exit-*.o)
