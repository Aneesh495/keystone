"""
Keystone Synthetic Traffic Load Generator & Stress Simulator
Simulates concurrent multi-partner transmission streams across X12, EDIFACT, HL7, and ISO 20022 protocols.
"""

import sys
import time
import threading
import argparse
from typing import List
from keystone_client.client import KeystoneClient
from keystone_client.edi_builder import EdiBuilder


class LoadSimulator:
    """Multi-threaded stress simulator for Keystone Transaction Gateway."""

    def __init__(self, base_url: str = "http://127.0.0.1:8088", concurrency: int = 4, total_requests: int = 50):
        self.client = KeystoneClient(base_url=base_url)
        self.concurrency = concurrency
        self.total_requests = total_requests
        self.latencies: List[float] = []
        self.lock = threading.Lock()
        self.success_count = 0
        self.error_count = 0

    def _worker(self, count: int, worker_id: int):
        protocols = ["X12", "EDIFACT", "HL7", "ISO20022"]
        for i in range(count):
            proto = protocols[(worker_id + i) % len(protocols)]
            if proto == "X12":
                payload = EdiBuilder.build_x12_850(po_number=f"SIM-PO-{worker_id}-{i}")
            elif proto == "EDIFACT":
                payload = EdiBuilder.build_edifact_orders(order_number=f"SIM-ORD-{worker_id}-{i}")
            elif proto == "HL7":
                payload = EdiBuilder.build_hl7_adt(patient_id=f"SIM-PAT-{worker_id}-{i}")
            else:
                payload = EdiBuilder.build_iso20022_pain001(msg_id=f"SIM-PAIN-{worker_id}-{i}")

            t0 = time.perf_counter()
            try:
                res = self.client.parse_document(proto, payload)
                elapsed_ms = (time.perf_counter() - t0) * 1000.0
                with self.lock:
                    if res.success:
                        self.success_count += 1
                    else:
                        self.error_count += 1
                    self.latencies.append(elapsed_ms)
            except Exception as e:
                with self.lock:
                    self.error_count += 1

    def run(self):
        print("================================================================")
        print("      KEYSTONE TRAFFIC SIMULATOR & CONCURRENCY BENCHMARK        ")
        print("================================================================")
        print(f"Target Gateway: {self.client.base_url}")
        print(f"Concurrency Level: {self.concurrency} worker threads")
        print(f"Total Requests: {self.total_requests} multi-protocol transmissions")
        print("----------------------------------------------------------------")

        health = self.client.check_health()
        print(f"Pre-flight health check: [{health.status}] Version: {health.version}")

        reqs_per_worker = self.total_requests // self.concurrency
        threads = []

        start_time = time.perf_counter()
        for w in range(self.concurrency):
            t = threading.Thread(target=self._worker, args=(reqs_per_worker, w))
            threads.append(t)
            t.start()

        for t in threads:
            t.join()

        total_elapsed = time.perf_counter() - start_time
        rps = self.total_requests / total_elapsed if total_elapsed > 0 else 0

        self.latencies.sort()
        n = len(self.latencies)
        p50 = self.latencies[int(n * 0.50)] if n > 0 else 0
        p90 = self.latencies[int(n * 0.90)] if n > 0 else 0
        p99 = self.latencies[int(n * 0.99)] if n > 0 else 0
        mean = sum(self.latencies) / n if n > 0 else 0

        print("\nSIMULATION RESULTS:")
        print(f"  Duration:            {total_elapsed:.3f} seconds")
        print(f"  Throughput:          {rps:.2f} requests/sec")
        print(f"  Successful Requests: {self.success_count} / {self.total_requests} ({(self.success_count / self.total_requests) * 100:.1f}%)")
        print(f"  Failed Requests:     {self.error_count}")
        print(f"  Latency (Mean):      {mean:.2f} ms")
        print(f"  Latency (p50):       {p50:.2f} ms")
        print(f"  Latency (p90):       {p90:.2f} ms")
        print(f"  Latency (p99):       {p99:.2f} ms")
        print("----------------------------------------------------------------")


def main():
    parser = argparse.ArgumentParser(description="Keystone Synthetic Traffic Simulator")
    parser.add_argument("--url", default="http://127.0.0.1:8088", help="Base URL of Keystone gateway")
    parser.add_argument("-c", "--concurrency", type=int, default=4, help="Worker threads")
    parser.add_argument("-n", "--requests", type=int, default=40, help="Total requests")
    args = parser.parse_args()

    sim = LoadSimulator(base_url=args.url, concurrency=args.concurrency, total_requests=args.requests)
    sim.run()


if __name__ == "__main__":
    main()
