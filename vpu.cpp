/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#include "cpu.h"
#include "vpu.h"

namespace {
    const U16 FrameW = 320;
    const U16 FrameH = 200;
    const U8  UpdateHz = 50;
    const U8  Overscan = 32;

    enum Registers {
        RegScanline    = 0x02,
        RegRasterInt   = 0x03,
        RegBrColorLo   = 0x04,
        RegBrColorHi   = 0x05,
        RegBgColorLo   = 0x06,
        RegBgColorHi   = 0x07,
        RegFgColorLo   = 0x08,
        RegFgColorHi   = 0x09,
        RegFramePage   = 0x0A,
        RegCharMapPage = 0x0B,
    };

    constexpr U16 FrameBegin[] = { 0 + (Overscan>>1), 0 + (Overscan>>1) };
    constexpr U16 FrameEnd[]   = { FrameBegin[0] + FrameW-1, FrameBegin[1] + FrameH-1 };
    constexpr U16 ScreenEnd[]  = { FrameEnd[0] + (Overscan>>1), FrameEnd[1] + (Overscan>>1) };
}

VPU::VPU(CPU* InCPU)
    : Device(InCPU)
    , Scanline(0)
    , RasterInt(0xFF)
{
    const U16 Width  = FrameW + Overscan;
    const U16 Height = FrameH + Overscan;

    if(SDL_InitSubSystem(SDL_INIT_VIDEO) < 0) {
        throw Device::Error(SDL_GetError());
    }

    if(!(Window = SDL_CreateWindow("B1 Display", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, Width*2, Height*2, 0))) {
        throw Device::Error(SDL_GetError());
    }
    if(!(Renderer = SDL_CreateRenderer(Window, -1, 0))) {
        throw Device::Error(SDL_GetError());
    }
    if(!(Texture = SDL_CreateTexture(Renderer, SDL_PIXELFORMAT_ABGR8888, SDL_TEXTUREACCESS_STREAMING, Width, Height))) {
        throw Device::Error(SDL_GetError());
    }

    for(int Reg=RegScanline; Reg<=RegCharMapPage; Reg++) {
        RAM.AllocRegister<VPU>(Reg, this, &VPU::ReadRegister, &VPU::WriteRegister);
    }

    CyclesPerTick    = TheCPU.Frequency / (UpdateHz * MAXSCAN);
    CharsPerScanline = FrameW/8;

    FrameAddr       = 0xF000;
    CharMapAddr     = 0xF400;
    BackgroundColor = 0x0000;
    ForegroundColor = 0x0EEE;
    BorderColor     = BackgroundColor;
}

VPU::~VPU()
{
    if(Texture)
        SDL_DestroyTexture(Texture);
    if(Renderer)
        SDL_DestroyRenderer(Renderer);
    if(Window)
        SDL_DestroyWindow(Window);
}

void VPU::Tick(const U32 DeltaCycles)
{
    while(ShouldTick(DeltaCycles)) {
        if(Scanline == 0) {
            SDL_LockTexture(Texture, nullptr, (void**)&LockedPixels, &LockedPitch);
        }
        if(Scanline <= ScreenEnd[1]) {
            DrawScanline();
            if(Scanline+1 == RasterInt) {
                TheCPU.SignalInterrupt(CPU::INT_NMI);
            }
        }
        else if(Scanline == ScreenEnd[1]+1) {
            SDL_UnlockTexture(Texture);
            SDL_RenderCopy(Renderer, Texture, nullptr, nullptr);
            SDL_RenderPresent(Renderer);
        }

        Scanline = (Scanline+1) % MAXSCAN;
    }
}

U8 VPU::ReadRegister(U8 Reg)
{
    switch(Reg) {
    case RegScanline:    return Scanline; break;
    case RegRasterInt:   return RasterInt; break;
    case RegBrColorLo:   return BorderColor & 0xFF; break;
    case RegBrColorHi:   return (BorderColor >> 8) & 0x0F; break;
    case RegBgColorLo:   return BackgroundColor & 0xFF; break;
    case RegBgColorHi:   return (BackgroundColor >> 8) & 0x0F; break;
    case RegFgColorLo:   return (ForegroundColor & 0xFF); break;
    case RegFgColorHi:   return (ForegroundColor >> 8) & 0x0F; break;
    case RegFramePage:   return (FrameAddr >> 8) & 0xFF; break;
    case RegCharMapPage: return (CharMapAddr >> 8) & 0xFF; break;
    }
    return 0;
}

void VPU::WriteRegister(U8 Reg, U8 Data)
{
    switch(Reg) {
    case RegRasterInt:   RasterInt = Data; break;
    case RegBrColorLo:   BorderColor = (BorderColor & 0xFF00) | Data; break;
    case RegBrColorHi:   BorderColor = (Data << 8) | (BorderColor & 0x00FF); break;
    case RegBgColorLo:   BackgroundColor = (BackgroundColor & 0xFF00) | Data; break;
    case RegBgColorHi:   BackgroundColor = (Data << 8) | (BackgroundColor & 0x00FF); break;
    case RegFgColorLo:   ForegroundColor = (ForegroundColor & 0xFF00) | Data; break;
    case RegFgColorHi:   ForegroundColor = (Data << 8) | (ForegroundColor & 0x00FF); break;
    case RegFramePage:   FrameAddr = Data << 8; break;
    case RegCharMapPage: CharMapAddr = Data << 8; break;
    }
}

void VPU::DrawScanline()
{
    U8* Addr = LockedPixels + Scanline * LockedPitch;
    U16 X    = 0;

    if(Scanline < FrameBegin[1] || Scanline > FrameEnd[1]) {
        for(; X<=ScreenEnd[0]; X++) {
            DrawPixel(Addr, BorderColor);
        }
    }
    else {
        const U16 FrameY = Scanline - FrameBegin[1];

        for(; X<FrameBegin[0]; X++) {
            DrawPixel(Addr, BorderColor);
        }
        for(; X<FrameEnd[0]; X+=8) {
            const U16 FrameX    = X - FrameBegin[0];
            const U16 CharAddr  = FrameAddr + (FrameY/8 * CharsPerScanline + FrameX/8);
            const U16 GlyphAddr = CharMapAddr + 8*RAM[CharAddr];

            for(U8 GX=0; GX<8; GX++) {
                const U8 PixelValue = RAM[GlyphAddr + (FrameY%8)] & (0x80 >> GX);
                DrawPixel(Addr, PixelValue ? ForegroundColor : BackgroundColor);
            }
        }
        for(; X<=ScreenEnd[0]; X++) {
            DrawPixel(Addr, BorderColor);
        }
    }
}

void VPU::DrawPixel(U8*& Addr, const U16 Color)
{
    *Addr++ = (Color & 0x0F00) >> 4;
    *Addr++ = (Color & 0x00F0);
    *Addr++ = (Color & 0x000F) << 4;
    *Addr++ = 255;
}
