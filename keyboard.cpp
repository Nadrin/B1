/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#include <map>
#include "cpu.h"
#include "mcc.h"
#include "keyboard.h"

namespace {
    enum Registers {
        RegKeyboard = 0x00,
    };
    const std::map<Sint32, U8> SpecialKeys = {
        {SDLK_LSHIFT,   0x01},
        {SDLK_RSHIFT,   0x02},
        {SDLK_LCTRL,    0x03},
        {SDLK_RCTRL,    0x04},
        {SDLK_LALT,     0x05},
        {SDLK_RALT,     0x06},

        {SDLK_CAPSLOCK,   0x0A},
        {SDLK_SCROLLLOCK, 0x0B},

        {SDLK_RIGHT, 0x0E},
        {SDLK_LEFT,  0x0F},
        {SDLK_UP,    0x10},
        {SDLK_DOWN,  0x11},

        {SDLK_F1,  0x41},
        {SDLK_F2,  0x42},
        {SDLK_F3,  0x43},
        {SDLK_F4,  0x44},
        {SDLK_F5,  0x45},
        {SDLK_F6,  0x46},
        {SDLK_F7,  0x47},
        {SDLK_F8,  0x48},
        {SDLK_F9,  0x49},
        {SDLK_F10, 0x4A},
        {SDLK_F11, 0x4B},
        {SDLK_F12, 0x4C},

        {SDLK_HOME,     0x50},
        {SDLK_END,      0x51},
        {SDLK_PAGEUP,   0x52},
        {SDLK_PAGEDOWN, 0x53},
        {SDLK_INSERT,   0x7E},
    };
    const U8 KeysMax = 8;
}

Keyboard::Keyboard(CPU* InCPU)
    : Device(InCPU)
{
    RAM.AllocRegister<Keyboard>(RegKeyboard, this, &Keyboard::ReadRegister, &Keyboard::WriteRegister);
}

void Keyboard::TranslateEvent(SDL_KeyboardEvent Event)
{
    if(Buffer.size() >= KeysMax)
        return;

    U8 Value;
    if(Event.keysym.sym <= 0x7F) {
        Value = Event.keysym.sym;
    }
    else {
        auto KeyIt = SpecialKeys.find(Event.keysym.sym);
        if(KeyIt == SpecialKeys.end())
            return;
        Value = KeyIt->second;
    }

    if(Event.state == SDL_RELEASED)
        Value |= 0x80;

    Buffer.push(Value);
    TheCPU.SignalInterrupt(CPU::INT_IRQ);
}

U8 Keyboard::ReadRegister(U8 Reg)
{
    U8 Value = 0;

    if(Reg == RegKeyboard && Buffer.size() > 0) {
        Value  = Buffer.front();
        Buffer.pop();
    }
    return Value;
}

void Keyboard::WriteRegister(U8 Reg, U8 Data)
{
    // Not supported by this device.
    UNUSED(Reg);
    UNUSED(Data);
}
