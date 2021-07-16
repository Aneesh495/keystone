/**
 * Keystone B2B Transaction Mesh - Native Acceleration Header
 * High-Throughput SIMD and Bit-Parallel Vector Scanner for B2B Protocol Streams
 */

#ifndef KEYSTONE_ACCEL_H
#define KEYSTONE_ACCEL_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define KEYSTONE_MAX_OFFSETS 65536

typedef struct {
    size_t offsets[KEYSTONE_MAX_OFFSETS];
    size_t count;
    size_t bytes_scanned;
    double throughput_gb_s;
} keystone_scan_result_t;

/**
 * High-performance bit-parallel delimiter scanning across raw memory buffer.
 * Locates all occurrences of target byte (e.g. segment terminator '~' or '\'')
 * at multi-gigabyte/second throughput using SWAR / SIMD vectorization.
 */
int keystone_scan_delimiters(
    const uint8_t *buffer,
    size_t length,
    uint8_t target_delimiter,
    keystone_scan_result_t *result
);

/**
 * Fast 64-bit Murmur/WyHash style non-cryptographic checksum for EDI transaction deduplication.
 */
uint64_t keystone_fast_checksum64(const uint8_t *buffer, size_t length, uint64_t seed);

/**
 * Validates whether buffer conforms to valid 7-bit ASCII representation.
 */
bool keystone_validate_ascii_fast(const uint8_t *buffer, size_t length);

#ifdef __cplusplus
}
#endif

#endif /* KEYSTONE_ACCEL_H */
