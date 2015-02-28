/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#ifndef CPU_H
#define CPU_H

#include "common.h"
#include "mcc.h"
#include "vpu.h"
#include "spu.h"
#include "keyboard.h"

// Memory reference
struct Ref
{
    U16 A;
    U8  V;

    operator U8() const { return V; }
    Ref& operator=(const U8 InV) { V=InV; return *this; }
};

// Central Processing Unit
class CPU
{
public:
    // Registers
    U8  A, X, Y, SP;
    // Program counter
    U16 PC;
    // Cycle counter
    U32 Cycles;
    // Approximate clock freq in kHz
    U32 Frequency;
    // Video signal refresh rate in Hz
    U16 VideoHz;

    // Memory control chip
    MCC RAM;
    // Video processing unit
    VPU Video;
    // Sound processing unit
    SPU Sound;
    // Keyboard controller;
    Keyboard Kbd;

    struct {
        U8 C:1; // Carry
        U8 Z:1; // Zero
        U8 I:1; // IRQ disable
        U8 D:1; // Decimal mode
        U8 B:1; // BRK
        U8 R:1; // Reserved
        U8 V:1; // Overflow
        U8 S:1; // Sign
    } Flags;

    enum InterruptType {
        INT_None = 0,
        INT_Reset,
        INT_NMI,
        INT_IRQ,
        INT_BRK,
    } Interrupt;

    enum {
        SF_None = 0x00,
        SF_C    = 0x01,
        SF_NC   = 0x02,
        SF_Z    = 0x04,
        SF_S    = 0x08,
    };

    CPU(const U32 InFreq, const U16 InHz, const char* Program, U16 Offset, size_t Size);

    void Tick();
    void Step();
    void ServiceInterrupt();
    void SignalInterrupt(InterruptType IntType);

private:
    S32 CyclesPerJiffy;
    S32 CyclesSinceSleep;
    U32 LastTimestamp;

private:
    inline U8 ReadImmediate();
    inline U16 ReadImmediate16();
    inline U16 ReadZeroPage16(U8 Index=0);
    inline U16 ReadAbsolute16(U8 Index=0);

    inline Ref RefZeroPage(U8 Index=0);
    inline Ref RefAbsolute(U8 Index=0);
    inline Ref RefIndexedX();
    inline Ref RefIndexedY();

    inline void Write(const Ref& Mem);

    inline U8 ToBinary(U8 Value) const;
    inline U8 ToDecimal(U8 Value) const;

    inline U8 Op(U16 Value, unsigned int SetFlags=SF_None);
    inline U8 OpADC(U8 OpA, U8 OpB);
    inline U8 OpSBC(U8 OpA, U8 OpB);

    inline void Branch(bool Condition);

    inline void StackPush(U8 Value);
    inline void StackPush16(U16 Value);

    inline U8 StackPop();
    inline U16 StackPop16();

    inline U8 ROL(U8 Value);
    inline U8 ROR(U8 Value);

    inline bool Flag(U16 Value) const
    {
        return Value != 0;
    }
    inline U8& FlagRegister()
    {
        return *(U8*)&Flags;
    }
};

#endif // CPU_H
