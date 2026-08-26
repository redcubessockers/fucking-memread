#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

volatile unsigned char memread_fixture[8] = {
    0x01, 0x02, 0x03, 0x04, 0x41, 0x42, 0x43, 0x44
};

int main(void) {
    printf("%ld %p 8\n", (long)getpid(), (void *)memread_fixture);
    fflush(stdout);
    sleep(10);
    return 0;
}
