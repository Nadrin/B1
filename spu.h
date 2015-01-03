/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#ifndef SPU_H
#define SPU_H

#include "common.h"
#include "device.h"

// Sound Processing Unit
class SPU : public Device
{
public:
    SPU(CPU *InCPU);
    ~SPU();

    void Tick(const U32 DeltaCycles) override;

private:
    U8   ReadRegister(U8 Reg);
    void WriteRegister(U8 Reg, U8 Data);

    inline U8 SampleFlat() const;
    inline U8 SampleSquare() const;
    inline U8 SampleSine() const;

    inline void SetKey(const U8 NewIndex);
    static void AudioCallback(void* UserData, Uint8* Stream, int Length);

    SDL_AudioDeviceID AudioDevice;
    SDL_AudioSpec     AudioSpec;

    U8  Waveform;
    U8  Volume;
    U8  KeyIndex;
    U16 Frequency;
    U16 HalfPeriod;
    U16 SampleIndex;

    U8* Buffer;
    int BufferSize;
    int ReadCursor;
    int WriteCursor;
    int BytesAvailable;
};

#endif // SPU_H
