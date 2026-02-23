import streamlit as st
import subprocess
import os

# Konfigurasi Halaman Web
st.set_page_config(page_title="LLM Auto-Converter", page_icon="🚀", layout="wide")

st.title("🚀 LLM Auto-Converter & Deployer")
st.markdown("Antaramuka kawalan untuk menukar model LoRA/MLX kepada GGUF dan terus ke Ollama.")
st.markdown("---")

# 🎛️ BAHAGIAN 1: INPUT PENGGUNA (Form)
col1, col2 = st.columns(2)

with col1:
    st.subheader("📂 Tetapan Fail & Model")
    base_model = st.text_input("Base Model (HuggingFace)", value="LLM BASE")
    adapter_path = st.text_input("Adapter Path (Folder LoRA)", value="/path/to/your/lora_adapter"")
    
    # Dropdown untuk kaedah Kuantisasi
    quant_method = st.selectbox(
        "Tahap Kuantisasi (Quant Method)", 
        ["Q4_K_M", "Q5_K_M", "Q8_0", "F16"],
        index=0,
        help="Q4_K_M adalah seimbang (saiz kecil, pintar). Q8_0 lebih besar dan pandai."
    )

with col2:
    st.subheader("💾 Tetapan Output")
    save_path = st.text_input("Save Path (Folder Fused MLX)", value="/path/to/save/fused_model")
    gguf_out = st.text_input("GGUF Output File", value="/path/to/output/model.gguf")

st.markdown("---")

# 🚀 BAHAGIAN 2: BUTANG EKSEKUSI
if st.button("🔥 JALANKAN AUTOMASI SEKARANG", use_container_width=True, type="primary"):
    
    # Semak jika skrip bash wujud
    if not os.path.exists("./convert_all.sh"):
        st.error("❌ Ralat: Fail `convert_all.sh` tidak dijumpai di direktori ini!")
    else:
        # Bina arahan Terminal menggunakan ciri CLI Override kita
        command = [
            "./convert_all.sh",
            "--base", base_model,
            "--adapter", adapter_path,
            "--save", save_path,
            "--out", gguf_out,
            "--quant", quant_method
        ]
        
        st.info("⚙️ Proses sedang berjalan. Sila pantau log di bawah...")
        
        # Sediakan kotak visual untuk Terminal Log
        log_container = st.empty()
        log_text = ""
        
        # Panggil skrip bash dan tangkap outputnya secara "Live"
        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            
            # Kemas kini log di WebUI baris demi baris
            for line in process.stdout:
                log_text += line
                log_container.code(log_text, language="bash")
                
            process.wait() # Tunggu sampai skrip habis
            
            # Semak status akhir (Exit Code)
            if process.returncode == 0:
                st.success("✨ SELESAI! Model anda telah sedia dalam Ollama.")
                st.balloons() # Animasi belon!
            else:
                st.error(f"❌ Ralat berlaku! Skrip terhenti dengan kod: {process.returncode}")
                
        except Exception as e:
            st.error(f"❌ Ralat sistem: {e}")