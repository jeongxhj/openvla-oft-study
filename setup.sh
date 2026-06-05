#!/bin/bash
# ============================================================
#  setup.sh — OpenVLA-OFT + LIBERO 환경 자동 구축
#  사용법: bash setup.sh
# ============================================================

# 오류 발생시 바로 종료
set -e

# ==== 출력 도우미 ====
WIDTH=$(tput cols 2>/dev/null || echo 60)

line() { printf '\e[90m%*s\e[0m\n' "$WIDTH" '' | tr ' ' '='; }

header() {  # 단계 제목: 초록 굵은 글씨, 가운데 정렬, 전체 폭 구분선
    local text="$1"
    local pad=$(( (WIDTH - ${#text}) / 2 )); [ $pad -lt 0 ] && pad=0
    echo ""
    line
    printf "\e[1;32m%*s%s\e[0m\n" $pad "" "$text"
    line
}

info() { printf "\e[36m  > %s\e[0m\n" "$1"; }          # 시안: 진행 정보
skip() { printf "\e[33m  > %s (skip)\e[0m\n" "$1"; }   # 노랑: 건너뜀
done_msg() { printf "\e[1;32m  OK\e[0m\n"; }


# ============================================================
header "[1/6] Miniconda3"
if [ ! -d "$HOME/miniconda3" ]; then
    info "downloading installer..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    info "installing (batch mode)..."
    bash /tmp/miniconda.sh -b -p "$HOME/miniconda3" > /dev/null
    echo 'source $HOME/miniconda3/etc/profile.d/conda.sh' >> ~/.bashrc
else
    skip "Miniconda3 already installed"
fi
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main > /dev/null 2>&1 || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r    > /dev/null 2>&1 || true
done_msg

# ============================================================
header "[2/6] conda env: openvla-oft (python 3.10)"
if conda env list | grep -q "^openvla-oft "; then
    skip "env already exists"
else
    conda create -n openvla-oft python=3.10 -y
fi
conda activate openvla-oft
done_msg

# ============================================================
header "[3/6] version constraints"
# 버전 충돌 일어났더 것들 충돌 안되게끔..
cat > /tmp/constraints.txt << 'EOF'
torch==2.2.0
torchvision==0.17.0
torchaudio==2.2.0
numpy==1.26.4
opencv-python==4.9.0.80
EOF
info "torch 2.2.0 / numpy 1.26.4 / opencv 4.9.0.80"
done_msg

# ============================================================
header "[4/6] OpenVLA-OFT clone & install"
cd "$HOME"
if [ -d "openvla-oft" ]; then
    skip "repo already cloned"
else
    git clone https://github.com/moojink/openvla-oft.git
fi
cd openvla-oft

# evdev가 기본으로 설치되어 있지 않아서 설치되어있어야 함!
if python -c "import evdev" 2>/dev/null; then
    skip "evdev already installed"
else
    info "installing evdev"
    conda install conda-forge::evdev -y
fi

# openvla-oft 설치
if pip show openvla-oft > /dev/null 2>&1; then
    skip "openvla-oft already installed"
else
    pip install -e . -c /tmp/constraints.txt
fi
done_msg

# ============================================================
header "[5/6] LIBERO clone & install"
cd "$HOME"
if [ -d "LIBERO" ]; then
    skip "repo already cloned"
else
    git clone https://github.com/Lifelong-Robot-Learning/LIBERO.git
fi
cd LIBERO

# LIBERO 설치
if pip show libero > /dev/null 2>&1; then
    skip "libero already installed"
else
    pip install -e . -c /tmp/constraints.txt
fi

# Git으로 LIBERO 설치시 PATH 지정해주어야 함!!
grep -qxF 'export PYTHONPATH=$HOME/LIBERO:$PYTHONPATH' ~/.bashrc || \
    echo 'export PYTHONPATH=$HOME/LIBERO:$PYTHONPATH' >> ~/.bashrc

# ============================================================
header "[6/7] Openvla-OFT Requirement Install"
cd "$HOME/openvla-oft"
if python -c "import robosuite" 2>/dev/null; then
    skip "libero requirements already installed"
else
    pip install -r experiments/robot/libero/libero_requirements.txt -c /tmp/constraints.txt
fi

python -c "import hf_transfer" 2>/dev/null && skip "hf_transfer already installed" || \
    pip install hf_transfer -c /tmp/constraints.txt
done_msg

# ============================================================
header "[7/7] system & env config"
if dpkg -s libosmesa6-dev > /dev/null 2>&1; then
    skip "rendering libs already installed"
else
    info "installing rendering libs (osmesa) + tmux"
    sudo apt-get update -qq
    sudo apt-get install -y -qq libosmesa6-dev libegl1 libgl1 tmux > /dev/null
fi
sudo usermod -aG render,video "$USER" || true

info "env vars -> ~/.bashrc"
grep -qxF 'export MUJOCO_GL=osmesa' ~/.bashrc || cat >> ~/.bashrc << 'EOF'
export MUJOCO_GL=osmesa
export PYOPENGL_PLATFORM=osmesa
export HF_HUB_ENABLE_HF_TRANSFER=1
export TOKENIZERS_PARALLELISM=false
EOF
export MUJOCO_GL=osmesa
export PYOPENGL_PLATFORM=osmesa

info "LIBERO first-run config (auto 'n')"
echo "n" | python -c "from libero.libero import benchmark" > /dev/null 2>&1 || true
done_msg

# ============================================================
header "SETUP COMPLETE"
printf "\e[1;37m  다음 명령으로 평가를 실행하세요:\e[0m\n\n"
printf "\e[1;36m    $ source ~/.bashrc\n"
printf "    $ conda activate openvla-oft\n"
printf "    $ cd ~/openvla-oft\n"
printf "    $ python experiments/robot/libero/run_libero_eval.py \\\\\n"
printf "      --pretrained_checkpoint moojink/openvla-7b-oft-finetuned-libero-spatial \\\\\n"
printf "      --task_suite_name libero_spatial --num_trials_per_task 3\e[0m\n\n"
