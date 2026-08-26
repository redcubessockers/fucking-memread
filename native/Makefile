CC ?= cc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra -Werror -D_FORTIFY_SOURCE=2
LDFLAGS ?=

TARGET := memread_linux_read

.PHONY: all clean

all: $(TARGET)

$(TARGET): memread_linux_read.c
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@

clean:
	rm -f $(TARGET)
