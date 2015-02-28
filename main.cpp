/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#include <cstring>
#include <fstream>
#include "cpu.h"

int main(int argc, char** argv)
{
    std::printf("BENDER-I Computer Emulator\n");
    std::printf("(c) 2015 Michal Siejak <michal@siejak.pl>\n\n");

    if(argc >= 2 && (std::strcmp(argv[1], "-h") == 0 ||
                     std::strcmp(argv[1], "--help") == 0)) {
        std::printf("Usage: %s [romfile]\n", argv[0]);
        return 0;
    }

    if(SDL_Init(SDL_INIT_EVENTS) < 0) {
        std::fprintf(stderr, "Cannot initialize SDL!\n");
        return 1;
    }

    CPU* TheCPU;
    {
        const char* RomFileName = argc >= 2 ? argv[1] : "rom.bin";

        std::ifstream RomFile(RomFileName, std::ios::binary);
        if(!RomFile) {
            std::fprintf(stderr, "Could not open rom file: %s\n", RomFileName);
            return 2;
        }

        char Buffer[MEMSIZE];
        RomFile.read(Buffer, MEMSIZE);
        if(!RomFile) {
            std::fprintf(stderr, "Invalid rom file: %s\n", RomFileName);
            return 3;
        }

        try {
            TheCPU = new CPU(CPUFREQ, VIDEOHZ, Buffer, 0, sizeof(Buffer));
        }
        catch(const Device::Error& Error) {
            std::fprintf(stderr, "Error: %s\n", Error.what());
            return 4;
        }
    }

    bool ShouldQuit = false;
    do {
        SDL_Event event;
        while(SDL_PollEvent(&event)) {
            switch(event.type)
            {
            case SDL_KEYDOWN:
            case SDL_KEYUP:
                TheCPU->Kbd.TranslateEvent(event.key);
                break;
            case SDL_QUIT:
                ShouldQuit = true;
                break;
            }
        }

        TheCPU->Tick();

    } while(!ShouldQuit);

    delete TheCPU;
    SDL_Quit();
    return 0;
}
