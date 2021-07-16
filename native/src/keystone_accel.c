/**
 * Keystone Native - Core Acceleration Engine & Non-Cryptographic Hashing
 */

#include "keystone_accel.h"
#include <stdlib.h>

/**
 * Fast 64-bit non-cryptographic checksum for high-throughput stream deduping.
 * Incorporates 64-bit mixer with prime multipliers.
 */
uint64_t keystone_fast_checksum64(const uint8_t *buffer, size_t length, uint64_t seed) {
    const uint64_t m = 0xc6a4a7935bd1e995ULL;
    const int r = 47;

    uint64_t h = seed ^ (length * m);

    const uint64_t *data = (const uint64_t *)buffer;
    const uint64_t *end = data + (length / 8);

    while (data != end) {
        uint64_t k = *data++;

        k *= m;
        k ^= k >> r;
        k *= m;

        h ^= k;
        h *= m;
    }

    const uint8_t *data2 = (const uint8_t *)data;

    switch (length & 7) {
        case 7: h ^= (uint64_t)data2[6] << 48;
        case 6: h ^= (uint64_t)data2[5] << 40;
        case 5: h ^= (uint64_t)data2[4] << 32;
        case 4: h ^= (uint64_t)data2[3] << 24;
        case 3: h ^= (uint64_t)data2[2] << 16;
        case 2: h ^= (uint64_t)data2[1] << 8;
        case 1: h ^= (uint64_t)data2[0];
                h *= m;
    };

    h ^= h >> r;
    h *= m;
    h ^= h >> r;

    return h;
}
