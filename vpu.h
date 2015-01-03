/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#ifndef VPU_H
#define VPU_H

#include "common.h"
#include "device.h"

// Video Processing Unit
class VPU : public Device
{
public:
    VPU(class CPU* InCPU);
    ~VPU();

    void Tick(const U32 DeltaCycles) override;

    SDL_Window*   Window;
    SDL_Renderer* Renderer;
    SDL_Texture*  Texture;

    U16 FrameAddr;
    U16	CharMapAddr;
    U16 BackgroundColor;
    U16 ForegroundColor;
    U16 BorderColor;
    U8  Scanline;
    U8  RasterInt;

private:
    U8   ReadRegister(U8 Reg);
    void WriteRegister(U8 Reg, U8 Data);

    inline void DrawScanline();
    inline void DrawPixel(U8*& Addr, const U16 Color);

    U8  CharsPerScanline;
    U8* LockedPixels;
    int LockedPitch;
};

#endif // VPU_H
