"""
Smoke Test — PeopleGone Worker Local Dry Run
Generates a synthetic image and processes it end-to-end through the pipeline.
"""

import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "server"))

from worker.pipeline import process

def test_pipeline_dry_run():
    print("Creating synthetic test image (800x600 RGB)...")
    # Create simple landscape image
    img = np.zeros((600, 800, 3), dtype=np.uint8)
    img[:300, :] = [135, 206, 235]  # Sky
    img[300:, :] = [34, 139, 34]    # Grass

    # Add primary person (center)
    img[200:500, 360:440] = [200, 50, 50]

    # Add background person (right)
    img[250:400, 600:660] = [50, 50, 200]

    pil_img = Image.fromarray(img)
    temp_in = os.path.join(os.path.dirname(__file__), "temp_test_input.jpg")
    temp_out = os.path.join(os.path.dirname(__file__), "temp_test_output.jpg")

    pil_img.save(temp_in, format="JPEG", quality=95)

    print("Running process() on synthetic image...")
    with open(temp_in, "rb") as f:
        photo_bytes = f.read()

    res_bytes, meta = process(photo_bytes)

    with open(temp_out, "wb") as f:
        f.write(res_bytes)

    print(f"Output dimensions: {meta['output_dimensions']}")
    print(f"Input dimensions: {meta['input_dimensions']}")
    assert meta["output_dimensions"] == [800, 600], "Output dimensions must match input dimensions!"
    print(f"GPU seconds: {meta['total_gpu_seconds']}s")
    print(f"Cost USD: ${meta['cost_estimate_usd']:.6f}")

    # Cleanup temp test files
    if os.path.exists(temp_in):
        os.remove(temp_in)
    if os.path.exists(temp_out):
        os.remove(temp_out)

    print("\nSUCCESS: Worker prototype pipeline dry-run completed successfully!")

if __name__ == "__main__":
    test_pipeline_dry_run()
