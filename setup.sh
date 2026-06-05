#!/bin/bash

: << 'DOC'
Hyeonjeong Jeong
June 05, 2026

[setup.sh]
  새 GPU 서버에서 한번에 OpenVLA-OFT 및 LIBERO 설치

[사용 방법]
  step 1. (로컬 환경) ssh ubuntu@<새 인스턴스 IP>
  step 2. (서버 환경) wget https://raw.githubusercontent.com/jeongxhj/openvla-oft-study/main/setup.sh && bash setup.sh

[설치 완료 후 빠른 평가 실행]
  $ source ~/.bashrc
  $ conda activate openvla-oft
  $ cd ~/openvla-oft
  $ python experiments/robot/libero/run_libero_eval.py \
    --pretrained_checkpoint moojink/openvla-7b-oft-finetuned-libero-spatial \
    --task_suite_name libero_spatial --num_trials_per_task 3
DOC

set -e

# ============================================================
# Printing Helper
WIDTH=$(tput cols 2>/dev/null || echo 60)

line() { printf '\e[90m%*s\e[0m\n' "$WIDTH" '' | tr ' ' '='; }

header() {
    local text="$1"
    local pad=$(( (WIDTH - ${#text}) / 2 )); [ $pad -lt 0 ] && pad=0
    echo ""
    line
    printf "\e[1;32m%*s%s\e[0m\n" $pad "" "$text"
    line }

info() { printf "\e[36m  > %s\e[0m\n" "$1"; }
skip() { printf "\e[33m  > %s (skip)\e[0m\n" "$1"; }
done_msg() { printf "\e[1;32m  OK\e[0m\n"; }

# ============================================================
# Version constraints (shared by Steps 3-5)
cat > /tmp/constraints.txt << 'EOF'
torch==2.2.0
torchvision==0.17.0
torchaudio==2.2.0
numpy==1.26.4
opencv-python==4.9.0.80
EOF

# ============================================================
header "Step 1/6: Install Miniconda3"

if [ ! -d "$HOME/miniconda3" ]; then
    info "downloading installer..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    
    info "installing Miniconda3..."
    bash /tmp/miniconda.sh -b -p "$HOME/miniconda3" > /dev/null
    echo 'source $HOME/miniconda3/etc/profile.d/conda.sh' >> ~/.bashrc
else
    skip "Miniconda3 already installed"
fi

source "$HOME/miniconda3/etc/profile.d/conda.sh"
info "accepting Conda Terms of Service..."
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main > /dev/null 2>&1 || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r    > /dev/null 2>&1 || true

done_msg

# ============================================================
header "Step 2/6: Create Conda Environment (python 3.10)"

info "conda env name: openvla-oft"
if conda env list | grep -q "^openvla-oft "; then
    skip "conda environment already exists"
else
    info "creating conda env..."
    conda create -n openvla-oft python=3.10 -y
fi
conda activate openvla-oft
done_msg

# ============================================================
header "Step 3/6: Install OpenVLA-OFT"

info "version constraints: torch 2.2.0 / numpy 1.26.4 / opencv 4.9.0.80"

cd "$HOME"
if [ -d "openvla-oft" ]; then
    skip "openvla-oft repository already cloned"
else
    info "cloning openvla-oft..."
    git clone https://github.com/moojink/openvla-oft.git
fi
cd openvla-oft

if python -c "import evdev" 2>/dev/null; then
    skip "evdev already installed"
else
    info "installing evdev..."
    conda install conda-forge::evdev -y
fi

if pip show openvla-oft > /dev/null 2>&1; then
    skip "openvla-oft already installed"
else
    info "installing openvla-oft..."
    pip install -e . -c /tmp/constraints.txt
fi
done_msg

# ============================================================
header "Step 4/6: Install LIBERO"

cd "$HOME"
if [ -d "LIBERO" ]; then
    skip "LIBERO repository already cloned"
else
    info "cloning LIBERO..."
    git clone https://github.com/Lifelong-Robot-Learning/LIBERO.git
fi
cd LIBERO

if pip show libero > /dev/null 2>&1; then
    skip "libero already installed"
else
    info "installing LIBERO..."
    pip install -e . -c /tmp/constraints.txt
fi

info "adding LIBERO to PYTHONPATH..."
grep -qxF 'export PYTHONPATH=$HOME/LIBERO:$PYTHONPATH' ~/.bashrc || \
    echo 'export PYTHONPATH=$HOME/LIBERO:$PYTHONPATH' >> ~/.bashrc
done_msg

# ============================================================
header "Step 5/6: Install OpenVLA-OFT Requirements"

cd "$HOME/openvla-oft"
if python -c "import robosuite" 2>/dev/null; then
    skip "libero requirements already installed"
else
    info "installing libero requirements..."
    pip install -r experiments/robot/libero/libero_requirements.txt -c /tmp/constraints.txt
fi

if python -c "import hf_transfer" 2>/dev/null; then
    skip "hf_transfer already installed"
else
    info "installing hf_transfer..."
    pip install hf_transfer -c /tmp/constraints.txt
fi
done_msg

# ============================================================
header "Step 6/6: Configure System and Environment"

if dpkg -s libosmesa6-dev > /dev/null 2>&1; then
    skip "rendering libs already installed"
else
    info "installing rendering libs (osmesa) + tmux..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq libosmesa6-dev libegl1 libgl1 tmux > /dev/null
fi
sudo usermod -aG render,video "$USER" || true

info "writing env vars to ~/.bashrc..."
grep -qxF 'export MUJOCO_GL=osmesa' ~/.bashrc || cat >> ~/.bashrc << 'EOF'
export MUJOCO_GL=osmesa
export PYOPENGL_PLATFORM=osmesa
export HF_HUB_ENABLE_HF_TRANSFER=1
export TOKENIZERS_PARALLELISM=false
EOF
export MUJOCO_GL=osmesa
export PYOPENGL_PLATFORM=osmesa

info "running LIBERO first-run config (auto 'n')..."
echo "n" | python -c "from libero.libero import benchmark" > /dev/null 2>&1 || true
done_msg

# ============================================================
header "SETUP COMPLETE"

printf "\e[1;37m  Quick Start: Evaluation\e[0m\n\n"
printf "  $ source ~/.bashrc\n"
printf "  $ conda activate openvla-oft\n"
printf "  $ cd ~/openvla-oft\n"
printf "  $ python experiments/robot/libero/run_libero_eval.py \\\\\n"
printf "    --pretrained_checkpoint moojink/openvla-7b-oft-finetuned-libero-spatial \\\\\n"
printf "    --task_suite_name libero_spatial --num_trials_per_task 3\e[0m\n\n"
