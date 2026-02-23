# 🚀 LLM Auto-Converter & Deployer

Satu alat automasi berkuasa tinggi untuk menukar model **LoRA/MLX** kepada format **GGUF** dan terus mendaftarkannya ke dalam **Ollama**. Projek ini menggabungkan kuasa skrip Bash untuk prestasi dan Streamlit untuk antaramuka pengguna yang mesra.

---

## 🔥 Ciri-Ciri Utama

- **⚡ Automasi End-to-End**: Proses *Fuse* → *Convert* → *Quantize* → *Deploy* dalam satu klik.
- **🌐 Web Dashboard**: Antaramuka Streamlit yang cantik dengan log terminal secara langsung (*Live Logs*).
- **💻 CLI Power-User**: Sokongan parameter terminal (`--quant`, `--base`, dll) untuk penggunaan pantas.
- **🛠️ Pre-flight Check**: Automatik menyemak ruang storan (min 40GB), dependensi (CMake, Brew), dan persekitaran Python.
- **🛡️ Pelindung Data**: Sistem *anti-overwrite* untuk mengelakkan model sedia ada terpadam secara tidak sengaja.
- **🧹 Kemas Semula**: Pembersihan automatik fail sementara (`temp_f16.gguf`) selepas selesai.

---

## 🛠️ Keperluan Sistem

- **OS**: macOS (Disyorkan Apple Silicon).
- **Alatan**: Homebrew, Ollama, Xcode Command Line Tools.
- **Python**: Persekitaran Conda atau venv yang aktif.
- **Repositori**: Folder `llama.cpp` mesti wujud dalam direktori projek.

---

## ⚙️ Pemasangan

1. **Klon Repositori**:
   ```bash
   git clone https://github.com/N4Z1T/mlx-to-ollama.git
   cd mlx-to-ollama
   
   git clone https://github.com/ggerganov/llama.cpp
   ```

2. **Sediakan Persekitaran Python**:
   ```bash
   conda create -n mlx_env python=3.10 -y
   conda activate mlx_env
   pip install mlx_lm huggingface_hub numpy streamlit
   ```

3. **Konfigurasi `.env`**:
   Cipta fail `.env` dalam folder utama:
   ```env
   BASE_MODEL="meta-llama/Meta-Llama-3-8B-Instruct"
   ADAPTER_PATH="/path/to/your/lora_adapter"
   SAVE_PATH="/path/to/save/fused_model"
   GGUF_OUT="/path/to/output/model.gguf"
   QUANT_METHOD="Q4_K_M"
   ```

---

## 🚀 Cara Penggunaan

### 1. Antaramuka Web (WebUI)
Sesuai untuk pengguna yang mahukan visual dan pemantauan mudah:
```bash
streamlit run app.py
```

### 2. Terminal (CLI)
Sesuai untuk automasi atau *power users*:

**Guna tetapan fail .env:**
```bash
chmod +x convert_all.sh
./convert_all.sh
```

**Override tetapan secara "on-the-fly":**
```bash
./convert_all.sh --quant Q8_0 --out Model_Pintar.gguf --base meta-llama/Llama-3-8B
```

---

## 📊 Aliran Kerja Skrip

1. **Fusing**: Menggabungkan adapter LoRA dengan Base Model menggunakan `mlx_lm`.
2. **Converting**: Menukar model ke format GGUF F16.
3. **Quantizing**: Mampatkan model ke saiz pilihan (cth: Q4_K_M).
4. **Deploying**: Mencipta `Modelfile` dan mendaftarkan model ke dalam Ollama secara automatik.

---

## ⏱️ Nota Prestasi
Skrip ini dilengkapi dengan *Time Tracker*. Selepas selesai, anda akan diberikan ringkasan jumlah masa yang diambil dan arahan terus untuk menjalankan model tersebut:
`👉 Sila taip arahan ini untuk bermula: ollama run <nama-model>`

---
**Dibangunkan dengan ❤️ untuk komuniti AI Malaysia.**
