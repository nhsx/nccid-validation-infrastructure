#!/bin/bash
set -eu

SETUPDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
cd "$SETUPDIR"

# Mambaforge and Minimal Snakemake
VERSION=4.10.3-6
INSTALLER=Mambaforge-$VERSION-Linux-x86_64.sh
curl -sfLO https://github.com/conda-forge/miniforge/releases/download/$VERSION/$INSTALLER
sha256sum -c $INSTALLER.sha256
sh $INSTALLER -b

~/mambaforge/bin/mamba init bash
~/mambaforge/bin/mamba create -y -q -n runtime -c bioconda \
    boto3 \
    jupyterlab \
    matplotlib \
    pandas \
    pydicom \
    snakemake
~/mambaforge/envs/runtime/bin/snakemake --version
