# Base image - RunPod ComfyUI Worker
FROM runpod/worker-comfyui:5.5.1-base

# 0. Install System Dependencies
RUN apt-get update && apt-get install -y curl unzip wget && rm -rf /var/lib/apt/lists/*

# 1. Install Custom Nodes

# RES4LYF - Required for ClownsharKSampler_Beta and beta57 scheduler
RUN git clone https://github.com/ClownsharkBatwing/RES4LYF /comfyui/custom_nodes/RES4LYF && \
    pip install -r /comfyui/custom_nodes/RES4LYF/requirements.txt

# rgthree-comfy - Required for Lora Loader Stack (rgthree)
RUN git clone https://github.com/rgthree/rgthree-comfy /comfyui/custom_nodes/rgthree-comfy && \
    pip install -r /comfyui/custom_nodes/rgthree-comfy/requirements.txt || true

# ComfyUI-Image-Saver - Optional but useful for better image saving
RUN comfy node install --exit-on-fail comfy-image-saver --mode remote || true

# 2. Copy Configuration Files
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# 3. Copy and Setup the Start Script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 4. Set the Entrypoint
CMD ["/start.sh"]
