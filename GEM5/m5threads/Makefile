CC := arm-linux-gnueabi-gcc
CPP := arm-linux-gnueabi-g++

ARM_FLAGS := -march=armv7-a -marm

#CFLAGS := -ggdb3 -O3 -D__DEBUG
#CFLAGS := -g -O3 -DM5_PROFILING
CFLAGS := -g -O3 $(ARM_FLAGS)

CPPFLAGS := $(CFLAGS)

.PHONY: all clean

all:  libpthread.a(pthread.o)

clean:
	$(RM) *.o libpthread.a
