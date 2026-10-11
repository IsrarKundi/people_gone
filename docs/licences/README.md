# Model Licence Pack — PeopleGone Phase 0

This directory documents and archives the exact licenses of all AI model weights and libraries utilized by the PeopleGone Phase 0 pipeline.

Per `PEOPLEGONE_REQUIREMENTS.md` §3.1 (Task 5), §6.4, and §14 (Task 0.2), **Ultralytics YOLO models (AGPL-3.0 / Commercial License required) are strictly forbidden**. All shipped checkpoints and libraries must possess permissive licenses (Apache-2.0 or MIT) that allow commercial use.

## Summary Table

| Component | Architecture / Checkpoint | Licence | Source Repository | Commercial Use OK? | AGPL Checked? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Person Detector** | RT-DETR (`PekingU/rtdetr_r50vd`) / DETR (`facebook/detr-resnet-50`) | **Apache-2.0** | [HuggingFace / PekingU](https://huggingface.co/PekingU/rtdetr_r50vd) / [HF DETR](https://huggingface.co/facebook/detr-resnet-50) | **YES** | **YES — No AGPL** |
| **Instance Segmentor** | SAM 2.1 (`facebook/sam2.1-hiera-tiny` / `small`) | **Apache-2.0** | [Meta SAM 2](https://github.com/facebookresearch/sam2) | **YES** | **YES — No AGPL** |
| **Inpainting Engine** | LaMa (`big-lama` checkpoint via IOPaint) | **Apache-2.0** | [Advimman/lama](https://github.com/advimman/lama) / [Sanster/IOPaint](https://github.com/Sanster/IOPaint) | **YES** | **YES — No AGPL** |

## License Verification Details

- [docs/licences/detector-rtdetr.md](file:///Users/mc/people_gone/docs/licences/detector-rtdetr.md): Detailed verification and license text for the RT-DETR / DETR detector checkpoint.
- [docs/licences/sam2.1.md](file:///Users/mc/people_gone/docs/licences/sam2.1.md): Detailed verification and license text for Meta SAM 2.1 checkpoints.
- [docs/licences/big-lama.md](file:///Users/mc/people_gone/docs/licences/big-lama.md): Detailed verification and license text for big-lama inpainting weights.

## Transitive Dependency Audit

All Python dependencies listed in `server/requirements.txt` (PyTorch, torchvision, transformers, timm, opencv-python-headless, numpy, scipy, pillow, runpod, requests) were audited for viral copyleft licenses (AGPL/GPL). No AGPL or GPL dependencies are included.
