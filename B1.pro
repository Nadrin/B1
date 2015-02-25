TEMPLATE = app
CONFIG += console
CONFIG -= app_bundle
CONFIG -= qt

unix {
    QMAKE_CXXFLAGS += -std=c++11
    LIBS += -lSDL2
}

win32 {
    win32-msvc*:contains(QMAKE_HOST.arch, x86_64):{
        LIBS += -L"$$PWD/winsdk/lib64/"
    } else {
        LIBS += -L"$$PWD/winsdk/lib32/"
    }

    DEFINES += SDL_MAIN_HANDLED
    INCLUDEPATH += "$$PWD/winsdk/include/"
    LIBS += -lSDL2
}

SOURCES += main.cpp \
    cpu.cpp \
    mcc.cpp \
    vpu.cpp \
    keyboard.cpp \
    spu.cpp \
    device.cpp

HEADERS += \
    cpu.h \
    common.h \
    mcc.h \
    vpu.h \
    keyboard.h \
    spu.h \
    device.h

