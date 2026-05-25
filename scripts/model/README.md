# YOLOv8n Model Setup

The FPGA does not run `yolov8n.pt` directly. The PyTorch checkpoint is the
source model. The hardware path needs an INT8 package containing quantized
weights, per-channel requant coefficients, activation LUTs, and a manifest that
the instruction scheduler can use.

## Environment

In WSL Ubuntu:

```sh
python3 -m venv .venv-yolo
. .venv-yolo/bin/activate
python -m pip install -r scripts/model/requirements-yolo.txt
```

This pins `ultralytics==8.4.53`.

## Download / Inspect

```sh
. .venv-yolo/bin/activate
python scripts/model/setup_yolov8n.py
```

This downloads `yolov8n.pt` through Ultralytics if it is not already cached and
writes `model_artifacts/yolov8n_source/yolov8n_summary.json`.

## First Hardware Pack

Without calibration images:

```sh
. .venv-yolo/bin/activate
python scripts/model/export_yolov8n_hardware_pack.py
```

With representative calibration images:

```sh
. .venv-yolo/bin/activate
python scripts/model/export_yolov8n_hardware_pack.py \
  --calib datasets/coco-calib/images \
  --calib-limit 500
```

Output goes to `model_artifacts/yolov8n_int8_pack/`:

- `weights_int8.bin`: signed INT8 Conv2d weights, per-output-channel quantized.
- `requant_coeffs.bin`: 8-byte records: `int32 M`, `uint8 S`, 3 pad bytes.
- `silu_luts.bin`: 256-entry signed INT8 SiLU LUTs.
- `manifest.json`: layer metadata and binary offsets.

This exporter is a bring-up step. For final accuracy, run calibration on a real
representative dataset and compare against a PyTorch INT8 reference before
loading the pack through the driver.
