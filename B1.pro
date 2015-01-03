TEMPLATE = app
CONFIG += console
CONFIG -= app_bundle
CONFIG -= qt

QMAKE_CXXFLAGS += -std=c++11
LIBS += -lSDL2

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

