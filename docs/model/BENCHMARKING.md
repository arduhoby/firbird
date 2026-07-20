# TFLite benchmarking

The Android target is Android 9 and later. Before a real model is accepted, measure warm-up time, end-to-end inference time, peak memory use, model size, and device thermal impact on a representative Android 9 device.

The first technical model must have a verified model-weight license, code license, training-data statement, and redistribution permission. Do not add an unverified model to the repository or release assets.

## Required measurements

- Cold and warm model load
- Image preprocessing time
- Detector and classifier time
- Total identification time
- Peak RAM
- Model size
- CPU/GPU/NNAPI configuration
