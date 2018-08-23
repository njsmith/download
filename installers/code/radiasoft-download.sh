#!/bin/bash
#g
# To run: curl radia.run | bash -s code warp
#
code_main() {
    local dnf=( sudo dnf --color=never -y )
    if [[ ! $(dnf -q repoinfo radiasoft-dev) =~ enabled ]]; then
        if ! rpm -q dnf-plugins-core >& /dev/null; then
            "${dnf[@]}" dnf-plugins-core
        fi
        "${dnf[@]}" config-manager --add-repo "$(install_depot_server)/yum/fedora/radiasoft.repo"
    fi
    if [[ ! ${install_extra_args:+1} ]]; then
        echo 'List of available codes:'
        dnf repoquery --queryformat '%{NAME}' rscode-\* | perl -pe 's/^rscode-//'
        return 1
    fi
    local rpms=()
    local i
    for i in "${install_extra_args[@]}"; do
        rpms+=( "rscode-$i" )
    done
    install_info "Installing: ${install_extra_args[*]}"
    "${dnf[@]}" install "${rpms[@]}"
}

code_main
