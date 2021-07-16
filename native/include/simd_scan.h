/**
 * Keystone Native - SIMD and Bitwise Parallel Scanning Primitives
 */

#ifndef SIMD_SCAN_H
#define SIMD_SCAN_H

#include <stdint.h>
#include <stddef.h>

#define REPEAT_BYTE(b) ((uint64_t)(b) * 0x0101010101010101ULL)
#define HIGH_BITS 0x8080808080808080ULL

/**
 * Checks if a 64-bit word contains a target byte using branchless bitwise arithmetic.
 * Based on Alan Mycroft / Hacker's Delight zero-byte detection.
 */
static inline uint64_t has_byte_zero64(uint64_t v) {
    return (v - 0x0101010101010101ULL) & ~v & HIGH_BITS;
}

static inline uint64_t has_byte_match64(uint64_t word, uint8_t byte) {
    return has_byte_zero64(word ^ REPEAT_BYTE(byte));
}

#endif /* SIMD_SCAN_H */
