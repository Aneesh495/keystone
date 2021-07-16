/**
 * Keystone Native - Vectorized Delimiter Scanning Implementation
 */

#include "simd_scan.h"
#include "keystone_accel.h"
#include <string.h>

int keystone_scan_delimiters(
    const uint8_t *buffer,
    size_t length,
    uint8_t target_delimiter,
    keystone_scan_result_t *result
) {
    if (!buffer || !result) return -1;

    result->count = 0;
    result->bytes_scanned = length;

    // Process 8 bytes per iteration using 64-bit word parallel scanning
    size_t words = length / 8;
    const uint64_t *word_ptr = (const uint64_t *)buffer;

    for (size_t w = 0; w < words; w++) {
        uint64_t word = word_ptr[w];
        uint64_t match = has_byte_match64(word, target_delimiter);

        if (match != 0) {
            // Match found within this 8-byte slice: extract exact byte positions
            size_t base = w * 8;
            for (size_t b = 0; b < 8; b++) {
                if (buffer[base + b] == target_delimiter) {
                    if (result->count < KEYSTONE_MAX_OFFSETS) {
                        result->offsets[result->count++] = base + b;
                    }
                }
            }
        }
    }

    // Process remaining trailing bytes
    size_t remainder_start = words * 8;
    for (size_t r = remainder_start; r < length; r++) {
        if (buffer[r] == target_delimiter) {
            if (result->count < KEYSTONE_MAX_OFFSETS) {
                result->offsets[result->count++] = r;
            }
        }
    }

    return 0;
}

bool keystone_validate_ascii_fast(const uint8_t *buffer, size_t length) {
    if (!buffer) return false;

    size_t words = length / 8;
    const uint64_t *word_ptr = (const uint64_t *)buffer;

    for (size_t w = 0; w < words; w++) {
        // High bit must be 0 for all bytes in valid 7-bit ASCII
        if ((word_ptr[w] & HIGH_BITS) != 0) {
            return false;
        }
    }

    for (size_t r = words * 8; r < length; r++) {
        if (buffer[r] & 0x80) {
            return false;
        }
    }

    return true;
}
