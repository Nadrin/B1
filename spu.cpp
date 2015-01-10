/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#include <cstring>
#include <cmath>
#include "cpu.h"
#include "spu.h"

namespace {
    enum Registers {
        RegAudioCtl  = 0x0C,
        RegFrequency = 0x0D,
    };
    enum Waveforms {
        WaveFlat     = 0x00,
        WaveSquare   = 0x01,
        WaveSine     = 0x02,
    };
    const double Pi = 3.141593;
}

SPU::SPU(CPU *InCPU)
    : Device(InCPU)
    , Waveform(0)
    , Volume(240)
    , SampleIndex(0)
    , Buffer(nullptr)
    , BufferSize(0)
    , ReadCursor(0)
    , WriteCursor(0)
    , BytesAvailable(0)
{
    SDL_InitSubSystem(SDL_INIT_AUDIO);

    SDL_AudioSpec InAudioSpec;
    std::memset(&InAudioSpec, 0, sizeof(SDL_AudioSpec));
    InAudioSpec.freq     = 8000;
    InAudioSpec.format   = AUDIO_U8;
    InAudioSpec.channels = 1;
    InAudioSpec.samples  = 256;
    InAudioSpec.callback = SPU::AudioCallback;
    InAudioSpec.userdata = this;

    AudioDevice = SDL_OpenAudioDevice(nullptr, 0, &InAudioSpec, &AudioSpec, 0);
    if(AudioDevice) {
        BufferSize     = 4 * AudioSpec.size;
        CyclesPerTick  = TheCPU.Frequency / AudioSpec.freq;
        BytesAvailable = BufferSize;

        Buffer = new U8[BufferSize];
        std::memset(Buffer, AudioSpec.silence, BufferSize);
        SDL_PauseAudioDevice(AudioDevice, 0);

        SetKey(0);
    }

    RAM.AllocRegister<SPU>(RegAudioCtl,  this, &SPU::ReadRegister, &SPU::WriteRegister);
    RAM.AllocRegister<SPU>(RegFrequency, this, &SPU::ReadRegister, &SPU::WriteRegister);
}

SPU::~SPU()
{
    if(AudioDevice) {
        SDL_CloseAudioDevice(AudioDevice);
        delete[] Buffer;
    }
}

void SPU::Tick(const U32 DeltaCycles)
{
    while(ShouldTick(DeltaCycles)) {
        SDL_LockAudioDevice(AudioDevice);
        if(BytesAvailable > 0) {
            BytesAvailable--;

            auto SampleFunction = &SPU::SampleFlat;
            switch(Waveform) {
            case WaveSquare: SampleFunction = &SPU::SampleSquare; break;
            case WaveSine:   SampleFunction = &SPU::SampleSine;   break;
            }

            Buffer[WriteCursor] = (this->*SampleFunction)();
            SampleIndex = (SampleIndex+1) % (HalfPeriod<<1);
            WriteCursor = (WriteCursor+1) % BufferSize;
        }
        SDL_UnlockAudioDevice(AudioDevice);
    }
}

U8 SPU::ReadRegister(U8 Reg)
{
    switch(Reg) {
    case RegAudioCtl:
        return (Waveform << 4) | ((Volume >> 4) & 0x0F);
    case RegFrequency:
        return KeyIndex;
    }
    return 0;
}

void SPU::WriteRegister(U8 Reg, U8 Data)
{
    switch(Reg) {
    case RegAudioCtl:
        Volume   = (Data & 0x0F) << 4;
        Waveform = std::min((Data & 0xF0) >> 4, int(WaveSine));
        break;
    case RegFrequency:
        SetKey(Data);
        SampleIndex %= HalfPeriod<<1;
        break;
    }
}

U8 SPU::SampleFlat() const
{
    return Volume;
}

U8 SPU::SampleSquare() const
{
    return (SampleIndex / HalfPeriod) ? Volume : 0;
}

U8 SPU::SampleSine() const
{
    return Volume * (std::sin(SampleIndex/double(HalfPeriod) * Pi) + 1.0) * 0.5;
}

void SPU::SetKey(const U8 NewIndex)
{
    KeyIndex   = NewIndex & 0x3F;
    Frequency  = std::pow(2.0, (KeyIndex-48)/12.0) * 440;
    HalfPeriod = AudioSpec.freq / (Frequency<<1);
}

void SPU::AudioCallback(void *UserData, Uint8 *Stream, int Length)
{
    SPU& Self = *static_cast<SPU*>(UserData);

    for(; Self.BytesAvailable < Self.BufferSize && Length > 0; Length--) {
        *Stream++ = Self.Buffer[Self.ReadCursor];
        Self.ReadCursor = (Self.ReadCursor+1) % Self.BufferSize;
        Self.BytesAvailable++;
    }
    if(Length > 0) {
        std::memset(Stream, Self.AudioSpec.silence, Length);
    }
}
