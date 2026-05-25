#!/usr/bin/env python3
"""Print pinned YOLO environment details."""

import torch
import ultralytics
from ultralytics import YOLO


def main() -> None:
    YOLO("yolov8n.pt")
    print(f"ultralytics={ultralytics.__version__}")
    print(f"torch={torch.__version__}")
    print(f"cuda_available={torch.cuda.is_available()}")
    print("model_load=ok")


if __name__ == "__main__":
    main()
