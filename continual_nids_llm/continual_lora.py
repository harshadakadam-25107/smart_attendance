"""
Continual LoRA Engine for Network Intrusion Detection (NIDS).
Implements Low-Rank Adaptation (LoRA), Fisher Information Matrix Regularization (EWC),
and Memory-Guided Exemplar Replay for Continual Class-Incremental Fine-Tuning.
"""

import random
import numpy as np
from typing import List, Dict, Tuple


def softmax(x: np.ndarray) -> np.ndarray:
    e_x = np.exp(x - np.max(x, axis=-1, keepdims=True))
    return e_x / np.sum(e_x, axis=-1, keepdims=True)


class NumPyLoRALinear:
    """Low-Rank Adaptation (LoRA) Layer in NumPy."""
    def __init__(self, in_features: int, out_features: int, rank: int = 16, alpha: float = 16.0, seed: int = 42):
        self.in_features = in_features
        self.out_features = out_features
        self.rank = rank
        self.scaling = alpha / rank

        rng = np.random.RandomState(seed)
        self.W_base = rng.normal(0, 0.1, (in_features, out_features))
        
        # LoRA trainable low-rank adapters A (rank x in) and B (out x rank)
        self.lora_A = rng.normal(0, 0.05, (rank, in_features))
        self.lora_B = rng.normal(0, 0.05, (out_features, rank))

    def forward(self, x: np.ndarray) -> np.ndarray:
        base_out = np.matmul(x, self.W_base)
        lora_out = np.matmul(np.matmul(x, self.lora_A.T), self.lora_B.T) * self.scaling
        return base_out + lora_out


class VocabularyEncoder:
    """Encodes NIDS packet text prompts using a consistent, fixed vocabulary."""
    def __init__(self):
        keywords = [
            "flow", "duration", "protocol", "srcport", "dstport", "packets", "bytes", "flags",
            "classify", "traffic", "tcp", "udp", "icmp", "syn", "syn-ack", "ack", "fin-ack",
            "rst", "psh-ack", "normal", "dos", "reconnaissance", "exploit"
        ]
        self.vocab = {kw: i for i, kw in enumerate(keywords)}
        self.max_features = len(keywords) + 32

    def transform(self, texts: List[str]) -> np.ndarray:
        matrix = np.zeros((len(texts), self.max_features))
        for i, text in enumerate(texts):
            tokens = text.lower().replace("|", " ").replace(":", " ").replace(".", " ").split()
            for tok in tokens:
                if tok in self.vocab:
                    matrix[i, self.vocab[tok]] += 1.0
                else:
                    idx = len(self.vocab) + (hash(tok) % 32)
                    matrix[i, idx] += 1.0
        norms = np.linalg.norm(matrix, axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        return matrix / norms


class ContinualLoRATrainer:
    """Trainer implementing Naive LoRA fine-tuning & Continual LoRA."""
    def __init__(self, label_map: Dict[str, int], ewc_lambda: float = 8.0, replay_size: int = 60, seed: int = 42):
        self.label_map = label_map
        self.inv_label_map = {v: k for k, v in label_map.items()}
        self.encoder = VocabularyEncoder()
        
        self.in_dim = self.encoder.max_features
        self.num_classes = len(label_map)
        
        self.layer = NumPyLoRALinear(self.in_dim, self.num_classes, rank=16, seed=seed)
        
        self.ewc_lambda = ewc_lambda
        self.replay_size = replay_size
        
        self.fisher_A: Dict[int, np.ndarray] = {}
        self.fisher_B: Dict[int, np.ndarray] = {}
        self.optimal_A: Dict[int, np.ndarray] = {}
        self.optimal_B: Dict[int, np.ndarray] = {}
        
        self.replay_buffer: List[Dict[str, str]] = []

    def _forward_pass(self, X: np.ndarray) -> np.ndarray:
        logits = self.layer.forward(X)
        probs = softmax(logits)
        return probs

    def train_task(self, task_id: int, train_data: List[Dict], mode: str = "continual", epochs: int = 120, lr: float = 0.15):
        if mode == "naive":
            task_samples = list(train_data)
        else:
            task_samples = list(train_data)
            if len(self.replay_buffer) > 0:
                task_samples.extend(self.replay_buffer)

        random.seed(42 + task_id)
        random.shuffle(task_samples)

        prompts = [d["prompt"] for d in task_samples]
        labels = np.array([self.label_map[d["label"]] for d in task_samples])
        
        X = self.encoder.transform(prompts)

        batch_size = len(task_samples)
        Y_onehot = np.zeros((batch_size, self.num_classes))
        Y_onehot[np.arange(batch_size), labels] = 1.0

        for epoch in range(epochs):
            probs = self._forward_pass(X)
            d_logits = (probs - Y_onehot) / batch_size
            
            grad_W = np.matmul(X.T, d_logits)
            grad_B = np.matmul(d_logits.T, np.matmul(X, self.layer.lora_A.T)) * self.layer.scaling
            grad_A = np.matmul(np.matmul(d_logits, self.layer.lora_B).T, X) * self.layer.scaling

            if mode == "naive":
                self.layer.W_base -= lr * grad_W
                self.layer.lora_A -= lr * grad_A
                self.layer.lora_B -= lr * grad_B
            
            elif mode == "continual":
                self.layer.W_base -= lr * 0.4 * grad_W
                
                if task_id > 1:
                    for past_task in self.fisher_A:
                        grad_A += (self.ewc_lambda / batch_size) * self.fisher_A[past_task] * (self.layer.lora_A - self.optimal_A[past_task])
                        grad_B += (self.ewc_lambda / batch_size) * self.fisher_B[past_task] * (self.layer.lora_B - self.optimal_B[past_task])

                self.layer.lora_A -= lr * grad_A
                self.layer.lora_B -= lr * grad_B

        if mode == "continual":
            self._save_task_state(task_id, X, Y_onehot)
            self._update_replay_buffer(train_data)

    def _save_task_state(self, task_id: int, X: np.ndarray, Y_onehot: np.ndarray):
        probs = self._forward_pass(X)
        batch_size = len(X)
        d_logits = (probs - Y_onehot) / batch_size
        
        grad_B = np.matmul(d_logits.T, np.matmul(X, self.layer.lora_A.T)) * self.layer.scaling
        grad_A = np.matmul(np.matmul(d_logits, self.layer.lora_B).T, X) * self.layer.scaling

        self.fisher_A[task_id] = np.abs(grad_A) + 1e-4
        self.fisher_B[task_id] = np.abs(grad_B) + 1e-4

        self.optimal_A[task_id] = np.copy(self.layer.lora_A)
        self.optimal_B[task_id] = np.copy(self.layer.lora_B)

    def _update_replay_buffer(self, train_data: List[Dict]):
        selected = train_data[:self.replay_size]
        self.replay_buffer.extend(selected)
        if len(self.replay_buffer) > self.replay_size * 3:
            self.replay_buffer = self.replay_buffer[-self.replay_size * 3:]

    def predict(self, test_data: List[Dict]) -> List[str]:
        prompts = [d["prompt"] for d in test_data]
        X = self.encoder.transform(prompts)
        probs = self._forward_pass(X)
        preds = np.argmax(probs, axis=1)
        return [self.inv_label_map[p] for p in preds]
