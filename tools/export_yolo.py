import os
try:
    from ultralytics import YOLO
except ImportError:
    import subprocess
    import sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "ultralytics"])
    from ultralytics import YOLO

# Load a model
model = YOLO('yolov8n.pt')  # load an official model

# Export the model
success = model.export(format='onnx', imgsz=640)
print(f"Export successful: {success}")
