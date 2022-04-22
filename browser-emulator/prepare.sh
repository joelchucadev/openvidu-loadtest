#!/usr/bin/env bash

# Shell setup
# ===========

# Bash options for strict error checking.
set -o errexit -o errtrace -o pipefail -o nounset
shopt -s inherit_errexit 2>/dev/null || true

# Trace all commands.
set -o xtrace

DOCKER_CONTAINER="${IS_DOCKER_CONTAINER:-false}"


# Check Node.js
# =============

command -v node >/dev/null || {
    echo "Installing Node.js"
    curl -sL https://deb.nodesource.com/setup_14.x | bash -
    apt-get install --no-install-recommends --yes \
        nodejs
}


# Check Docker
# ============

command -v docker >/dev/null || {
    echo "Installing Docker CE"
    apt-get install --no-install-recommends --yes \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    source /etc/lsb-release # Get Ubuntu version definitions (DISTRIB_CODENAME).
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $DISTRIB_CODENAME stable"
    apt-get update && apt-get install --no-install-recommends --yes \
        docker-ce
    # usermod -aG docker "$USER"
    # newgrp docker
}


# Check FFmpeg
# ============

## Ffmpeg is only used with NODE_CANVAS strategy. However, this strategy consume more resources than we expected so, for now, it will be disabled
# command -v ffmpeg >/dev/null || {
#     echo "Installing Ffmpeg"
#     snap install ffmpeg
# }

SELF_PATH="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" # Absolute canonical path

# Download mediafiles
# ============

if [ "$DOCKER_CONTAINER" = false ]; then
    echo "Downloading media files..."
    "$SELF_PATH"/download_mediafiles.sh
fi

## Give execution rights to the scripts
chmod +x "$SELF_PATH"/qoe-scripts/*.sh

## Install Bazel apt repo (needed for ViSQOL)
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg
mv bazel.gpg /etc/apt/trusted.gpg.d/
echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list

## Install necessary packages
apt-get update
apt-get install --no-install-recommends -y apt-transport-https curl gnupg
apt-get update
apt-get install --no-install-recommends -y bc make cmake build-essential git libopencv-dev python3-opencv bazel libnetpbm10-dev libjpeg-turbo-progs ffmpeg imagemagick-6.q16

## Install VMAF

if [[ ! -f "/usr/local/bin/vmaf" ]]; then
curl --output "/usr/local/bin/run_vmaf" \
        --continue-at - \
        --location "https://github.com/Netflix/vmaf/releases/download/v2.3.0/vmaf"
fi
chmod +x /usr/local/bin/run_vmaf
export VMAF_PATH=/usr/local/bin
echo export VMAF_PATH=/usr/local/bin | tee -a /etc/profile

## Install VQMT
git clone https://github.com/Rolinh/VQMT
cd VQMT
make
mv ./build/bin/Release/vqmt /usr/local/bin/vqmt
cd ..
rm -rf VQMT
export VQMT_PATH=/usr/local/bin
echo export VQMT_PATH=/usr/local/bin | tee -a /etc/profile

## Install PESQ
git clone https://github.com/dennisguse/ITU-T_pesq
cd ITU-T_pesq
make
mv ./bin/itu-t-pesq2005 /usr/local/bin/pesq
cd ..
rm -rf ITU-T_pesq
export PESQ_PATH=/usr/local/bin
echo export PESQ_PATH=/usr/local/bin | tee -a /etc/profile

## Install VISQOL
curl --output "/tmp/visqol.tar.gz" \
        --continue-at - \
        --location "https://github.com/google/visqol/archive/refs/tags/v3.1.0.tar.gz"
cd /tmp
tar -xvf visqol.tar.gz
rm visqol.tar.gz
cd visqol-3.1.0
bazel build :visqol -c opt
cd ..
mv visqol-3.1.0 /usr/local/visqol
export VISQOL_PATH=/usr/local/visqol
echo export VISQOL_PATH=/usr/local/visqol | tee -a /etc/profile
cd $SELF_PATH

## Install GOCR

curl --output "/tmp/gocr-0.52.tar.gz" \
        --continue-at - \
        --location "https://www-e.ovgu.de/jschulen/ocr/gocr-0.52.tar.gz"
cd /tmp
tar -xvf gocr-0.52.tar.gz
rm gocr-0.52.tar.gz
cd gocr-0.52
./configure
make
make install
cd ..
rm -rf gocr-0.52
cd $SELF_PATH

echo "Instance is ready"
