/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#ifndef KEYBOARD_H
#define KEYBOARD_H

#include <queue>
#include "common.h"
#include "device.h"

class Keyboard : public Device
{
public:
    Keyboard(CPU* InCPU);
    void TranslateEvent(SDL_KeyboardEvent Event);

    std::queue<U8> Buffer;
private:
    U8   ReadRegister(U8 Reg);
    void WriteRegister(U8 Reg, U8 Data);
};

#endif // KEYBOARD_H
