/**
 * Keystone Native - Performance Throughput Microbenchmark
 * Compares naive scalar byte-by-byte scanning with SIMD/SWAR parallel scanning.
 */

#include "keystone_accel.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define BENCH_BUFFER_SIZE (64 * 1024 * 1024) // 64 Megabytes
#define BENCH_ITERATIONS 5

static double get_time_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

// Naive scalar baseline implementation indexing offsets
static size_t scalar_scan_delimiters(const uint8_t *buf, size_t len, uint8_t delim, size_t *offsets, size_t max_offsets) {
    size_t count = 0;
    for (size_t i = 0; i < len; i++) {
        if (buf[i] == delim) {
            if (count < max_offsets) {
                offsets[count] = i;
            }
            count++;
        }
    }
    return count;
}

int main(void) {
    printf("================================================================\n");
    printf("   KEYSTONE NATIVE ACCELERATION ENGINE - BENCHMARK HARNESS      \n");
    printf("================================================================\n");

    printf("Allocating %d MB synthetic EDI buffer...\n", (int)(BENCH_BUFFER_SIZE / (1024 * 1024)));
    uint8_t *buffer = malloc(BENCH_BUFFER_SIZE);
    if (!buffer) {
        fprintf(stderr, "Failed to allocate memory\n");
        return 1;
    }

    // Populate synthetic EDI stream with standard segment lengths (~80 chars)
    for (size_t i = 0; i < BENCH_BUFFER_SIZE; i++) {
        if (i > 0 && i % 80 == 0) {
            buffer[i] = '~'; // segment terminator
        } else if (i % 10 == 0) {
            buffer[i] = '*'; // element separator
        } else {
            buffer[i] = 'A' + (i % 26);
        }
    }

    printf("Validating ASCII conformance...\n");
    bool is_ascii = keystone_validate_ascii_fast(buffer, BENCH_BUFFER_SIZE);
    printf("  ASCII Validation Result: %s\n", is_ascii ? "PASSED" : "FAILED");

    printf("\nComputing 64-bit non-cryptographic checksum...\n");
    double t0 = get_time_sec();
    uint64_t hash = keystone_fast_checksum64(buffer, BENCH_BUFFER_SIZE, 0x1337BEEF);
    double hash_time = get_time_sec() - t0;
    printf("  Hash: 0x%016llx (%.2f GB/s)\n", (unsigned long long)hash, (BENCH_BUFFER_SIZE / (1024.0 * 1024.0 * 1024.0)) / hash_time);

    printf("\n[1] Running Baseline Scalar Scanner (%d iterations)...\n", BENCH_ITERATIONS);
    double scalar_total_time = 0;
    size_t scalar_count = 0;
    size_t *scalar_offsets = malloc(sizeof(size_t) * KEYSTONE_MAX_OFFSETS);
    for (int iter = 0; iter < BENCH_ITERATIONS; iter++) {
        double start = get_time_sec();
        scalar_count = scalar_scan_delimiters(buffer, BENCH_BUFFER_SIZE, '~', scalar_offsets, KEYSTONE_MAX_OFFSETS);
        scalar_total_time += (get_time_sec() - start);
    }
    free(scalar_offsets);
    double scalar_avg_time = scalar_total_time / BENCH_ITERATIONS;
    double scalar_gb_s = (BENCH_BUFFER_SIZE / (1024.0 * 1024.0 * 1024.0)) / scalar_avg_time;
    printf("  Scalar Result: %zu terminators found\n", scalar_count);
    printf("  Scalar Latency: %.3f ms (Throughput: %.2f GB/s)\n", scalar_avg_time * 1000.0, scalar_gb_s);

    printf("\n[2] Running Keystone Vectorized SIMD/SWAR Scanner (%d iterations)...\n", BENCH_ITERATIONS);
    keystone_scan_result_t res;
    double simd_total_time = 0;
    for (int iter = 0; iter < BENCH_ITERATIONS; iter++) {
        double start = get_time_sec();
        keystone_scan_delimiters(buffer, BENCH_BUFFER_SIZE, '~', &res);
        simd_total_time += (get_time_sec() - start);
    }
    double simd_avg_time = simd_total_time / BENCH_ITERATIONS;
    double simd_gb_s = (BENCH_BUFFER_SIZE / (1024.0 * 1024.0 * 1024.0)) / simd_avg_time;
    printf("  Vector Result: %zu terminators indexed (capped at max offset limit)\n", res.count);
    printf("  Vector Latency: %.3f ms (Throughput: %.2f GB/s)\n", simd_avg_time * 1000.0, simd_gb_s);

    double speedup = scalar_avg_time / simd_avg_time;
    printf("\n----------------------------------------------------------------\n");
    printf("PERFORMANCE SPEEDUP: %.2fx faster than scalar baseline\n", speedup);
    printf("----------------------------------------------------------------\n");

    free(buffer);
    return 0;
}
