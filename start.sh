#!/bin/bash
echo "--- 🚀 WORKER STARTING (QWEN IMAGE) ---"

# 0. OPTIMIZATIONS
# Disable ComfyUI Manager startup checks to speed up boot
export COMFYUI_MANAGER_SKIP_UPDATE=true
export COMFYUI_MANAGER_SKIP_STARTUP_CHECK=true

# 1. VOLUME DIAGNOSTIC & PREP
echo "⏳ Waiting for volume..."
for i in {1..10}; do
    if [ -d "/runpod-volume" ]; then
        echo "✅ /runpod-volume detected."
        break
    fi
    sleep 1
done

echo "📂 VOLUME CONTENT CHECK (Level 1):"
ls -F /runpod-volume/ || echo "❌ /runpod-volume is empty or unreadable"
echo "📂 VOLUME CONTENT CHECK (Level 2):"
ls -F /runpod-volume/models/ || echo "❌ /runpod-volume/models not found"

echo "🔓 Setting permissions..."
chmod 777 /runpod-volume 2>/dev/null # Only top level

echo "---------------------------------------------------"

# 2. ROBUST LINKING FUNCTION
function link_model_folder {
    COMFY_TYPE=$1   # e.g., "loras"
    SEARCH_NAME=$2  # e.g., "loras"
    
    echo "🔎 Processing '$COMFY_TYPE'..."
    
    # STRATEGY A: Direct Hardcoded Path
    DIRECT_PATH="/runpod-volume/models/$SEARCH_NAME"
    
    # STRATEGY B: Auto-Discovery
    if [ -d "$DIRECT_PATH" ]; then
        FOUND="$DIRECT_PATH"
        echo "   🎯 Found via Direct Path: $FOUND"
    elif [ -d "/workspace/models/$SEARCH_NAME" ]; then
        FOUND="/workspace/models/$SEARCH_NAME"
        echo "   🎯 Found in Workspace: $FOUND"
    else
        echo "   ⚠️ Direct path $DIRECT_PATH not found. Attempting recursive search..."
        FOUND=$(find /runpod-volume -maxdepth 4 -type d -iname "$SEARCH_NAME" -not -path "*/output/*" -print -quit)
    fi

    # EXECUTE LINK
    if [ -n "$FOUND" ]; then
        TARGET="/comfyui/models/$COMFY_TYPE"
        rm -rf "$TARGET"
        ln -s "$FOUND" "$TARGET"
        echo "   🔗 Linked: $FOUND -> $TARGET"
        
        echo "   📄 First 5 files in $TARGET:"
        ls -F "$TARGET" | head -n 5
    else
        echo "   ❌ FATAL: Could not find folder '$SEARCH_NAME' anywhere!"
    fi
}

echo "--- 🔗 STARTING LINKING PHASES ---"

# Phase 1: Standard Folders
link_model_folder "loras" "loras"
link_model_folder "vae" "vae"
link_model_folder "clip" "clip"
link_model_folder "text_encoders" "text_encoders"

# Phase 2: Diffusion/Unet (Special Handling)
echo "🔎 Processing Diffusion/Unet..."
DIFF_DIRECT="/runpod-volume/models/diffusion_models"

if [ -d "$DIFF_DIRECT" ]; then
    DIFF_FOUND="$DIFF_DIRECT"
    echo "   🎯 Found Diffusion via Direct Path: $DIFF_FOUND"
else
    DIFF_FOUND=$(find /runpod-volume -maxdepth 4 -type d \( -iname "diffusion_models" -o -iname "unet" \) -not -path "*/output/*" -print -quit)
fi

if [ -n "$DIFF_FOUND" ]; then
    # Double link for maximum compatibility
    echo "   🔗 Dual-linking diffusion dir to 'unet' and 'diffusion_models'..."
    
    rm -rf /comfyui/models/unet
    ln -s "$DIFF_FOUND" /comfyui/models/unet
    
    rm -rf /comfyui/models/diffusion_models
    ln -s "$DIFF_FOUND" /comfyui/models/diffusion_models
    
    echo "   📄 Content check (Diffusion):"
    ls -F /comfyui/models/diffusion_models | head -n 5
else
    echo "   ❌ FATAL: Diffusion/Unet models not found!"
fi

# Phase 3: Output Folder
if [ ! -d "/runpod-volume/output" ]; then
    mkdir -p /runpod-volume/output
fi
rm -rf /comfyui/output
ln -s /runpod-volume/output /comfyui/output

# 4. FINAL VERIFICATION
echo "--- 📋 FINAL VERIFICATION ---"
echo "Symlinked paths (via /comfyui/models):"
echo "  Loras: $(ls -1 /comfyui/models/loras 2>/dev/null | wc -l) files"
echo "  VAE: $(ls -1 /comfyui/models/vae 2>/dev/null | wc -l) files"
echo "  Clip: $(ls -1 /comfyui/models/clip 2>/dev/null | wc -l) files"
echo "  Text Encoders: $(ls -1 /comfyui/models/text_encoders 2>/dev/null | wc -l) files"
echo "  Diffusion: $(ls -1 /comfyui/models/diffusion_models 2>/dev/null | wc -l) files"

echo "Direct volume paths (via /runpod-volume/models):"
echo "  Loras: $(ls -1 /runpod-volume/models/loras 2>/dev/null | wc -l) files"
echo "  VAE: $(ls -1 /runpod-volume/models/vae 2>/dev/null | wc -l) files"
echo "  Clip: $(ls -1 /runpod-volume/models/clip 2>/dev/null | wc -l) files"
echo "  Text Encoders: $(ls -1 /runpod-volume/models/text_encoders 2>/dev/null | wc -l) files"
echo "  Diffusion: $(ls -1 /runpod-volume/models/diffusion_models 2>/dev/null | wc -l) files"

echo "Listing actual files in volume:"
ls -la /runpod-volume/models/loras/ 2>/dev/null || echo "  (loras dir empty or missing)"
ls -la /runpod-volume/models/diffusion_models/ 2>/dev/null || echo "  (diffusion_models dir empty or missing)"
ls -la /runpod-volume/models/text_encoders/ 2>/dev/null || echo "  (text_encoders dir empty or missing)"

# 5. START COMFYUI
echo "--- 🚀 STARTING COMFYUI ---"
cd /comfyui
python3 main.py --listen 127.0.0.1 --port 8188 --extra-model-paths-config /comfyui/extra_model_paths.yaml &

# 6. WAIT FOR READY
echo "--- ⏳ WAITING FOR PORT 8188 ---"
until python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8188/history')" > /dev/null 2>&1; do
  sleep 2
done
echo "✅ COMFYUI IS UP"

# 7. START HANDLER
echo "--- 🚀 STARTING HANDLER ---"
python3 -u /handler.py
