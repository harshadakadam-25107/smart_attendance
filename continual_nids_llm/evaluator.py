"""
Evaluation Metrics & Latency Benchmarking for Continual Learning.
Computes Accuracy Matrix R, Average Accuracy (ACC), Backward Transfer (BWT), and Inference Latency.
"""

import time
import numpy as np
from typing import List, Dict


class ContinualEvaluator:
    @staticmethod
    def calculate_accuracy(y_true: List[str], y_pred: List[str]) -> float:
        correct = sum(1 for gt, pred in zip(y_true, y_pred) if gt == pred)
        return round((correct / len(y_true)) * 100.0, 2)

    @staticmethod
    def compute_bwt(matrix: np.ndarray) -> float:
        """Computes Backward Transfer (BWT) score to quantify catastrophic forgetting."""
        num_tasks = matrix.shape[0]
        if num_tasks <= 1:
            return 0.0
        bwt_sum = 0.0
        for j in range(num_tasks - 1):
            bwt_sum += (matrix[num_tasks - 1, j] - matrix[j, j])
        return round(bwt_sum / (num_tasks - 1), 2)

    @staticmethod
    def compute_average_accuracy(matrix: np.ndarray) -> float:
        """Computes Average Accuracy across all tasks after the final task is learned."""
        num_tasks = matrix.shape[0]
        return round(float(np.mean(matrix[num_tasks - 1, :])), 2)

    @staticmethod
    def measure_latency_and_throughput(trainer, sample_data: List[Dict]) -> Dict[str, float]:
        start_time = time.time()
        _ = trainer.predict(sample_data)
        elapsed = time.time() - start_time
        
        num_samples = len(sample_data)
        latency_ms = round((elapsed / num_samples) * 1000.0, 3)
        throughput_pps = round(num_samples / elapsed, 1)
        
        return {
            "latency_per_packet_ms": latency_ms,
            "throughput_packets_per_sec": throughput_pps
        }
