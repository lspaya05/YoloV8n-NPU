#!/usr/bin/env python3
"""Create a first INT8 hardware pack from a YOLOv8n PyTorch checkpoint.

This is a bring-up exporter, not a final accuracy-validated PTQ pipeline. It
does the mechanical pieces the RTL/driver need now:

- downloads/loads YOLOv8n from the pinned Ultralytics environment
- fuses Conv+BN where Ultralytics supports it
- quantizes Conv2d weights per output channel to signed INT8
- optionally collects activation ranges from representative images
- writes aligned requant coefficient records and SiLU LUTs
- emits a JSON manifest with layer shapes and binary offsets

The final mAP-quality path should run with representative COCO calibration data
and compare this pack against a PyTorch INT8 reference.
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

import numpy as np
import torch
from ultralytics import YOLO


@dataclass
class LayerRecord:
    index: int
    name: str
    module_type: str
    in_channels: int
    out_channels: int
    kernel: list[int]
    stride: list[int]
    padding: list[int]
    groups: int
    activation: str | None
    weight_offset: int
    weight_bytes: int
    coeff_offset: int
    coeff_bytes: int
    lut_offset: int | None
    lut_bytes: int
    input_scale: float
    weight_scale_min: float
    weight_scale_max: float
    output_scale: float


def iter_images(path: Path) -> Iterable[Path]:
    exts = {".bmp", ".jpg", ".jpeg", ".png", ".webp"}
    if path.is_file() and path.suffix.lower() in exts:
        yield path
        return
    if path.is_dir():
        for child in sorted(path.rglob("*")):
            if child.suffix.lower() in exts:
                yield child


def conv_modules(model: torch.nn.Module) -> list[tuple[str, torch.nn.Module, torch.nn.Conv2d]]:
    layers: list[tuple[str, torch.nn.Module, torch.nn.Conv2d]] = []
    for name, module in model.named_modules():
        conv = getattr(module, "conv", None)
        if isinstance(conv, torch.nn.Conv2d):
            layers.append((name, module, conv))
    return layers


def quant_scale_from_abs(max_abs: float) -> float:
    return max(float(max_abs), 1.0e-12) / 127.0


def quantize_weight_per_channel(weight: torch.Tensor) -> tuple[np.ndarray, np.ndarray]:
    w = weight.detach().cpu().float().numpy()
    reduce_axes = tuple(range(1, w.ndim))
    max_abs = np.max(np.abs(w), axis=reduce_axes)
    scales = np.maximum(max_abs / 127.0, 1.0e-12).astype(np.float32)
    view_shape = (w.shape[0],) + (1,) * (w.ndim - 1)
    q = np.round(w / scales.reshape(view_shape))
    q = np.clip(q, -128, 127).astype(np.int8)
    return q, scales


def choose_multiplier_shift(real_multiplier: float, max_shift: int = 15) -> tuple[int, int]:
    """Approximate real_multiplier as M / 2**S with a 4-bit shift field."""
    if not math.isfinite(real_multiplier) or real_multiplier <= 0:
        return 0, 0

    best_m = 0
    best_s = 0
    best_err = float("inf")
    for shift in range(max_shift + 1):
        m = int(round(real_multiplier * (1 << shift)))
        m = max(min(m, (1 << 31) - 1), -(1 << 31))
        approx = m / float(1 << shift)
        err = abs(approx - real_multiplier)
        if err < best_err:
            best_m = m
            best_s = shift
            best_err = err
    return best_m, best_s


def silu_lut(input_scale: float, output_scale: float) -> np.ndarray:
    values = np.arange(-128, 128, dtype=np.float32)
    x = values * input_scale
    sigmoid = np.empty_like(x)
    positive = x >= 0
    sigmoid[positive] = 1.0 / (1.0 + np.exp(-x[positive]))
    exp_x = np.exp(x[~positive])
    sigmoid[~positive] = exp_x / (1.0 + exp_x)
    y = x * sigmoid
    q = np.round(y / output_scale)
    return np.clip(q, -128, 127).astype(np.int8)


def collect_activation_scales(
    yolo: YOLO,
    modules: list[tuple[str, torch.nn.Module, torch.nn.Conv2d]],
    calib: Path | None,
    image_size: int,
    limit: int,
) -> dict[str, float]:
    scales = {name: 1.0 / 127.0 for name, _, _ in modules}
    if calib is None:
        return scales

    maxima = {name: 0.0 for name, _, _ in modules}
    hooks = []

    for name, module, _ in modules:
        def hook(_module, _inputs, output, layer_name=name):
            if isinstance(output, torch.Tensor):
                maxima[layer_name] = max(maxima[layer_name], float(output.detach().abs().max().cpu()))

        hooks.append(module.register_forward_hook(hook))

    image_paths = list(iter_images(calib))[:limit]
    if not image_paths:
        raise FileNotFoundError(f"No calibration images found under {calib}")

    with torch.no_grad():
        for image in image_paths:
            yolo.predict(source=str(image), imgsz=image_size, verbose=False, device="cpu")

    for hook in hooks:
        hook.remove()

    return {name: quant_scale_from_abs(maxima[name]) for name in maxima}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--weights", default="yolov8n.pt")
    parser.add_argument("--out", default="model_artifacts/yolov8n_int8_pack")
    parser.add_argument("--calib", type=Path, default=None)
    parser.add_argument("--calib-limit", type=int, default=32)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--input-scale", type=float, default=1.0 / 255.0)
    args = parser.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    yolo = YOLO(args.weights)
    yolo.model.eval()
    if hasattr(yolo.model, "fuse"):
        yolo.model.fuse()

    modules = conv_modules(yolo.model)
    act_scales = collect_activation_scales(
        yolo, modules, args.calib, args.imgsz, args.calib_limit
    )

    weights_path = out_dir / "weights_int8.bin"
    coeff_path = out_dir / "requant_coeffs.bin"
    lut_path = out_dir / "silu_luts.bin"

    records: list[LayerRecord] = []
    weight_offset = 0
    coeff_offset = 0
    lut_offset = 0
    prev_output_scale = args.input_scale

    with weights_path.open("wb") as weights_file, coeff_path.open("wb") as coeff_file, lut_path.open("wb") as lut_file:
        for index, (name, module, conv) in enumerate(modules):
            q_weight, weight_scales = quantize_weight_per_channel(conv.weight)
            weights_file.write(q_weight.tobytes(order="C"))
            weight_bytes = q_weight.nbytes

            output_scale = act_scales[name]
            coeff_records = bytearray()
            for weight_scale in weight_scales:
                real_multiplier = (prev_output_scale * float(weight_scale)) / output_scale
                mult, shift = choose_multiplier_shift(real_multiplier)
                coeff_records.extend(np.int32(mult).tobytes())
                coeff_records.extend(np.uint8(shift).tobytes())
                coeff_records.extend(b"\x00\x00\x00")
            coeff_file.write(coeff_records)

            activation_name = module.act.__class__.__name__ if hasattr(module, "act") else None
            layer_lut_offset = None
            layer_lut_bytes = 0
            if activation_name in {"SiLU", "SiLU(inplace=True)"} or activation_name == "SiLU":
                layer_lut_offset = lut_offset
                table = silu_lut(output_scale, output_scale)
                lut_file.write(table.tobytes())
                layer_lut_bytes = table.nbytes
                lut_offset += table.nbytes

            records.append(
                LayerRecord(
                    index=index,
                    name=name,
                    module_type=module.__class__.__name__,
                    in_channels=conv.in_channels,
                    out_channels=conv.out_channels,
                    kernel=list(conv.kernel_size),
                    stride=list(conv.stride),
                    padding=list(conv.padding),
                    groups=conv.groups,
                    activation=activation_name,
                    weight_offset=weight_offset,
                    weight_bytes=weight_bytes,
                    coeff_offset=coeff_offset,
                    coeff_bytes=len(coeff_records),
                    lut_offset=layer_lut_offset,
                    lut_bytes=layer_lut_bytes,
                    input_scale=prev_output_scale,
                    weight_scale_min=float(weight_scales.min()),
                    weight_scale_max=float(weight_scales.max()),
                    output_scale=output_scale,
                )
            )

            weight_offset += weight_bytes
            coeff_offset += len(coeff_records)
            prev_output_scale = output_scale

    manifest = {
        "format": "ee470-yolov8n-int8-pack",
        "format_version": 1,
        "source_weights": args.weights,
        "image_size": args.imgsz,
        "input_scale": args.input_scale,
        "calibration": {
            "path": str(args.calib) if args.calib else None,
            "limit": args.calib_limit,
            "note": "No calibration path means placeholder activation scales were used."
            if args.calib is None
            else "Activation scales collected with Ultralytics preprocessing on CPU.",
        },
        "binaries": {
            "weights": weights_path.name,
            "requant_coeffs": coeff_path.name,
            "silu_luts": lut_path.name,
        },
        "coeff_record_layout": {
            "bytes": 8,
            "fields": [
                {"name": "M", "type": "int32_le", "offset": 0},
                {"name": "S", "type": "uint8", "offset": 4},
                {"name": "pad", "type": "uint8[3]", "offset": 5},
            ],
        },
        "layers": [asdict(record) for record in records],
    }

    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"Exported {len(records)} conv layers")
    print(f"Wrote {weights_path}")
    print(f"Wrote {coeff_path}")
    print(f"Wrote {lut_path}")
    print(f"Wrote {manifest_path}")


if __name__ == "__main__":
    main()
