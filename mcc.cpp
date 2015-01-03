/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#include <memory>
#include <cstring>
#include "mcc.h"

MCC::MCC()
{
    using namespace std::placeholders;

    std::memset(Buffer, 0, sizeof(Buffer));
    ReadCallback.fill(std::bind(&MCC::PassthroughRegisterRead, this, _1));
    WriteCallback.fill(std::bind(&MCC::PassthroughRegisterWrite, this, _1, _2));
}

U8 MCC::ReadRegister(const U8 Reg)
{
    return ReadCallback[Reg](Reg);
}

void MCC::WriteRegister(const U8 Reg, const U8 Value)
{
    WriteCallback[Reg](Reg, Value);
}

U8 MCC::PassthroughRegisterRead(U8 Reg)
{
    return Buffer[0xFD00 + Reg];
}

void MCC::PassthroughRegisterWrite(U8 Reg, U8 Data)
{
    Buffer[0xFD00 + Reg] = Data;
}
