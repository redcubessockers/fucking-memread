#define _GNU_SOURCE

#include <errno.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/uio.h>
#include <sys/types.h>
#include <unistd.h>

#define MEMREAD_MAX_BYTES 32768U

static int parse_u64(const char *text, uint64_t *out) {
    char *end = NULL;
    errno = 0;
    unsigned long long value = strtoull(text, &end, 0);
    if (errno != 0 || end == text || *end != '\0') {
        return 0;
    }
    *out = (uint64_t)value;
    return 1;
}

static int write_all(const unsigned char *data, size_t size) {
    size_t offset = 0;
    while (offset < size) {
        ssize_t written = write(STDOUT_FILENO, data + offset, size - offset);
        if (written < 0) {
            if (errno == EINTR) {
                continue;
            }
            return 0;
        }
        if (written == 0) {
            return 0;
        }
        offset += (size_t)written;
    }
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "usage: %s <pid> <address> <size>\n", argv[0]);
        return 64;
    }

    uint64_t pid_value = 0;
    uint64_t address_value = 0;
    uint64_t size_value = 0;
    if (!parse_u64(argv[1], &pid_value) || pid_value == 0 || pid_value > UINT32_MAX) {
        fprintf(stderr, "invalid pid\n");
        return 64;
    }
    if (!parse_u64(argv[2], &address_value)) {
        fprintf(stderr, "invalid address\n");
        return 64;
    }
    if (!parse_u64(argv[3], &size_value) || size_value == 0 || size_value > MEMREAD_MAX_BYTES) {
        fprintf(stderr, "size must be in 1..%u\n", MEMREAD_MAX_BYTES);
        return 64;
    }

    unsigned char *buffer = (unsigned char *)malloc((size_t)size_value);
    if (buffer == NULL) {
        fprintf(stderr, "allocation failed\n");
        return 70;
    }

    struct iovec local = {
        .iov_base = buffer,
        .iov_len = (size_t)size_value,
    };
    struct iovec remote = {
        .iov_base = (void *)(uintptr_t)address_value,
        .iov_len = (size_t)size_value,
    };

    ssize_t read_count = process_vm_readv((pid_t)pid_value, &local, 1, &remote, 1, 0);
    if (read_count < 0) {
        fprintf(stderr, "process_vm_readv: %s\n", strerror(errno));
        free(buffer);
        return 1;
    }
    if ((uint64_t)read_count != size_value) {
        fprintf(stderr, "short read: requested=%" PRIu64 " received=%zd\n", size_value, read_count);
        free(buffer);
        return 1;
    }

    int ok = write_all(buffer, (size_t)read_count);
    free(buffer);
    if (!ok) {
        fprintf(stderr, "stdout write failed\n");
        return 1;
    }
    return 0;
}
