JMON - Jeff's Monitor Program
------------------------------

A machine language monitor program for the Apple Replica 1.

Copyright (C) 2012-2014 by Jeff Tranter <tranter@pobox.com>
Copyright (C) 2015 by Michał Siejak <michal@siejak.pl>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Commands:

ASSEMBLER: A

Call a mini assembler which can assemble lines of 6502 or 65C02 code.
Prompts for the start address and then prompts for instructions. Does
not support symbols or labels. All values must be in hex with 2 or 4
digits and there are limited editing features (backspace support only). 
Press <Enter> to terminate and assemble a line. Pressing <Esc> will cancel.

Sample session:

A 6000
6000: NOP
6001: LDX #0A
6003: JSR FFEF
6006: DEX
6007: BNE 6003
6009: <Esc>

BREAKPOINT: B <N> <ADDRESS>

Set up to 4 breakpoints, numbered 0 through 3.
"B ?" lists status of all breakpoints.
"B <n> <address>" sets breakpoint number <n> at address <address>
"B <n> 0000" removes breakpoint <n>.
Breakpoint number <n> is 0 through 3.

Set a breakpoint on an address where you want to go into the trace
routine. Puts a BRK there and saved original instruction. When BRK is
hit, puts original instruction back and jumps into JMON and saves the
values of the current registers. From there you can single step,
change registers, etc. Once hit, a breakpoint is cleared and needs to
be set again. Breakpoints must be in RAM and the IRQ/BRK vector must
be in RAM (AN error is displayed if it is not). If the break handler
is called from an interrupt rather than a BRK instruction, a message
is displayed and a return from interrupt executed. If JMON is
restarted, breakpoints are cleared. If a BRK instruction is encountered
that does not match a breakpoint set in JMON, a message is displayed.

COPY: C <START> <END> <DEST>

Copy memory from address START through END to DEST. Range can overlap
but start address must be less than or equal to the end address.

DUMP: D <START>

Dump memory in hex and ASCII a screen at a time. Press <Space> to
continue or <Esc> to cancel when prompted.

FILL: F <START> <END> <DATA>...

Fill a range of memory with a hex data pattern. Data pattern can be of
any length up to 127 bytes. Press <Enter> after entering the pattern.

GO: G <ADDRESS>

Run from an address. Before execution, restores the values of the
registers set by the R command. Uses JSR so the called routine can
return to JMON. Uses the PC value set by the Registers command if
you hit <Enter> when prompted for the address.

HEX TO DEC: H <ADDRESS>

Convert 16-bit hexadecimal number to signed binary.

CHECKSUM: K <START> <END>

Calculate a 16-bit checksum of memory from addresses START to END.

CLR SCREEN: L

Clear the screen by printing 24 newlines.

INFO: N

Display information about the system. Sample output:

         CPU type: 65C02
RAM detected from: $0000 to $8FFF
       NMI vector: $0F00
     RESET vector: $FF00
   IRQ/BRK vector: $0100
        BASIC ROM: not present

SOUND TEST: M

Enters sound testing program. Keys <F1> to <F12> act as a musical
keyboard.

OPTION: O

Sets a number of program options. Prompts the user for the value of
each option.

REGISTERS: R

Displays the current value of the CPU registers A, X, Y, S, and P.
Also disassembles the instruction at the current PC. Then prompts to
enter new values. Uses any saved values when executing the Go command.
<Esc> cancels at any time. Pressing <Enter> when prompted for a new
register value will keep the current value and advance to the next
register. The trace function uses the values of the registers.

SEARCH: S <START> <END> <DATA>...

Search range of memory for a hex data pattern. Data pattern can be of
any length up to 127 bytes. Press <Enter> after entering the pattern.
After a match is found, prompts whether to continue the search.

TEST: T <START> <END>

Test a range of memory. No check that memory is not used by the
running program. Not recommended to test writable EEPROM as it has a
limited number of write cycles.

UNASSEMBLE: U <START>

Disassemble memory a page at a time. Supports 65C02 and 65816 op
codes.

VERIFY: V <START> <END> <DEST>

Verify that memory from start to end matches memory at destination.
Displays any mismatch. Prompts after each mismatch whether to
continue.

WRITE: : <ADDRESS> <DATA>...

Write hex data bytes to memory. Enter the start address followed by
data bytes. Starts a new line every multiple of 8 bytes. Press <Esc>
to cancel input.

MATH: = <ADDRESS> +/- <ADDRESS>

Math command. Add or subtract two 16-bit hex numbers.
Examples:
= 1234 + 0077 = 12AB
= FF00 - 0002 = FEFE

TRACE: .

The "." command single steps one instruction at a time showing the CPU
registers. Starts with the register values listed by the R command.
Updates them after single stepping. The command supports
tracing/stepping through ROM as well as RAM.

HELP: <F1>

Displays a summary of JMON commands.

REBOOT: <F12>

Jumps to RESET vector effectively rebooting the system.

------------------------------------------------------------------------

Other notes:

JMON will run out of RAM or ROM.

The breakpoint feature may interfere with any other interrupt handlers
that might be installed. It will fail if code writes over the break
handler code (three bytes starting at $0100).

The Fill, Search, and ":" commands accept characters as well as hex
values. Type ' to enter a single character.
