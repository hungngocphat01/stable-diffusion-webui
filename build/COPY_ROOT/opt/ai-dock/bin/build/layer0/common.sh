#!/bin/false

source /opt/ai-dock/etc/environment.sh

build_common_main() {
    build_common_create_env
    build_common_install_jupyter_kernels
}

build_common_create_env() {
    apt-get update
    $APT_INSTALL \
        libgl1-mesa-glx \
        libtcmalloc-minimal4

    ln -sf $(ldconfig -p | grep -Po "libtcmalloc_minimal.so.\d" | head -n 1) \
        /lib/x86_64-linux-gnu/libtcmalloc.so
    
    micromamba create -n webui
    micromamba run -n webui mamba-skel
    micromamba install -n webui -y \
        python="${PYTHON_VERSION}" \
        ipykernel \
        ipywidgets \
        nano
    micromamba run -n webui install-pytorch -v "$PYTORCH_VERSION"
}

build_common_install_jupyter_kernels() {
    micromamba install -n webui -y \
        ipykernel \
        ipywidgets
    
    kernel_path=/usr/local/share/jupyter/kernels
    
    # Add the often-present "Python3 (ipykernel) as a webui alias"
    rm -rf ${kernel_path}/python3
    dir="${kernel_path}/python3"
    file="${dir}/kernel.json"
    cp -rf ${kernel_path}/../_template ${dir}
    sed -i 's/DISPLAY_NAME/'"Python3 (ipykernel)"'/g' ${file}
    sed -i 's/PYTHON_MAMBA_NAME/'"webui"'/g' ${file}
    
    dir="${kernel_path}/webui"
    file="${dir}/kernel.json"
    cp -rf ${kernel_path}/../_template ${dir}
    sed -i 's/DISPLAY_NAME/'"WebUI"'/g' ${file}
    sed -i 's/PYTHON_MAMBA_NAME/'"webui"'/g' ${file}
}

build_common_install_webui() {
    # Get latest tag from GitHub if not provided
    if [[ -z $WEBUI_TAG ]]; then
        export WEBUI_TAG="$(curl -s $WEBUI_REPO/tags | \
            jq -r '.[0].name')"
        env-store WEBUI_TAG
    fi

    echo "web_ui repo: $WEBUI_REPO"

    cd /opt
    git clone "$WEBUI_REPO" stable-diffusion-webui
    cd /opt/stable-diffusion-webui
    git checkout "$WEBUI_TAG"
    
    micromamba run -n webui ${PIP_INSTALL} -r requirements_versions.txt
    micromamba run -n webui ${PIP_INSTALL} setuptools==69.0
}

build_common_install_kohya() {
    cd /opt
    git clone https://github.com/bmaltais/kohya_ss -b v24.1.7
    cd kohya_ss

    echo "================ NOW INSTALLING KOHYA_SS ================"
    sudo bash -c "umask 007; cd /opt/kohya_ss; ./setup-runpod.sh"
}

build_common_run_tests() {
    installed_pytorch_version=$(micromamba run -n webui python -c "import torch; print(torch.__version__)")
    if [[ "$installed_pytorch_version" != "$PYTORCH_VERSION"* ]]; then
        echo "Expected PyTorch ${PYTORCH_VERSION} but found ${installed_pytorch_version}\n"
        exit 1
    fi
}

build_common_main "$@"