#!/usr/bin/env python3
"""Download and summarize the pinned YOLOv8n source model."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
import ultralytics
from ultralytics import YOLO


def conv_summary(model: torch.nn.Module) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for name, module in model.named_modules():
        conv = getattr(module, "conv", None)
        if isinstance(conv, torch.nn.Conv2d):
            rows.append(
                {
                    "name": name,
                    "type": module.__class__.__name__,
                    "in_channels": conv.in_channels,
                    "out_channels": conv.out_channels,
                    "kernel": list(conv.kernel_size),
                    "stride": list(conv.stride),
                    "padding": list(conv.padding),
                    "groups": conv.groups,
                    "has_bn": getattr(module, "bn", None) is not None,
                    "activation": module.act.__class__.__name__
                    if hasattr(module, "act")
                    else None,
                }
            )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--weights", default="yolov8n.pt")
    parser.add_argument("--out", default="model_artifacts/yolov8n_source")
    args = parser.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    yolo = YOLO(args.weights)
    yolo.model.eval()

    summary = {
        "ultralytics_version": ultralytics.__version__,
        "torch_version": torch.__version__,
        "weights": args.weights,
        "task": yolo.task,
        "names": yolo.names,
        "conv_layers": conv_summary(yolo.model),
    }

    summary_path = out_dir / "yolov8n_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"Ultralytics {ultralytics.__version__}")
    print(f"Torch {torch.__version__}")
    print(f"Conv layers: {len(summary['conv_layers'])}")
    print(f"Wrote {summary_path}")


if __name__ == "__main__":
    main()
