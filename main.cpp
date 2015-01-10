/**
 * B1 Computer Emulator
 * (c) 2014-2015 Michał Siejak
 */

#include <fstream>
#include "cpu.h"

int main(int argc, char** argv)
{
    std::printf("BENDER-I Computer Emulator\n");
    std::printf("(c) 2015 Michal Siejak <michal@siejak.pl>\n\n");

    if(SDL_Init(SDL_INIT_EVENTS) < 0) {
        std::fprintf(stderr, "Cannot initialize SDL!\n");
        return 1;
    }
	if(argc < 2) {
        std::fprintf(stderr, "Usage: %s <romfile>\n", argv[0]);
        return 2;
	}

    CPU* TheCPU;
    {
        std::ifstream RomFile(argv[1], std::ios::binary);
        if(!RomFile) {
            std::fprintf(stderr, "Could not open rom file: %s\n", argv[1]);
            return 3;
        }

        char Buffer[MEMSIZE];
        RomFile.read(Buffer, MEMSIZE);
        if(!RomFile) {
            std::fprintf(stderr, "Invalid rom file: %s\n", argv[1]);
            return 4;
        }

        TheCPU = new CPU(CPUFREQ, VIDEOHZ, Buffer, 0, sizeof(Buffer));
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
