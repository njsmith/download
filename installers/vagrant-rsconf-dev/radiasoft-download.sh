#!/bin/bash
#
# Create a rsconf dev box
#
set -euo pipefail

vagrant_rsconf_dev_main() {
    if [[ ${1:-} == master ]]; then
        install_server=file:///home/vagrant/src/radiasoft/rsconf/run/srv \
            vagrant_rsconf_dev_master
    else
        vagrant_dev_barebones=1 \
            install_server=http://v3.radia.run:2916 \
            vagrant_rsconf_dev_worker
    fi
}

vagrant_rsconf_dev_master() {
    install_repo_eval vagrant-centos7
    bivio_vagrant_ssh <<'EOF'
        bivio_pyenv_2
        set -euo pipefail
        sudo yum install -y nginx
        mkdir -p ~/src/radiasoft
        cd ~/src/radiasoft
        gcl download
        gcl containers
        gcl pykern
        cd pykern
        pip install -e .
        cd ..
        gcl rsconf
        cd rsconf
        pip install -e .
        mkdir -p rpm
        cd rpm
        curl -S -s -L -O https://depot.radiasoft.org/foss/bivio-perl-dev.rpm
        curl -S -s -L -O https://depot.radiasoft.org/foss/perl-Bivio-dev.rpm
        cd ..
        rsconf build
EOF
    vagrant_rsconf_dev_run || true
    vagrant reload
    vagrant_rsconf_dev_run
    # For building perl rpms (see build-perl-rpm.sh)
    bivio_vagrant_ssh sudo usermod -aG docker vagrant
}

vagrant_rsconf_dev_run() {
    bivio_vagrant_ssh sudo su - <<EOF
        set -euo pipefail
        export install_channel=dev install_server=$install_server
        curl "$install_server/index.html" | bash -s rsconf.sh "\$(hostname -f)" setup_dev
EOF
}

vagrant_rsconf_dev_worker() {
    install_repo_eval vagrant-centos7
    vagrant_rsconf_dev_run || true
    vagrant reload
    vagrant_rsconf_dev_run
}

vagrant_rsconf_dev_main ${install_extra_args[@]+"${install_extra_args[@]}"}
