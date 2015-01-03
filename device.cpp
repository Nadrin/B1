/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#include "device.h"
#include "cpu.h"
#include "mcc.h"

Device::Device(CPU *InCPU)
    : TheCPU(*InCPU)
    , RAM(InCPU->RAM)
    , CyclesPerTick(1)
    , Cycles(0)
{}

bool Device::ShouldTick(const U32 DeltaCycles) const
{
    Cycles += DeltaCycles;

    if(Cycles >= CyclesPerTick) {
        Cycles -= CyclesPerTick;
        return true;
    }
    else {
        return false;
    }
}

