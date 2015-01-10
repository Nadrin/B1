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
        RegKeyboardStatus = 0x00,
        RegKeyboardData   = 0x01,
    };

    const std::map<Sint32, U8> ShiftedSymbols = {
        {SDLK_BACKQUOTE,   '~'},
        {SDLK_1,           '!'},
        {SDLK_2,           '@'},
        {SDLK_3,           '#'},
        {SDLK_4,           '$'},
        {SDLK_5,           '%'},
        {SDLK_6,           '^'},
        {SDLK_7,           '&'},
        {SDLK_8,           '*'},
        {SDLK_9,           '('},
        {SDLK_0,           ')'},
        {SDLK_MINUS,       '_'},
        {SDLK_EQUALS,      '+'},
        {SDLK_LEFTBRACKET, '{'},
        {SDLK_RIGHTBRACKET,'}'},
        {SDLK_SEMICOLON,   ':'},
        {SDLK_QUOTE,       '"'},
        {SDLK_COMMA,       '<'},
        {SDLK_PERIOD,      '>'},
        {SDLK_SLASH,       '?'},
        {SDLK_BACKSLASH,   '|'},
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

        {SDLK_F1,  0x81},
        {SDLK_F2,  0x82},
        {SDLK_F3,  0x83},
        {SDLK_F4,  0x84},
        {SDLK_F5,  0x85},
        {SDLK_F6,  0x86},
        {SDLK_F7,  0x87},
        {SDLK_F8,  0x88},
        {SDLK_F9,  0x89},
        {SDLK_F10, 0x8A},
        {SDLK_F11, 0x8B},
        {SDLK_F12, 0x8C},

        {SDLK_HOME,     0x50},
        {SDLK_END,      0x51},
        {SDLK_PAGEUP,   0x52},
        {SDLK_PAGEDOWN, 0x53},
        {SDLK_INSERT,   0x7E},
    };
}

Keyboard::Keyboard(CPU* InCPU)
    : Device(InCPU)
    , Data(0)
    , Status(0)
{
    RAM.AllocRegister<Keyboard>(RegKeyboardStatus, this, &Keyboard::ReadRegister, &Keyboard::WriteRegister);
    RAM.AllocRegister<Keyboard>(RegKeyboardData,   this, &Keyboard::ReadRegister, &Keyboard::WriteRegister);
}

void Keyboard::TranslateEvent(SDL_KeyboardEvent Event)
{
    const Sint32 KeyCode = Event.keysym.sym;
    bool ShiftKeys       = Event.keysym.mod & (KMOD_SHIFT | KMOD_CAPS);

    if(KeyCode <= 0x7F) {
        if(KeyCode >= SDLK_a && KeyCode <= SDLK_z) {
            Data = KeyCode;
            if(ShiftKeys || (Status & 0x02))
                Data &= 0xDF;
        }
        else {
            Data = KeyCode;
            if(ShiftKeys && (Status & 0x01)) {
                auto KeyIt = ShiftedSymbols.find(KeyCode);
                if(KeyIt != ShiftedSymbols.end())
                    Data = KeyIt->second;
            }
        }
    }
    else {
        if((Status & 0x01) && (KeyCode == SDLK_LSHIFT || KeyCode == SDLK_RSHIFT))
            return;

        auto KeyIt = SpecialKeys.find(KeyCode);
        if(KeyIt == SpecialKeys.end())
            return;

        Data = KeyIt->second;
    }

    Status &= 0x03;
    if(Event.state == SDL_PRESSED) {
        Status |= 1<<6;
    }
    else {
        Status |= 1<<7;
    }

    if(ShiftKeys) {
        Status |= 1<<5;
    }
    if(Event.keysym.mod & KMOD_ALT) {
        Status |= 1<<4;
    }
    if(Event.keysym.mod & KMOD_CTRL) {
        Status |= 1<<3;
    }

    TheCPU.SignalInterrupt(CPU::INT_IRQ);
}

U8 Keyboard::ReadRegister(U8 Reg)
{
    U8 Result = 0;
    switch(Reg) {
    case RegKeyboardStatus:
        Result = Status;
        break;
    case RegKeyboardData:
        Result  = Data;
        Status &= 0x03;
        Data    = 0;
        break;
    }
    return Result;
}

void Keyboard::WriteRegister(U8 Reg, U8 Data)
{
    if(Reg == RegKeyboardStatus) {
        Status = (Data & 0x03) | (Status & 0xFC);
    }
}
