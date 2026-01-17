#!/bin/bash
# -------------------------------------------------------------
# RunPod Network Volume Preparation Script - Qwen Image Workflow
# Run this in the Jupyter Terminal of your temporary pod
# Target GPU: H200 SXM, H100 NVL, or H100 SXM
# -------------------------------------------------------------

echo "🚀 Starting Network Volume Setup for Qwen Image..."

# 0. Ensure wget is installed and ready
if ! command -v wget &> /dev/null; then
    echo "📦 'wget' not found. Installing..."
    apt-get update && apt-get install -y wget
fi

# 1. Create directory structure
echo "📂 Creating directory structure..."
mkdir -p /workspace/models/diffusion_models
mkdir -p /workspace/models/loras
mkdir -p /workspace/models/vae
mkdir -p /workspace/models/text_encoders
mkdir -p /workspace/models/clip

# 2. Download Qwen Image Diffusion Model (Hugging Face)
echo "⬇️ Downloading Qwen Image Diffusion Model (~20GB BF16)..."
cd /workspace/models/diffusion_models
if [ ! -f "qwen_image_bf16.safetensors" ]; then
    wget -O qwen_image_bf16.safetensors "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_bf16.safetensors"
else
    echo "✅ qwen_image_bf16.safetensors already exists, skipping..."
fi

# 3. Download Qwen Text Encoder (Hugging Face)
echo "⬇️ Downloading Qwen Text Encoder (~14GB)..."
cd /workspace/models/text_encoders
if [ ! -f "qwen_2.5_vl_7b.safetensors" ]; then
    wget -O qwen_2.5_vl_7b.safetensors "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b.safetensors"
else
    echo "✅ qwen_2.5_vl_7b.safetensors already exists, skipping..."
fi
# Symlink to clip folder for compatibility
ln -sf /workspace/models/text_encoders/qwen_2.5_vl_7b.safetensors /workspace/models/clip/qwen_2.5_vl_7b.safetensors

# 4. Download Qwen VAE (Hugging Face)
echo "⬇️ Downloading Qwen VAE..."
cd /workspace/models/vae
if [ ! -f "qwen_image_vae.safetensors" ]; then
    wget -O qwen_image_vae.safetensors "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"
else
    echo "✅ qwen_image_vae.safetensors already exists, skipping..."
fi

# 5. Download LoRAs from Civitai
echo "⬇️ Downloading LoRAs..."
cd /workspace/models/loras

# Civitai Model ID 2335968 (1GIRL_QWEN_V1)
if [ ! -f "1GIRL_QWEN_V1.safetensors" ]; then
    echo "⬇️ Downloading 1GIRL_QWEN_V1 LoRA (Civitai ID 2335968)..."
    wget "https://civitai.com/api/download/models/2335968?type=Model&format=SafeTensor&token=1f8ccf1c625fbccb31b886935bf663b8" --content-disposition
    # Rename to expected filename if different
    if [ -f "*.safetensors" ] && [ ! -f "1GIRL_QWEN_V1.safetensors" ]; then
        mv *.safetensors 1GIRL_QWEN_V1.safetensors
    fi
else
    echo "✅ 1GIRL_QWEN_V1.safetensors already exists, skipping..."
fi

# Civitai Model ID 2270374 (samsungcam)
if [ ! -f "samsungcam.safetensors" ]; then
    echo "⬇️ Downloading samsungcam LoRA (Civitai ID 2270374)..."
    wget "https://civitai.com/api/download/models/2270374?type=Model&format=SafeTensor&token=00d790b1d7a9934acb89ef729d04c75a" --content-disposition
    # Rename to expected filename if different  
    for f in *.safetensors; do
        if [ "$f" != "1GIRL_QWEN_V1.safetensors" ] && [ "$f" != "samsungcam.safetensors" ]; then
            mv "$f" samsungcam.safetensors
            break
        fi
    done
else
    echo "✅ samsungcam.safetensors already exists, skipping..."
fi

# 6. Verify Content
echo ""
echo "✅ Detailed verification..."
echo "--- LORAS ---"
ls -lah /workspace/models/loras/
echo "--- DIFFUSION ---"
ls -lah /workspace/models/diffusion_models/
echo "--- VAE ---"
ls -lah /workspace/models/vae/
echo "--- TEXT ENCODERS ---"
ls -lah /workspace/models/text_encoders/
echo "--- CLIP (symlinks) ---"
ls -lah /workspace/models/clip/

# 7. Space usage summary
echo ""
echo "📊 Total space usage:"
du -sh /workspace/models/*

echo ""
echo "🎉 All Done! You can now terminate this pod and start your Serverless Endpoint."
echo ""
echo "📝 Notes for Qwen Image workflow:"
echo "   - This workflow requires H200 SXM, H100 NVL, or H100 SXM for best performance"
echo "   - The BF16 diffusion model is large (~20GB VRAM needed)"
echo "   - Total estimated storage: ~40-50GB"
