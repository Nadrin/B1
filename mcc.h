/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#ifndef MCC_H
#define MCC_H

#include <functional>
#include <array>
#include "common.h"

// Memory Control Chip
class MCC
{
public:
    MCC();

    inline U8 Read(const U16 Addr)
    {
        if((Addr >> 8) == 0xFD)
            return ReadRegister(Addr & 0xFF);
        else
            return Buffer[Addr];
    }
    inline void Write(const U16 Addr, const U8 Value)
    {
        if((Addr >> 8) == 0xFD)
            WriteRegister(Addr & 0xFF, Value);
        else
            Buffer[Addr] = Value;
    }
    inline U8 operator[](const U16 Addr) { return Read(Addr); }

    U8   ReadRegister(const U8 Reg);
    void WriteRegister(const U8 Reg, const U8 Value);

    template<class T>
    void AllocRegister(const U8 Reg, T* Device, U8 (T::*ReadFunc)(U8), void (T::*WriteFunc)(U8, U8))
    {
        using namespace std::placeholders;
        ReadCallback[Reg]  = std::bind(ReadFunc, Device, _1);
        WriteCallback[Reg] = std::bind(WriteFunc, Device, _1, _2);
    }

    // 64kB address space
    U8 Buffer[MEMSIZE];

    // Memory-mapped IO callbacks
    std::array<std::function<U8(U8)>, 255>      ReadCallback;
    std::array<std::function<void(U8,U8)>, 255> WriteCallback;
private:
    U8   PassthroughRegisterRead(U8 Reg);
    void PassthroughRegisterWrite(U8 Reg, U8 Data);
};

#endif // MCC_H
