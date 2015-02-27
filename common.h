/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#ifndef COMMON_H
#define COMMON_H

#include <cstdio>
#include <cstdint>
#include <SDL2/SDL.h>

#ifndef UNUSED
#define UNUSED(x) (void)(x)
#endif

#ifdef _MSC_VER
#if _MSC_VER <= 1800
#define constexpr const
#endif
#endif // _MSC_VER

typedef int8_t   S8;
typedef uint8_t  U8;
typedef int16_t  S16;
typedef uint16_t U16;
typedef int32_t  S32;
typedef uint32_t U32;

namespace {
    const U32 CPUFREQ = 1000;
    const U32 MEMSIZE = 64*1024;
    const U32 VIDEOHZ = 50;
    const U32 MAXSCAN = 256;
    const int TIMERES = 10;
}

#endif // COMMON_H
