#!/bin/bash

# ==============================================================================
# 🚀 NAMA SKRIP   : convert_all.sh (LLM Auto-Converter & Deployer)
#
# 🎯 TUJUAN
#   Mengautomasikan proses menukar model AI (LoRA/MLX) kepada format GGUF
#   (quantized & optimized) dan mendaftarkannya ke dalam Ollama untuk digunakan
#   sebagai model inference tempatan.
#
# 💡 RASIONAL PENGGUNAAN
#   1. Automasi Penuh   : Menggabungkan proses fuse → convert → quantize → deploy
#                         dalam satu arahan sahaja.
#   2. Konsistensi      : Menggunakan aliran penukaran standard bagi mengurangkan
#                         risiko ketidakpadanan tensor.
#   3. Pre-flight Check : Menyemak keperluan sistem (CMake, Brew, Python, Ollama)
#                         sebelum proses bermula.
#   4. Pengurusan Fail  : Menjana Modelfile secara automatik dan membersihkan
#                         fail sementara selepas proses selesai.
# 💡 QoL FEATURES :
#   1. CLI Override : Boleh tukar setting tanpa usik .env (cth: --quant Q8_0)
#   2. Time Tracker : Mengira jumlah masa proses dari mula hingga tamat.
#
# 📦 DEPENDENCIES
#   - llama.cpp
#   - mlx_lm
#   - huggingface_hub
#   - Ollama
#
# ⚙️ CARA GUNA
#   1. Kemas kini fail '.env'
#   2. Jalankan arahan: ./convert_all.sh
# ==============================================================================

# Berhenti serta-merta jika ada ralat (e), variable kosong (u), atau pipe gagal (o)
set -euo pipefail

# ⏱️ MULA KIRA MASA
START_TIME=$SECONDS

# 🧹 ULTRA-POLISH: Trap senyap.
trap '[[ -f temp_f16.gguf ]] && rm -f temp_f16.gguf && echo "🧹 Auto-cleanup: temp_f16.gguf dipadam dari storan."' EXIT

echo "=========================================="
echo "🚀 MEMULAKAN PROSES AUTOMASI LLM"
echo "=========================================="

# --------------------------------------
# 1. BACA .ENV & CLI OVERRIDE
# --------------------------------------
if [ -f .env ]; then
    source .env
    echo "✅ Fail .env berjaya dibaca."
else
    echo "❌ RALAT: Fail .env tidak dijumpai di folder ini!"
    exit 1
fi

# 🎛️ CLI OVERRIDE (Fungsi QoL Baru)
# Membenarkan pengguna menukar nilai .env secara "on-the-fly" melalui terminal
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --quant) QUANT_METHOD="$2"; shift ;;
        --base) BASE_MODEL="$2"; shift ;;
        --adapter) ADAPTER_PATH="$2"; shift ;;
        --save) SAVE_PATH="$2"; shift ;;
        --out) GGUF_OUT="$2"; shift ;;
        *) echo "❌ RALAT: Parameter tidak dikenali: $1"; exit 1 ;;
    esac
    shift
done

echo "🔍 Memeriksa pemboleh ubah (variables)..."
REQUIRED_VARS=(BASE_MODEL ADAPTER_PATH SAVE_PATH GGUF_OUT QUANT_METHOD)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "❌ RALAT: Pemboleh ubah '$var' tidak ditetapkan!"
        exit 1
    fi
done
echo "✅ Semua pemboleh ubah lengkap. (Kuantisasi: $QUANT_METHOD)"

# --------------------------------------
# 2. ANTI-OVERWRITE (Pelindung Model Lama)
# --------------------------------------
echo "🛡️ Memeriksa risiko 'overwrite'..."
if [ -d "$SAVE_PATH" ]; then
    echo "❌ RALAT: Folder SAVE_PATH ($SAVE_PATH) sudah wujud!"
    echo "💡 Sila padam folder tersebut atau guna flag --save [NAMA_BARU]"
    exit 1
fi

if [ -f "$GGUF_OUT" ]; then
    echo "❌ RALAT: Fail GGUF_OUT ($GGUF_OUT) sudah wujud!"
    echo "💡 Sila padam fail tersebut atau guna flag --out [NAMA_BARU]"
    exit 1
fi

# ==========================================
# 🔍 BAHAGIAN 1: SISTEM CHECK (PRE-FLIGHT)
# ==========================================
echo "🧐 Memeriksa keperluan sistem & storan..."

# Semakan Ruang Storan (Penting: Perlu sekurang-kurangnya 40GB)
FREE_SPACE=$(df -g . | awk 'NR==2 {print $4}')
if [ "$FREE_SPACE" -lt 40 ]; then
    echo "❌ RALAT: Ruang storan tidak mencukupi! Anda cuma ada ${FREE_SPACE}GB."
    echo "💡 Proses ini memerlukan sekurang-kurangnya 40GB ruang kosong sementara."
    exit 1
fi
echo "✅ Ruang storan mencukupi (${FREE_SPACE}GB wujud)."

if ! xcode-select -p &>/dev/null; then
    echo "❌ RALAT: Xcode Tools tidak dijumpai. Jalankan: xcode-select --install"
    exit 1
fi

if ! command -v brew &>/dev/null; then
    echo "❌ RALAT: Homebrew tidak dijumpai. Sila pasang dari https://brew.sh"
    exit 1
fi

if ! command -v cmake &>/dev/null; then
    echo "📦 Memasang CMake via Brew..."
    brew install cmake
fi

if ! command -v ollama &>/dev/null; then
    echo "❌ RALAT: Ollama tidak dijumpai. Sila pasang dari https://ollama.com dahulu."
    exit 1
fi

# Semakan Persekitaran Python yang Ketat
if [[ -z "${CONDA_DEFAULT_ENV:-}" && -z "${VIRTUAL_ENV:-}" ]]; then
    echo "❌ RALAT: Tiada persekitaran Python (Conda/venv) yang aktif!"
    echo "💡 Sila aktifkan dahulu, contoh: conda activate mlx_env"
    exit 1
fi
echo "✅ Environment aktif dikesan."

echo "🐍 Memeriksa library Python..."
REQUIRED_PKGS=("mlx_lm" "huggingface_hub" "numpy")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! python3 -c "import importlib.util, sys; sys.exit(1) if importlib.util.find_spec('$pkg') is None else sys.exit(0)" &>/dev/null; then
        echo "📦 Memasang $pkg..."
        python3 -m pip install "$pkg" --quiet
    fi
done

if [ ! -f "./llama.cpp/build/bin/llama-quantize" ]; then
    echo "🏗️ Membina enjin llama-quantize..."
    if [ -d "llama.cpp" ]; then
        cd llama.cpp
        cmake -B build -DCMAKE_BUILD_TYPE=Release
        cmake --build build --target llama-quantize
        python3 -m pip install -r requirements.txt --quiet
        cd ..
    else
        echo "❌ RALAT: Folder llama.cpp tidak dijumpai di direktori ini!"
        exit 1
    fi
fi

# ==========================================
# ⚙️ BAHAGIAN 2: PROSES KONVERSI
# ==========================================

echo "--------------------------------------"
echo "📂 Langkah 1: Fusing Model (MLX)..."
mlx_lm.fuse --model "$BASE_MODEL" --adapter-path "$ADAPTER_PATH" --save-path "$SAVE_PATH"

echo "--------------------------------------"
echo "🔄 Langkah 2: Convert ke GGUF F16..."
python3 llama.cpp/convert_hf_to_gguf.py "$SAVE_PATH" --outfile temp_f16.gguf

if [ ! -f temp_f16.gguf ]; then
    echo "❌ RALAT: Conversion ke GGUF gagal secara senyap. Fail temp_f16.gguf tidak dijumpai!"
    exit 1
fi

echo "--------------------------------------"
echo "📉 Langkah 3: Kuantisasi ($QUANT_METHOD)..."
./llama.cpp/build/bin/llama-quantize temp_f16.gguf "$GGUF_OUT" "$QUANT_METHOD"

if [ ! -f "$GGUF_OUT" ]; then
    echo "❌ RALAT: Proses Kuantisasi gagal menghasilkan $GGUF_OUT!"
    exit 1
fi

echo "--------------------------------------"
echo "📝 Langkah 4: Menjana Modelfile..."
cat <<EOF > Modelfile
FROM $GGUF_OUT
PARAMETER temperature 0.7
SYSTEM "Anda adalah pembantu AI yang pakar dalam hal ehwal Malaysia. Jawab dalam Bahasa Melayu yang natural."
EOF

echo "--------------------------------------"
MODEL_NAME=$(basename "$GGUF_OUT" .gguf | tr '[:upper:]' '[:lower:]' | tr '_' '-')
echo "🤖 Langkah 5: Pendaftaran Ollama ($MODEL_NAME)..."
ollama create "$MODEL_NAME" -f Modelfile

echo "--------------------------------------"

# ⏱️ KIRAAN MASA TAMAT (Fungsi QoL Baru)
DURATION=$(( SECONDS - START_TIME ))
MINS=$(( DURATION / 60 ))
SECS=$(( DURATION % 60 ))

echo "✨ SELESAI DENGAN JAYA! Skrip berjalan sempurna."
echo "⏱️ Masa diambil: $MINS minit $SECS saat."
echo "👉 Sila taip arahan ini untuk bermula: ollama run $MODEL_NAME"
echo "=========================================="