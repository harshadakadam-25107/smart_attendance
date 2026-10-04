"""
Data Loader & Text Prompt Generator for Continual NIDS Fine-Tuning.
Generates structured natural language prompts from network flow features and splits data into sequential tasks.
"""

import random
import numpy as np
import pandas as pd
from typing import List, Dict, Tuple


class NIDSTaskDataGenerator:
    def __init__(self, seed: int = 42):
        random.seed(seed)
        np.random.seed(seed)
        
        self.protocols = ["TCP", "UDP", "ICMP"]
        self.flag_types = ["SYN", "SYN-ACK", "ACK", "FIN-ACK", "RST", "PSH-ACK"]
        
        # Task specifications: incremental attack classes
        self.task_classes = {
            1: ["Normal", "DoS"],
            2: ["Reconnaissance"],
            3: ["Exploit"]
        }

    def _generate_flow(self, label: str) -> Dict[str, str]:
        if label == "Normal":
            proto = random.choice(["TCP", "UDP"])
            duration = round(random.uniform(0.1, 10.0), 3)
            src_port = random.randint(1024, 65535)
            dst_port = random.choice([80, 443, 53, 22, 8080])
            packets = random.randint(5, 100)
            bytes_sent = packets * random.randint(64, 1500)
            flags = random.choice(["ACK", "FIN-ACK", "PSH-ACK"])
        elif label == "DoS":
            proto = "TCP"
            duration = round(random.uniform(0.001, 0.05), 4)
            src_port = random.randint(1024, 65535)
            dst_port = random.choice([80, 443])
            packets = random.randint(500, 5000)
            bytes_sent = packets * random.randint(40, 100)
            flags = "SYN"
        elif label == "Reconnaissance":
            proto = "TCP"
            duration = round(random.uniform(0.001, 0.01), 4)
            src_port = random.randint(1024, 65535)
            dst_port = random.randint(1, 1024)
            packets = random.randint(1, 3)
            bytes_sent = packets * 40
            flags = "RST"
        elif label == "Exploit":
            proto = "TCP"
            duration = round(random.uniform(0.5, 3.0), 2)
            src_port = random.randint(1024, 65535)
            dst_port = random.choice([80, 8080, 21, 23, 445])
            packets = random.randint(20, 200)
            bytes_sent = packets * random.randint(200, 1400)
            flags = "PSH-ACK"
        else:
            raise ValueError(f"Unknown label: {label}")

        return {
            "duration": f"{duration}s",
            "protocol": proto,
            "src_port": str(src_port),
            "dst_port": str(dst_port),
            "packets": str(packets),
            "bytes": str(bytes_sent),
            "flags": flags,
            "label": label
        }

    def generate_task_dataset(self, task_id: int, num_samples: int = 400) -> List[Dict[str, str]]:
        """Generates a dataset for a specific task containing current task classes + previous task classes."""
        classes_in_task = self.task_classes[task_id]
        samples = []
        samples_per_class = num_samples // len(classes_in_task)
        
        for cls in classes_in_task:
            for _ in range(samples_per_class):
                flow = self._generate_flow(cls)
                prompt = (
                    f"Flow Duration: {flow['duration']} | Protocol: {flow['protocol']} | "
                    f"SrcPort: {flow['src_port']} | DstPort: {flow['dst_port']} | "
                    f"Packets: {flow['packets']} | Bytes: {flow['bytes']} | "
                    f"Flags: {flow['flags']}. Classify traffic:"
                )
                samples.append({
                    "prompt": prompt,
                    "label": flow["label"],
                    "full_text": f"{prompt} {flow['label']}",
                    "task_id": task_id
                })
        
        random.shuffle(samples)
        return samples

    def get_continual_task_sequence(self, samples_per_task: int = 300) -> Dict[int, Tuple[List[Dict], List[Dict]]]:
        """Returns train and test splits for Task 1, Task 2, and Task 3."""
        sequence = {}
        for task_id in range(1, 4):
            data = self.generate_task_dataset(task_id=task_id, num_samples=samples_per_task)
            split_idx = int(len(data) * 0.8)
            train_data = data[:split_idx]
            test_data = data[split_idx:]
            sequence[task_id] = (train_data, test_data)
        return sequence


if __name__ == "__main__":
    generator = NIDSTaskDataGenerator()
    seq = generator.get_continual_task_sequence(samples_per_task=10)
    for task_id, (train, test) in seq.items():
        print(f"--- Task {task_id} (Train: {len(train)}, Test: {len(test)}) ---")
        print("Sample Prompt:", train[0]["prompt"])
        print("Sample Label:", train[0]["label"])
