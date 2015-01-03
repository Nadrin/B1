/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#ifndef DEVICE_H
#define DEVICE_H

#include "common.h"

class CPU;
class MCC;

class Device
{
public:
    virtual void Tick(const U32 DeltaCycles) { UNUSED(DeltaCycles); }

protected:
    Device(CPU* InCPU);
    bool ShouldTick(const U32 DeltaCycles) const;

    CPU& TheCPU;
    MCC& RAM;

    U32 CyclesPerTick;
    mutable U32 Cycles;
};

#endif // DEVICE_H
