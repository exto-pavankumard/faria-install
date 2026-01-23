#!/usr/bin/env python3
"""
Export cmarkea/detr-layout-detection to ONNX format.

Usage:
    pip install transformers torch onnx onnxruntime
    python export_detr_layout_onnx.py --output /path/to/output.onnx

This will download the DETR layout detection model and export it to ONNX format.
The model detects document layout elements: Table, Text, Title, Picture, etc.

IMPORTANT: This model must be loaded using DetrForSegmentation, NOT DetrForObjectDetection.
"""

import argparse
import sys
from pathlib import Path

def export_detr_layout(output_path: Path):
    import torch
    from transformers import AutoImageProcessor
    from transformers.models.detr import DetrForSegmentation

    model_name = "cmarkea/detr-layout-detection"

    # Ensure output directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Loading model: {model_name}")
    print("NOTE: Using DetrForSegmentation (model was saved with this class)")
    processor = AutoImageProcessor.from_pretrained(model_name)
    model = DetrForSegmentation.from_pretrained(model_name)
    model.eval()

    # Print model info
    print(f"Model config: num_labels={model.config.num_labels}, num_queries={model.config.num_queries}")

    # DETR uses fixed size input
    if hasattr(processor, 'size'):
        if isinstance(processor.size, dict):
            height = processor.size.get('height', 800)
            width = processor.size.get('width', 800)
        else:
            height = width = processor.size
    else:
        height = width = 800

    print(f"Input size: {height}x{width}")

    # Create dummy input
    dummy_pixel_values = torch.randn(1, 3, height, width)

    # Test inference before export
    print("Testing PyTorch inference...")
    with torch.no_grad():
        test_out = model(pixel_values=dummy_pixel_values)
    print(f"  logits: {test_out.logits.shape}, range: [{test_out.logits.min():.2f}, {test_out.logits.max():.2f}]")
    print(f"  pred_boxes: {test_out.pred_boxes.shape}, range: [{test_out.pred_boxes.min():.2f}, {test_out.pred_boxes.max():.2f}]")

    if torch.isnan(test_out.logits).any():
        print("ERROR: PyTorch model outputs NaN. Cannot export.")
        sys.exit(1)

    # Wrap model to only return logits and pred_boxes (exclude segmentation outputs)
    class DetrWrapper(torch.nn.Module):
        def __init__(self, model):
            super().__init__()
            self.model = model

        def forward(self, pixel_values):
            outputs = self.model(pixel_values=pixel_values)
            return outputs.logits, outputs.pred_boxes

    wrapped_model = DetrWrapper(model)
    wrapped_model.eval()

    # Export to ONNX
    output_stage_path = output_path.parent / f"{output_path.stem}_without_data.onnx"
    embedded_path = output_path
    print(f"\nExporting to ONNX: {output_stage_path}")

    try:
        torch.onnx.export(
            wrapped_model,
            (dummy_pixel_values,),
            str(output_stage_path),
            export_params=True,
            opset_version=14,
            do_constant_folding=True,
            input_names=['pixel_values'],
            output_names=['logits', 'pred_boxes'],
            dynamic_axes={
                'pixel_values': {0: 'batch_size'},
                'logits': {0: 'batch_size'},
                'pred_boxes': {0: 'batch_size'}
            }
        )
        print(f"Success! ONNX model saved to: {output_stage_path}")
    except Exception as e:
        print(f"Export failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

    # Verify the export and create embedded model
    print("\nVerifying ONNX export...")
    import onnx

    # Load model with external data (if any)
    onnx_model = onnx.load(str(output_stage_path), load_external_data=True)
    onnx.checker.check_model(onnx_model)
    print("ONNX model structure is valid!")

    # Create embedded model (single file with all weights included)
    print(f"\nCreating embedded model: {embedded_path}")
    onnx.save_model(
        onnx_model,
        str(embedded_path),
        save_as_external_data=False  # Embed all weights in the .onnx file
    )
    print(f"Embedded model saved! Size: {embedded_path.stat().st_size / 1024 / 1024:.1f} MB")

    # Test with onnxruntime (use embedded model)
    print("\nTesting ONNX inference with embedded model...")
    import onnxruntime as ort
    import numpy as np

    sess = ort.InferenceSession(str(embedded_path))
    onnx_inputs = {"pixel_values": dummy_pixel_values.numpy()}
    onnx_outputs = sess.run(None, onnx_inputs)

    onnx_logits = onnx_outputs[0]
    onnx_boxes = onnx_outputs[1]

    print(f"  logits: {onnx_logits.shape}, range: [{onnx_logits.min():.2f}, {onnx_logits.max():.2f}]")
    print(f"  pred_boxes: {onnx_boxes.shape}, range: [{onnx_boxes.min():.2f}, {onnx_boxes.max():.2f}]")

    if np.isnan(onnx_logits).any():
        print("ERROR: ONNX outputs NaN!")
        sys.exit(1)

    # Compare PyTorch vs ONNX
    pt_logits = test_out.logits.numpy()
    diff = np.abs(pt_logits - onnx_logits).max()
    print(f"  Max difference PyTorch vs ONNX: {diff:.6f}")

    if diff > 0.01:
        print("WARNING: Large difference between PyTorch and ONNX outputs")

    print("\n✅ ONNX export successful and verified!")

    # Print model info
    print("\n=== Model Specification ===")
    print("Inputs:")
    for input in onnx_model.graph.input:
        print(f"  - {input.name}: {[d.dim_value for d in input.type.tensor_type.shape.dim]}")

    print("Outputs:")
    for output in onnx_model.graph.output:
        print(f"  - {output.name}: {[d.dim_value for d in output.type.tensor_type.shape.dim]}")

    print("\n=== Class Labels (DocLayNet format) ===")
    labels = [
        "Caption",
        "Footnote",
        "Formula",
        "List-item",
        "Page-footer",
        "Page-header",
        "Picture",
        "Section-header",
        "Table",
        "Text",
        "Title"
    ]
    for i, label in enumerate(labels):
        marker = " <-- TARGET" if label == "Table" else ""
        print(f"  {i}: {label}{marker}")

    print("\n=== DETR Output Format ===")
    print("- logits: [batch, num_queries, num_classes+1] - class scores (last is 'no object')")
    print("- pred_boxes: [batch, num_queries, 4] - normalized boxes in (cx, cy, w, h) format")
    print("\nPost-processing required:")
    print("1. Apply softmax to logits to get class probabilities")
    print("2. Filter by confidence threshold")
    print("3. Convert boxes from (cx, cy, w, h) to (x1, y1, x2, y2)")
    print("4. Scale boxes from [0,1] to image dimensions")

    # Save processor config
    processor.save_pretrained(str(output_path.parent))
    print(f"\nProcessor config saved to: {output_path.parent}")

    return output_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export DETR layout detection model to ONNX")
    parser.add_argument("--output", "-o", type=str, required=True,
                        help="Output path for the ONNX model (e.g., /path/to/detr_layout_detection.onnx)")
    args = parser.parse_args()

    export_detr_layout(Path(args.output))
