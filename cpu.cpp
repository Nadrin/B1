/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */


#include <cstring>
#include "common.h"
#include "cpu.h"

CPU::CPU(const U32 InFreq, const U16 InHz, const char* Program, U16 Offset, size_t Size)
    : A(0), X(0), Y(0), SP(0xFF), PC(0)
    , Cycles(0)
    , Frequency(InFreq*1000)
    , VideoHz(InHz)
    , RAM()
    , Video(this)
    , Sound(this)
    , Kbd(this)
    , Interrupt(INT_Reset)
{
    SDL_InitSubSystem(SDL_INIT_TIMER);
    FlagRegister() = 0;
    std::memcpy(&RAM.Buffer[Offset], Program, Size);

    CyclesPerJiffy   = (1000/VideoHz * Frequency) / 1000;
    CyclesSinceSleep = 0;
    LastSleepTicks   = SDL_GetTicks();
}

void CPU::Tick()
{
    Cycles = 0;
    ServiceInterrupt();
    Step();

    Video.Tick(Cycles);
    Sound.Tick(Cycles);

    CyclesSinceSleep += Cycles;
    if(CyclesSinceSleep >= CyclesPerJiffy) {
        CyclesSinceSleep -= CyclesPerJiffy;

        const int SleepTicks = 1000/VideoHz - (SDL_GetTicks() - LastSleepTicks);
        if(SleepTicks > 0)
            SDL_Delay(SleepTicks);
        LastSleepTicks = SDL_GetTicks();
    }
}

void CPU::Step()
{
    Cycles += 2;
    const U8 OpCode = RAM[PC++];

    switch(OpCode) {

    // ADC
    case 0x69: A = OpADC(A, ReadImmediate()); break;
    case 0x65: A = OpADC(A, RefZeroPage());   break;
    case 0x75: A = OpADC(A, RefZeroPage(X));  break;
    case 0x6D: A = OpADC(A, RefAbsolute());   break;
    case 0x7D: A = OpADC(A, RefAbsolute(X));  break;
    case 0x79: A = OpADC(A, RefAbsolute(Y));  break;
    case 0x61: A = OpADC(A, RefIndexedX());   break;
    case 0x71: A = OpADC(A, RefIndexedY());   break;

    // AND
    case 0x29: A = Op(A & ReadImmediate(), SF_S|SF_Z); break;
    case 0x25: A = Op(A & RefZeroPage(),  SF_S|SF_Z);  break;
    case 0x35: A = Op(A & RefZeroPage(X), SF_S|SF_Z);  break;
    case 0x2D: A = Op(A & RefAbsolute(),  SF_S|SF_Z);  break;
    case 0x3D: A = Op(A & RefAbsolute(X), SF_S|SF_Z);  break;
    case 0x39: A = Op(A & RefAbsolute(Y), SF_S|SF_Z);  break;
    case 0x21: A = Op(A & RefIndexedX(),  SF_S|SF_Z);  break;
    case 0x31: A = Op(A & RefIndexedY(),  SF_S|SF_Z);  break;

    // ASL
    case 0x0A: A = Op(A << 1, SF_S|SF_Z|SF_C); break;
    case 0x06: { Ref Mem = RefZeroPage();  Write(Mem = Op(Mem << 1, SF_S|SF_Z|SF_C)); } break;
    case 0x16: { Ref Mem = RefZeroPage(X); Write(Mem = Op(Mem << 1, SF_S|SF_Z|SF_C)); } break;
    case 0x0E: { Ref Mem = RefAbsolute();  Write(Mem = Op(Mem << 1, SF_S|SF_Z|SF_C)); } break;
    case 0x1E: { Ref Mem = RefAbsolute(X); Write(Mem = Op(Mem << 1, SF_S|SF_Z|SF_C)); } break;

    // BIT
    case 0x24: {
        const U8 Mem = RefZeroPage();
        Flags.Z = ((A & Mem) == 0);
        Flags.S = Flag(Mem & 0x80);
        Flags.V = Flag(Mem & 0x40);
    } break;
    case 0x2C: {
        const U8 Mem = RefAbsolute();
        Flags.Z = ((A & Mem) == 0);
        Flags.S = Flag(Mem & 0x80);
        Flags.V = Flag(Mem & 0x40);
    } break;

    // BPL
    case 0x10: Branch(!Flags.S); break;
    // BMI
    case 0x30: Branch(Flags.S);  break;
    // BVC
    case 0x50: Branch(!Flags.V); break;
    // BVS
    case 0x70: Branch(Flags.V);  break;
    // BCC
    case 0x90: Branch(!Flags.C); break;
    // BCS
    case 0xB0: Branch(Flags.C);  break;
    // BNE
    case 0xD0: Branch(!Flags.Z); break;
    // BEQ
    case 0xF0: Branch(Flags.Z);  break;

    // BRK
    case 0x00: SignalInterrupt(CPU::INT_BRK); PC++; break;

    // CMP
    case 0xC9: Op(A - ReadImmediate(), SF_S|SF_Z|SF_NC); break;
    case 0xC5: Op(A - RefZeroPage(),   SF_S|SF_Z|SF_NC); break;
    case 0xD5: Op(A - RefZeroPage(X),  SF_S|SF_Z|SF_NC); break;
    case 0xCD: Op(A - RefAbsolute(),   SF_S|SF_Z|SF_NC); break;
    case 0xDD: Op(A - RefAbsolute(X),  SF_S|SF_Z|SF_NC); break;
    case 0xD9: Op(A - RefAbsolute(Y),  SF_S|SF_Z|SF_NC); break;
    case 0xC1: Op(A - RefIndexedX(),   SF_S|SF_Z|SF_NC); break;
    case 0xD1: Op(A - RefIndexedY(),   SF_S|SF_Z|SF_NC); break;

    // CPX
    case 0xE0: Op(X - ReadImmediate(), SF_S|SF_Z|SF_NC); break;
    case 0xE4: Op(X - RefZeroPage(),   SF_S|SF_Z|SF_NC); break;
    case 0xEC: Op(X - RefAbsolute(),   SF_S|SF_Z|SF_NC); break;

    // CPY
    case 0xC0: Op(Y - ReadImmediate(), SF_S|SF_Z|SF_NC); break;
    case 0xC4: Op(Y - RefZeroPage(),   SF_S|SF_Z|SF_NC); break;
    case 0xCC: Op(Y - RefAbsolute(),   SF_S|SF_Z|SF_NC); break;

    // DEC
    case 0xC6: { Ref Mem = RefZeroPage();  Write(Mem = Op(Mem-1, SF_S|SF_Z)); } break;
    case 0xD6: { Ref Mem = RefZeroPage(X); Write(Mem = Op(Mem-1, SF_S|SF_Z)); } break;
    case 0xCE: { Ref Mem = RefAbsolute();  Write(Mem = Op(Mem-1, SF_S|SF_Z)); } break;
    case 0xDE: { Ref Mem = RefAbsolute(X); Write(Mem = Op(Mem-1, SF_S|SF_Z)); } break;

    // EOR
    case 0x49: A = Op(A ^ ReadImmediate(), SF_S|SF_Z); break;
    case 0x45: A = Op(A ^ RefZeroPage(),   SF_S|SF_Z); break;
    case 0x55: A = Op(A ^ RefZeroPage(X),  SF_S|SF_Z); break;
    case 0x4D: A = Op(A ^ RefAbsolute(),   SF_S|SF_Z); break;
    case 0x5D: A = Op(A ^ RefAbsolute(X),  SF_S|SF_Z); break;
    case 0x59: A = Op(A ^ RefAbsolute(Y),  SF_S|SF_Z); break;
    case 0x41: A = Op(A ^ RefIndexedX(),   SF_S|SF_Z); break;
    case 0x51: A = Op(A ^ RefIndexedY(),   SF_S|SF_Z); break;

    // CLC
    case 0x18: Flags.C = 0; break;
    // SEC
    case 0x38: Flags.C = 1; break;
    // CLI
    case 0x58: Flags.I = 0; break;
    // SEI
    case 0x78: Flags.I = 1; break;
    // CLV
    case 0xB8: Flags.V = 0; break;
    // CLD
    case 0xD8: Flags.D = 0; break;
    // SED
    case 0xF8: Flags.D = 1; break;

    // INC
    case 0xE6: { Ref Mem = RefZeroPage();  Write(Mem = Op(Mem+1, SF_S|SF_Z)); } break;
    case 0xF6: { Ref Mem = RefZeroPage(X); Write(Mem = Op(Mem+1, SF_S|SF_Z)); } break;
    case 0xEE: { Ref Mem = RefAbsolute();  Write(Mem = Op(Mem+1, SF_S|SF_Z)); } break;
    case 0xFE: { Ref Mem = RefAbsolute(X); Write(Mem = Op(Mem+1, SF_S|SF_Z)); } break;

    // JMP
    case 0x4C: PC = ReadImmediate16(); break;
    case 0x6C: PC = ReadAbsolute16();  break;

    // JSR
    case 0x20: { const U16 Addr = ReadImmediate16(); StackPush16(PC-1); PC = Addr; } break;

    // LDA
    case 0xA9: A = Op(ReadImmediate(), SF_S|SF_Z); break;
    case 0xA5: A = Op(RefZeroPage(),   SF_S|SF_Z); break;
    case 0xB5: A = Op(RefZeroPage(X),  SF_S|SF_Z); break;
    case 0xAD: A = Op(RefAbsolute(),   SF_S|SF_Z); break;
    case 0xBD: A = Op(RefAbsolute(X),  SF_S|SF_Z); break;
    case 0xB9: A = Op(RefAbsolute(Y),  SF_S|SF_Z); break;
    case 0xA1: A = Op(RefIndexedX(),   SF_S|SF_Z); break;
    case 0xB1: A = Op(RefIndexedY(),   SF_S|SF_Z); break;

    // LDX
    case 0xA2: X = Op(ReadImmediate(), SF_S|SF_Z); break;
    case 0xA6: X = Op(RefZeroPage(),   SF_S|SF_Z); break;
    case 0xB6: X = Op(RefZeroPage(Y),  SF_S|SF_Z); break;
    case 0xAE: X = Op(RefAbsolute(),   SF_S|SF_Z); break;
    case 0xBE: X = Op(RefAbsolute(Y),  SF_S|SF_Z); break;

    // LDY
    case 0xA0: Y = Op(ReadImmediate(), SF_S|SF_Z); break;
    case 0xA4: Y = Op(RefZeroPage(),   SF_S|SF_Z); break;
    case 0xB4: Y = Op(RefZeroPage(X),  SF_S|SF_Z); break;
    case 0xAC: Y = Op(RefAbsolute(),   SF_S|SF_Z); break;
    case 0xBC: Y = Op(RefAbsolute(X),  SF_S|SF_Z); break;

    // LSR
    case 0x4A: Flags.C = A & 1; A = Op(A >> 1, SF_S|SF_Z); break;
    case 0x46: { Ref Mem = RefZeroPage();  Flags.C = Mem & 1; Write(Mem = Op(Mem >> 1, SF_S|SF_Z)); } break;
    case 0x56: { Ref Mem = RefZeroPage(X); Flags.C = Mem & 1; Write(Mem = Op(Mem >> 1, SF_S|SF_Z)); } break;
    case 0x4E: { Ref Mem = RefAbsolute();  Flags.C = Mem & 1; Write(Mem = Op(Mem >> 1, SF_S|SF_Z)); } break;
    case 0x5E: { Ref Mem = RefAbsolute(X); Flags.C = Mem & 1; Write(Mem = Op(Mem >> 1, SF_S|SF_Z)); } break;

    // NOP
    case 0xEA: break;

    // ORA
    case 0x09: A = Op(A | ReadImmediate(), SF_S|SF_Z); break;
    case 0x05: A = Op(A | RefZeroPage(),   SF_S|SF_Z); break;
    case 0x15: A = Op(A | RefZeroPage(X),  SF_S|SF_Z); break;
    case 0x0D: A = Op(A | RefAbsolute(),   SF_S|SF_Z); break;
    case 0x1D: A = Op(A | RefAbsolute(X),  SF_S|SF_Z); break;
    case 0x19: A = Op(A | RefAbsolute(Y),  SF_S|SF_Z); break;
    case 0x01: A = Op(A | RefIndexedX(),   SF_S|SF_Z); break;
    case 0x11: A = Op(A | RefIndexedY(),   SF_S|SF_Z); break;

    // TAX
    case 0xAA: X = Op(A, SF_S|SF_Z); break;
    // TXA
    case 0x8A: A = Op(X, SF_S|SF_Z); break;
    // DEX
    case 0xCA: X = Op(X-1, SF_S|SF_Z); break;
    // INX
    case 0xE8: X = Op(X+1, SF_S|SF_Z); break;
    // TAY
    case 0xA8: Y = Op(A, SF_S|SF_Z); break;
    // TYA
    case 0x98: A = Op(Y, SF_S|SF_Z); break;
    // DEY
    case 0x88: Y = Op(Y-1, SF_S|SF_Z); break;
    // INY
    case 0xC8: Y = Op(Y+1, SF_S|SF_Z); break;

    // ROL
    case 0x2A: A = Op(ROL(A), SF_S|SF_Z); break;
    case 0x26: { Ref Mem = RefZeroPage();  Write(Mem = Op(ROL(Mem), SF_S|SF_Z)); } break;
    case 0x36: { Ref Mem = RefZeroPage(X); Write(Mem = Op(ROL(Mem), SF_S|SF_Z)); } break;
    case 0x2E: { Ref Mem = RefAbsolute();  Write(Mem = Op(ROL(Mem), SF_S|SF_Z)); } break;
    case 0x3E: { Ref Mem = RefAbsolute(X); Write(Mem = Op(ROL(Mem), SF_S|SF_Z)); } break;

    // ROR
    case 0x6A: A = Op(ROR(A), SF_S|SF_Z); break;
    case 0x66: { Ref Mem = RefZeroPage();  Write(Mem = Op(ROR(Mem), SF_S|SF_Z)); } break;
    case 0x76: { Ref Mem = RefZeroPage(X); Write(Mem = Op(ROR(Mem), SF_S|SF_Z)); } break;
    case 0x6E: { Ref Mem = RefAbsolute();  Write(Mem = Op(ROR(Mem), SF_S|SF_Z)); } break;
    case 0x7E: { Ref Mem = RefAbsolute(X); Write(Mem = Op(ROR(Mem), SF_S|SF_Z)); } break;

    // RTI
    case 0x40: FlagRegister() = StackPop() | 0x30; PC = StackPop16(); break;

    // RTS
    case 0x60: PC = StackPop16()+1; break;

    // SBC
    case 0xE9: A = OpSBC(A, ReadImmediate()); break;
    case 0xE5: A = OpSBC(A, RefZeroPage());   break;
    case 0xF5: A = OpSBC(A, RefZeroPage(X));  break;
    case 0xED: A = OpSBC(A, RefAbsolute());   break;
    case 0xFD: A = OpSBC(A, RefAbsolute(X));  break;
    case 0xF9: A = OpSBC(A, RefAbsolute(Y));  break;
    case 0xE1: A = OpSBC(A, RefIndexedX());   break;
    case 0xF1: A = OpSBC(A, RefIndexedY());   break;

    // STA
    case 0x85: Write(RefZeroPage()  = A); break;
    case 0x95: Write(RefZeroPage(X) = A); break;
    case 0x8D: Write(RefAbsolute()  = A); break;
    case 0x9D: Write(RefAbsolute(X) = A); break;
    case 0x99: Write(RefAbsolute(Y) = A); break;
    case 0x81: Write(RefIndexedX()  = A); break;
    case 0x91: Write(RefIndexedY()  = A); break;

    // STX
    case 0x86: Write(RefZeroPage()  = X); break;
    case 0x96: Write(RefZeroPage(Y) = X); break;
    case 0x8E: Write(RefAbsolute()  = X); break;

    // STY
    case 0x84: Write(RefZeroPage()  = Y); break;
    case 0x94: Write(RefZeroPage(X) = Y); break;
    case 0x8C: Write(RefAbsolute()  = Y); break;

    // TXS
    case 0x9A: SP = X; break;
    // TSX
    case 0xBA: X = Op(SP, SF_S|SF_Z); break;
    // PHA
    case 0x48: StackPush(A); break;
    // PLA
    case 0x68: A = Op(StackPop(), SF_S|SF_Z); break;
    // PHP
    case 0x08: StackPush(FlagRegister() | 0x30); break;
    // PLP
    case 0x28: FlagRegister() = StackPop() | 0x30; break;

    default:
        std::printf("Illegal opcode: %x!\n", OpCode);
        break;
    }
}

void CPU::ServiceInterrupt()
{
    static const U16 InterruptVectors[] = {
        0x0000,
        0xFFFC,
        0xFFFA,
        0xFFFE,
        0xFFFE,
    };

    switch(Interrupt) {
    case INT_Reset:
        Flags.I = 1;
        Flags.R = 1;
        Flags.Z = 1;
        break;
    case INT_NMI:
    case INT_IRQ:
    case INT_BRK:
        StackPush16(PC);
        StackPush(FlagRegister() | 0x30);
        Flags.I = 1;
        Flags.B = (Interrupt == INT_BRK);
        break;
    default:
        return;
    }

    Cycles += 2 + 1;
    const U16 VectorAddr = InterruptVectors[Interrupt];
    PC = RAM[VectorAddr] | RAM[VectorAddr+1] << 8;
    Interrupt = INT_None;
}

void CPU::SignalInterrupt(InterruptType IntType)
{
    if(!(IntType == CPU::INT_IRQ && Flags.I)) {
        Interrupt = IntType;
    }
}

U8 CPU::ReadImmediate()
{
    Cycles += 1;
    return RAM[PC++];
}

U16 CPU::ReadImmediate16()
{
    Cycles += 2;
    const U8 WordLo = RAM[PC++];
    const U8 WordHi = RAM[PC++];
    return WordHi << 8 | WordLo;
}

U16 CPU::ReadZeroPage16(U8 Index)
{
    Cycles += 3;
    const U16 AddrLo = (RAM[PC++] + Index) & 0xFF;
    const U16 AddrHi = (AddrLo + 1) & 0xFF;
    return RAM[AddrHi] << 8 | RAM[AddrLo];
}

U16 CPU::ReadAbsolute16(U8 Index)
{
    Cycles += 2;
    const U16 AddrLo = ReadImmediate16() + Index;
    const U16 AddrHi = AddrLo + 1;
    return RAM[AddrHi] << 8 | RAM[AddrLo];
}

Ref CPU::RefZeroPage(U8 Index)
{
    Cycles += 2;
    const U8 Addr = RAM[PC++] + Index;
    return {Addr, RAM[Addr]};
}

Ref CPU::RefAbsolute(U8 Index)
{
    Cycles += 1;
    const U16 Addr = ReadImmediate16() + Index;
    return {Addr, RAM[Addr]};
}

Ref CPU::RefIndexedX()
{
    Cycles += 1;
    const U16 Addr = ReadZeroPage16(X);
    return Ref{Addr, RAM[Addr]};
}

Ref CPU::RefIndexedY()
{
    Cycles += 1;
    const U16 Addr = ReadZeroPage16(0) + Y;
    return Ref{Addr, RAM[Addr]};
}

void CPU::Write(const Ref &Mem)
{
    Cycles += 1;
    RAM.Write(Mem.A, Mem.V);
}

U8 CPU::ToBinary(U8 Value) const
{
    const U8 NibbleHi = (Value / 16);
    const U8 NibbleLo = (Value % 16);
    return NibbleHi * 10 + NibbleLo;
}

U8 CPU::ToDecimal(U8 Value) const
{
    const U8 NibbleHi = (Value / 10);
    const U8 NibbleLo = (Value % 10);
    return NibbleHi * 16 + NibbleLo;
}

U8 CPU::Op(U16 Value, unsigned int SetFlags)
{
    if(SetFlags & SF_NC)     Flags.C = Flag(!(Value & 0x100));
    else if(SetFlags & SF_C) Flags.C = Flag((Value & 0x100));

    if(SetFlags & SF_Z) Flags.Z = Flag((Value & 0xFF) == 0);
    if(SetFlags & SF_S) Flags.S = Flag(Value & 0x80);

    return Value & 0xFF;
}

U8 CPU::OpADC(U8 OpA, U8 OpB)
{
    U8 Result;
    if(Flags.D) {
        const S16 BinResult = ToBinary(OpA) + ToBinary(OpB) + Flags.C;
        Flags.C = Flag(BinResult >= 0x64);
        Result  = Op(ToDecimal(BinResult % 0x64), SF_Z|SF_S);
    }
    else {
        Result  = Op(OpA + OpB + Flags.C, SF_C|SF_Z|SF_S);
        Flags.V = Flag((OpA ^ Result) & (OpB ^ Result) & 0x80);
    }
    return Result;
}

U8 CPU::OpSBC(U8 OpA, U8 OpB)
{
    U8 Result;
    if(Flags.D) {
        const S16 BinResult = ToBinary(OpA) - ToBinary(OpB) - !Flags.C;
        Flags.C = Flag(BinResult >= 0);
        Result  = Op(ToDecimal(BinResult >= 0 ? BinResult : 0x64 + BinResult), SF_Z|SF_S);
    }
    else {
        Result  = Op(OpA - OpB - !Flags.C, SF_NC|SF_Z|SF_S);
        Flags.V = Flag((OpA ^ Result) & ((0xFF-OpB) ^ Result) & 0x80);
    }
    return Result;
}

void CPU::Branch(bool Condition)
{
    const S8 Offset = ReadImmediate();
    if(Condition) {
        Cycles += 1;
        PC += Offset;
    }
}

void CPU::StackPush(U8 Value)
{
    Cycles += 1;
    RAM.Write(0x100+SP, Value);
    --SP;
}

void CPU::StackPush16(U16 Value)
{
    StackPush((Value >> 8) & 0xFF);
    StackPush(Value & 0xFF);
}

U8 CPU::StackPop()
{
    Cycles += 1;
    ++SP;
    return RAM[0x100+SP];
}

U16 CPU::StackPop16()
{
    const U8 WordLo = StackPop();
    const U8 WordHi = StackPop();
    return WordHi << 8 | WordLo;
}

U8 CPU::ROL(U8 Value)
{
    const U8 CarryMask = Flags.C << 0;
    Flags.C = Flag(Value & 0x80);
    return (Value << 1) | CarryMask;
}

U8 CPU::ROR(U8 Value)
{
    const U8 CarryMask = Flags.C << 7;
    Flags.C = Flag(Value & 0x01);
    return (Value >> 1) | CarryMask;
}
