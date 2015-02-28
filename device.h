/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#ifndef DEVICE_H
#define DEVICE_H

#include "common.h"
#include <stdexcept>

class CPU;
class MCC;

class Device
{
public:
    virtual void Tick(const U32 DeltaCycles) { UNUSED(DeltaCycles); }

    struct Error : public std::runtime_error {
        explicit Error(const char* what) : std::runtime_error(what) {}
    };

protected:
    Device(CPU* InCPU);
    bool ShouldTick(const U32 DeltaCycles) const;

    CPU& TheCPU;
    MCC& RAM;

    U32 CyclesPerTick;
    mutable U32 Cycles;
};

#endif // DEVICE_H
