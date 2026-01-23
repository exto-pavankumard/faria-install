#!/usr/bin/env python3
"""
Export Nemotron Table Structure v1 to ONNX format.

Usage:
    # First clone the model repository:
    git lfs install
    git clone https://huggingface.co/nvidia/nemotron-table-structure-v1
    cd nemotron-table-structure-v1
    pip install -e .

    # Then run this script:
    python export_nemotron_onnx.py --output /path/to/output.onnx

This will export the Nemotron Table Structure model to ONNX format with
separate tensor outputs (labels, boxes, scores) instead of the original
dictionary output which ONNX cannot handle.
"""

import argparse
import sys
from pathlib import Path

def export_nemotron_table_structure(output_path: Path):
    import torch

    # Try to import from the installed package
    try:
        from nemotron_table_structure_v1.model import define_model
    except ImportError:
        print("Error: nemotron_table_structure_v1 package not found.")
        print("Please clone and install the model first:")
        print("  git lfs install")
        print("  git clone https://huggingface.co/nvidia/nemotron-table-structure-v1")
        print("  cd nemotron-table-structure-v1")
        print("  pip install -e .")
        sys.exit(1)

    # Ensure output directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Load the model
    print("Loading Nemotron Table Structure v1 model...")
    raw_model = define_model()
    raw_model.eval()

    # Print model info
    print(f"Model labels: {raw_model.labels}")
    print(f"Number of classes: {raw_model.num_classes}")

    # Create a wrapper that returns separate tensors (not a dict)
    # The original YoloXWrapper returns list[dict] which ONNX can't handle
    class TensorOutputWrapper(torch.nn.Module):
        def __init__(self, model):
            super().__init__()
            self.inner_model = model

        def forward(self, x, sizes):
            # Call the model - returns list[dict] with keys: labels, boxes, scores
            outputs = self.inner_model(x, sizes)

            # Get first batch item's predictions
            preds = outputs[0]

            # Return as separate tensors that ONNX can handle
            labels = preds["labels"]
            boxes = preds["boxes"]
            scores = preds["scores"]

            return labels, boxes, scores

    model = TensorOutputWrapper(raw_model)

    # Setup inputs
    dummy_input = torch.randn(1, 3, 1024, 1024)
    dummy_sizes = torch.tensor([[1024, 1024]], dtype=torch.int64)

    # Export to ONNX
    print(f"Exporting to ONNX: {output_path}")

    try:
        torch.onnx.export(
            model,
            (dummy_input, dummy_sizes),
            str(output_path),
            export_params=True,
            opset_version=18,
            do_constant_folding=True,
            input_names=['input', 'orig_sizes'],
            output_names=['labels', 'boxes', 'scores'],  # Three separate outputs
            training=torch.onnx.TrainingMode.EVAL,
            dynamo=False
        )
        print(f"Success! ONNX model saved to: {output_path}")
    except Exception as e:
        print(f"Export failed: {e}")
        sys.exit(1)

    print("\nExport complete!")
    print(f"\nONNX model saved to: {output_path}")

    # Print class labels for reference
    print("\nClass labels (Nemotron Table Structure format):")
    labels = {
        0: "border",  # not used
        1: "cell",
        2: "row",
        3: "column",
        4: "header",  # not used
    }
    for i, label in labels.items():
        print(f"  {i}: {label}")

    print("\nModel input/output specification:")
    print("  Inputs:")
    print("    - input: float32[1, 3, 1024, 1024] (RGB image, normalized)")
    print("    - orig_sizes: int64[1, 2] (original image [height, width])")
    print("  Outputs:")
    print("    - labels: float32[N] (class labels for each detection)")
    print("    - boxes: float32[N, 4] (normalized boxes [x1, y1, x2, y2])")
    print("    - scores: float32[N] (confidence scores)")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export Nemotron Table Structure model to ONNX")
    parser.add_argument("--output", "-o", type=str, required=True,
                        help="Output path for the ONNX model (e.g., /path/to/nemotron_table_structure.onnx)")
    args = parser.parse_args()

    export_nemotron_table_structure(Path(args.output))
