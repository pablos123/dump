#!/usr/bin/env bash

# scilab 6.0.2 installer.
# La versión que se usa en la cátedra de Métodos Numéricos

scilab_tar_path=/tmp/scilab_6_0_2.tar.gz
scilab_dir_path="${HOME}/bin/scilab-6.0.2/"

mkdir -p "${HOME}/bin/"

[[ ! -s "${scilab_tar_path}" ]] &&
    wget -O "${scilab_tar_path}" 'https://www.scilab.org/download/6.0.2/scilab-6.0.2.bin.linux-x86_64.tar.gz'

[[ ! -d "${scilab_dir_path}" ]] &&
    tar -xf "${scilab_tar_path}" -C "${HOME}/bin/"

ln -fs "${scilab_dir_path}/bin/scilab" "${HOME}/bin/scilab"
ln -fs "${scilab_dir_path}/bin/scilab-cli" "${HOME}/bin/scilab-cli"
