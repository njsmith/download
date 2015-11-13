#!/bin/bash
#
# Install RadiaSoft containers
#
# TODO(robnagler):
#    - delegated argument parsing
#    - modularize better (delegation model to other repos?)
#    - add codes.sh (so can install locally and remotely)
#    - better logging for hopper install
#    - leave in directory match? (may be overkill on automation)
#    - handle no tty case better (not working?)
#    - add channels
#    - generalized bundling with versions
#    - add test of dynamic download and static on travis (trigger for dynamic?)
#    - tests for individual codes
set -e

install_check() {
    if [[ $install_no_check ]]; then
        return
    fi
    if [[ $(ls -A | grep -v install.log) ]]; then
        install_err 'Current directory is not empty.
Please create a new directory, cd to it, and re-run this command.'
    fi
}

install_download() {
    local url=$1
    local base=$(basename "$url")
    local file=$(dirname "$0")/$base
    local res
    if [[ -r $file ]]; then
        res=$(<$file)
        install_log cat "$file"
    else
        if [[ $url == $base ]]; then
            url=$install_url/$base
        fi
        install_log curl -L -s -S "$url"
        res=$(curl -L -s -S "$url")
    fi
    if [[ ! $res =~ ^#! ]]; then
        install_err "Unable to download $url"
    fi
    echo "$res"
}

install_err() {
    trap - EXIT
    install_msg "$@
If you don't know what to do, please contact support@radiasoft.net."
    exit 1
}

install_err_trap() {
    set +e
    trap - EXIT
    if [[ ! $install_verbose ]]; then
        tail -10 "$install_log_file"
    fi
    install_log 'Error trap'
    install_err 'Unexpected error; Install failed.'
}

install_exec() {
    install_log "$@"
    if [[ $install_verbose ]]; then
        "$@" 2>&1 | tee -a $install_log_file
    else
        "$@" >> $install_log_file 2>&1
    fi
}

install_info() {
    local f=install_msg
    if [[ $install_verbose ]]; then
        install_log "$@" ...
    fi
    #TODO(robnagler) $install_silent
    $f "$@" ...
}

install_log() {
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$@" >> $install_log_file
    if [[ $install_verbose ]]; then
        install_msg "$@"
    fi
}

install_main() {
    install_log_file=$PWD/install.log
    trap install_err_trap EXIT
    install_log install_main
    install_vars "$@"
    install_check
    eval "$(install_download $install_type.sh)"
    trap - EXIT
}

install_msg() {
    echo "$@" 1>&2
}

install_radia_run() {
    local script=radia-run
    install_log "Creating $script"
    local common=$(install_download "$install_type-run.sh")
    local guest_dir=/vagrant
    local guest_user=vagrant
    local uri=
    case $install_image in
        */radtrack)
            cmd=radia-run-radtrack
            ;;
        */sirepo)
            cmd="radia-run-sirepo $install_port $guest_dir"
            uri=/srw
            ;;
        */isynergia)
            cmd=synergia-ipython-beamsim
            uri=/
    esac
    cat > "$script" <<EOF
#!/bin/bash
#
# Invoke $install_type run on $cmd
#
radia_run_cmd='$cmd'
radia_run_container=\$(id -u -n)-\$(basename '$install_image')
radia_run_guest_dir='$guest_dir'
radia_run_guest_user='$guest_user'
radia_run_image='$install_image'
radia_run_port='$install_port'
radia_run_uri='$uri'
radia_run_x11='$install_x11'

$(declare -f install_msg install_err | sed -e 's,^install,radia_run,')

$common
EOF
    cat >> "$script" <<EOF
radia_run_prompt() {
    if [[ $radia_run_uri ]]; then
        install_msg "
Point your browser to:

http://127.0.0.1:$radia_run_port$radia_run_uri
"
    elif [[ $x11 ]]; then
        install_msg '
Starting X11 application. Look for window to popup
'
    fi
}

radia_run_main "$@"
EOF
    chmod +x "$script"
    install_info "To restart, enter this command in the shell:

 ./$script
"
    exec "./$script"
}

install_usage() {
    install_err "$@
usage: $(basename $0) [docker|hopper|vagrant] beamsim|isynergia|python2|radtrack|sirepo|synergia"
}

install_vars() {
    if [[ hopper == $NERSC_HOST ]]; then
        install_type=hopper
    else
        case "$(uname)" in
            [Dd]arwin)
                if [[ $(type -t vagrant) ]]; then
                    install_type=vagrant
                else
                    install_err 'Please install Vagrant and restart install'
                fi
                ;;
            [Ll]inux)
                if [[ $(type -t docker) ]]; then
                    install_type=docker
                elif [[ $(type -t vagrant) ]]; then
                    install_type=vagrant
                else
                    install_err 'Please install Docker or Vagrant and restart install'
                fi
                ;;
            *)
                install_err "$(uname) is an unsupported system, sorry"
                ;;
        esac
    fi
    install_image=
    install_verbose=
    while [[ "$1" ]]; do
        case "$1" in
            beamsim|isynergia|python2|radtrack|sirepo)
                install_image=$1
                ;;
            hopper)
                install_type=$1
                ;;
            synergia)
                install_image=$1
                ;;
            vagrant|docker)
                install_type=$1
                ;;
            verbose)
                install_verbose=1
                ;;
            quiet)
                install_verbose=
                ;;
            *)
                install_usage "$1: unknown install option"
                ;;
        esac
        shift
    done
    if [[ ! $install_image ]]; then
        install_image=$(basename "$PWD")
        if [[ ! $install_image =~ ^(beamsim|isynergia|python2|radtrack|sirepo)$ ]]; then
            install_usage "Please supply a install name: beamsim, isynergia, python2, radtrack, sirepo, synergia"
        fi
    fi
    case $install_type in
        vagrant|docker)
            if [[ $NERSC_HOST ]]; then
                install_usage "You can't install vagrant or docker at NERSC"
            fi
            if [[ $install_image == synergia ]]; then
                install_msg 'Switching image to "beamsim" which includes synergia'
                install_image=beamsim
            fi
            if [[ $install_image == isynergia ]]; then
                if [[ $install_type == docker ]]; then
                    install_no_check=1
                else
                    install_usage 'isynergia is only supported for docker'
                fi
            fi
            if [[ $install_image == radtrack ]]; then
                install_x11=1
            fi
            if [[ $install_image =~ isynergia|sirepo ]]; then
                install_port=8000
            fi
            install_image=radiasoft/$install_image
            ;;
        hopper)
            install_no_check=1
            if [[ $NERSC_HOST != hopper ]]; then
                install_usage "You are not running on $install_type so can't install"
            fi
            if [[ $install_image != synergia ]]; then
                install_usage "Can only install synergia on $install_type"
            fi
            ;;
    esac
    install_url=https://raw.githubusercontent.com/radiasoft/download/master/bin
}

install_main "$@"
