#!/bin/bash

declare DIR=$PWD

# Define the following variables in build.conf file
declare VPN_SITE="vpn10.palm.com"
declare VPN_USER # Your VPN account login
declare VPN_PASS # Your VPN account password
declare MIRROR_PATH="shareuser@172.26.123.186:/home/nightbuilder/build-starfish-completed"
declare MIRROR_PASS="shareuser@palm2013"
declare SERVER_NAME="jupiter.lge.net"
declare SERVER_USER # Your username at server
declare SERVER_PASS # Your password at server

# -----------------------------------------------------------------------------
# Internal variables
# -----------------------------------------------------------------------------

declare TASK="image"
declare  VPN="1"
declare CONF=""
declare BAKE="1"
declare COPY=""

# -----------------------------------------------------------------------------
# Check current error code
# -----------------------------------------------------------------------------

check()
{
    local code=$?
    if [[ $code -ne "0" ]]
    then
      cd $DIR
      echo "[[[ ERROR ]]]"
      exit $code
    fi
}

# -----------------------------------------------------------------------------
# Terminate and exit
# -----------------------------------------------------------------------------

terminate()
{
    local code=$?
    cd $DIR
    echo "[[[ EXIT! ]]]"
    exit $code
}

# -----------------------------------------------------------------------------
# Print section title
# -----------------------------------------------------------------------------

title()
{
    echo
    echo "[[[[[[|]]]]]] ******************************************************"
    echo "[[[[[[|]]]]]] *** ${1}"
    echo "[[[[[[|]]]]]] ******************************************************"
}

# -----------------------------------------------------------------------------
# Print section title
# -----------------------------------------------------------------------------

print()
{
    echo "[[[[[===]]]]] $1 $2 $3 $4 $5 $6 $7 $8 $9"
}

# -----------------------------------------------------------------------------
# Print section title
# -----------------------------------------------------------------------------

print_usage()
{
    cat << EOF

    Usage: ./build.bash [COMMAND] OPTIONS
EOF
    kill -SIGINT $$
}

# -----------------------------------------------------------------------------
# Read configuration
# -----------------------------------------------------------------------------

do_start()
{
    title "Start"

    # Get local settings from build.cfg
    if [ -f ./build.conf ]; then
        print "Reading build.conf"
        source ./build.conf
        check
    fi

    print
    print "Location: ${DIR}"
    print "     VPN: ${VPN_USER} at ${VPN_SITE}"
    print "  Mirror: ${MIRROR_PATH}"
    print "  Server: ${SERVER_USER} at ${SERVER_NAME}"
    print "    Task: ${TASK}"
    cd ${DIR}
    check
}

# -----------------------------------------------------------------------------
# Mount shared mirror to get access to downloads and sstate-cache
# -----------------------------------------------------------------------------

do_mount()
{(
    title "Mounting shared downloads"

    local mounted=`mount | grep ${MIRROR_PATH}`
    if [ -z "${mounted}" ]; then
        local dir=${DIR}/build-mirrors
        mkdir -p ${dir}
        check
        print "Mounting: ${MIRROR_PATH}"
        print "to ${dir}"
        echo ${MIRROR_PASS} | sshfs ${MIRROR_PATH} ${dir} -o workaround=rename -o password_stdin
        check
    else
        print "Already mounted:"
        print "${mounted}"
    fi

); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Connect VPN
# -----------------------------------------------------------------------------

do_vpn()
{(
    if [ ! "${VPN}" ]; then
        title "VPN: SKIP"
        return
    fi

    title "Connecting VPN"
    local pid=${DIR}/openconnect-pid
    if [ ! -f ${pid} ]; then
        print "openconnect ${VPN_SITE} --user=\"${VPN_USER}\" --background --pid-file=${pid}"
        print "----------------------------------------------------------"
        if [ ${VPN_PASS} ]; then
            echo ${VPN_PASS} | sudo openconnect ${VPN_SITE} --user="${VPN_USER}" --background --pid-file=${pid} --script /etc/vpnc/vpnc-script --passwd-on-stdin
        else
            sudo openconnect ${VPN_SITE} --user="${VPN_USER}" --background --pid-file=${pid} --script /etc/vpnc/vpnc-script
        fi
    else
        print "Already connected:"
        print "${pid}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Clone build-starfish.git
# -----------------------------------------------------------------------------

do_gitconfig()
{(
    title "Patch ~/.gitconfig"
    local mark="build-starfish"
    local subst=`git config --global --list | grep ${mark}`
    if [ -z "${subst}" ]; then
        print "Adding mirrors to global ~/.gitconfig"
        cat >> ~/.gitconfig << EOF

# downloads:
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/downloads/g2g.palm.com..luna-sysmgr"]
    insteadOf = "ssh://g2g.palm.com/luna-sysmgr"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/downloads/gpro.palm.com.starfish.GF-Libs"]
    insteadOf = "ssh://gpro.palm.com/starfish/GF-Libs"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/downloads/gpro.palm.com.starfish.tv-binaries-goldfinger"]
    insteadOf = "ssh://gpro.palm.com/starfish/tv-binaries-goldfinger"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/downloads/gpro.palm.com.starfish.WebKit"]
    insteadOf = "ssh://gpro.palm.com/starfish/WebKit"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/downloads/gpro.palm.com.webos-pro.demo-apps"]
    insteadOf = "ssh://gpro.palm.com/webos-pro/demo-apps"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/tvbinaries/64.28.148.103.linux-3.4-lg115x"]
    insteadOf = "git://64.28.148.103/linux-3.4-lg115x"
# metalayers & build-starfish:
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/build-starfish.git"]
    insteadOf = "ssh://gpro.palm.com/starfish/build-starfish.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/bitbake.git"]
    insteadOf = "git://github.com/openembedded/bitbake.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/GF_ToolChain.git"]
    insteadOf = "ssh://gpro.palm.com/starfish/GF_ToolChain.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/meta-goldfinger.git"]
    insteadOf = "ssh://gpro.palm.com/starfish/meta-goldfinger.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/meta-oe.git"]
    insteadOf = "git://github.com/openembedded/meta-oe.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/meta-qemux86-starfish.git"]
    insteadOf = "ssh://gpro.palm.com/starfish/meta-qemux86-starfish.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/meta-qt5.git"]
    insteadOf = "ssh://gpro.palm.com/webos-pro/meta-qt5.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/meta-starfish.git"]
    insteadOf = "ssh://gpro.palm.com/starfish/meta-starfish.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/meta-webos-backports.git"]
    insteadOf = "ssh://g2g.palm.com/meta-webos-backports.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/meta-webos.git"]
    insteadOf = "git://github.com/openwebos/meta-webos.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/meta-webos-pro.git"]
    insteadOf = "ssh://gpro.palm.com/webos-pro/meta-webos-pro.git"
[url "ssh://starfish@172.26.123.186/home/starfish/starfish/metalayers/oe-core.git"]
    insteadOf = "git://github.com/openembedded/oe-core.git"
EOF
        check
    else
        print "Already patched: ~/.gitconfig"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Clone build-starfish.git
# -----------------------------------------------------------------------------

do_clone()
{(
    local dir

    title "Clone build-starfish"
    dir=${DIR}/build-starfish
    if [ ! -d ${dir} ]; then
        print "git clone ssh://gpro.palm.com/starfish/build-starfish.git"
        echo
        git clone ssh://gpro.palm.com/starfish/build-starfish.git
        check
    else
        print "Already cloned:"
        print "${dir}"
    fi

    title "Clone WebKit"
    dir=${DIR}/WebKit
    if [ ! -d ${dir} ]; then
        print "git clone ssh://gpro.palm.com/starfish/WebKit"
        echo
        git clone ssh://gpro.palm.com/starfish/WebKit
        check
    else
        print "Already cloned:"
        print "${dir}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Clone build-starfish.git
# -----------------------------------------------------------------------------

do_conf()
{(
    title "Create local configuration"
    local file=${DIR}/build-starfish/webos-local.conf

    if [ ! -f ${file} ]; then
        print "Creating:"
        print "${file}"
        echo 'S_pn-webkit-starfish = "'`echo ${DIR}`'/WebKit"' > ${file}
        echo 'PR_pn-webkit-starfish = "d0"' >> ${file}
        echo 'SRC_URI_pn-webkit-starfish = "file:///dev/null"' >> ${file}
    else
        print "Already created:"
        print "${file}"
    fi

    cd ${DIR}/WebKit
    local mirror="ssh://starfish@172.26.123.186/home/starfish/starfish/downloads/gpro.palm.com.starfish.WebKit"
    local origin="ssh://gpro.palm.com/starfish/WebKit"
    local remote=`git remote -v | grep ${origin}`
    if [ -z "${remote}" ]; then
        print "Fixing local WebKit .git/config:"
        print "git remote set-url origin ${mirror}"
        git remote set-url origin ${mirror}
        check
        print "git config --local --add url.${origin}.insteadOf ${mirror}"
        git config --local --add url.${origin}.insteadOf ${mirror}
        #git config --local --add url.${origin}.pushInsteadOf ${mirror}
        check
    else
        print "Local WebKit .git/config is already fixed:"
    fi
    print "git remote -v"
    echo
    git remote -v
    cd ${DIR}
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Run mfc to configure starfish build
# -----------------------------------------------------------------------------

do_configure()
{(
    title "Configuring: mfc"
    local buildir=${DIR}/build-starfish/BUILD-goldfinger
    if [ ! -d ${buildir} ]; then
        cd ${DIR}/build-starfish
        print "Running mfc..."
        ./mcf -p 0 -b 0 --premirror=file:///${DIR}/build-mirrors/downloads --sstatemirror=file:///${DIR}/build-mirrors/sstate-cache goldfinger
    else
        print "Already configured:"
        print "${buildir}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Clone build-starfish.git
# -----------------------------------------------------------------------------

do_toolchain()
{(
    title "Toolchain"
    local dir=${DIR}/build-starfish/GF_ToolChain/H13
    local toolchaindir="arm-taskone-lg115x-linux-gnueabi"
    local toolchainfile="arm-taskone-linux-gnueabi.tar.bz2"
    if [ ! -d ${dir}/${toolchaindir} ]; then
        print "Unpacking toolchain for H13:"
        cd ${dir}
        check
        print "tar xf ${toolchainfile}"
        tar xf ${toolchainfile}
        check
    else
        print "Toolchain is unpacked"
        print "${dir}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Run bitbake with specified target
# -----------------------------------------------------------------------------

do_bake()
{(
    if [ ! "${BAKE}" ]; then
        title "Bitbake: SKIP"
        return
    fi

    title "Bitbake"
    print "Source bitbake.rc"
    cd ${DIR}/build-starfish/BUILD-goldfinger
    source bitbake.rc

    case "${TASK}" in
        webkit)
            if [ "${CONF}" ]; then
                print "Configuring WebKit:"
                print "bitbake webkit-starfish -C configure"
                echo && echo
                bitbake webkit-starfish -C configure
            else
                print "Compiling WebKit:"
                print "bitbake webkit-starfish -C compile"
                echo && echo
                bitbake webkit-starfish -C compile
            fi
        ;;

        image)
            print "Bitbake starfish-image"
            echo
            bitbake starfish-image
        ;;

        *)
            print "ERROR: unspecified task"
            terminate
        ;;
    esac
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Copy image or libs
# -----------------------------------------------------------------------------

do_copy()
{(
    if [ ! "${COPY}" ]; then
        title "Copy: SKIP"
        return
    fi

    title "Copy"
    local buildir=${DIR}/build-starfish/BUILD-goldfinger

    case "${TASK}" in
        webkit)
            print "Copying WebKit..."
            webkitdir=${buildir}/work/armv7a-vfp-neon-starfish-linux-gnueabi/webkit-starfish-*/packages-split/webkit-starfish/usr
            destination=${SERVER_USER}@${SERVER_NAME}:/var/webos-in/users/${SERVER_USER}/starfish/
            scp -r ${webkitdir} ${destination}
        ;;

        image)
            print "Copying starfish-image..."
            image=${buildir}/deploy/images/starfish-image-goldfinger.tar.gz 
            destination=${SERVER_USER}@${SERVER_NAME}:/home/${SERVER_USER}/starfish/
            scp ${image} ${destination}
        ;;

        *)
            print "ERROR: unspecified task"
            terminate
        ;;
    esac
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Target board preparation
# -----------------------------------------------------------------------------

do_board()
{(
    title "Target board preparation"
    local buildir=${DIR}/build-starfish/BUILD-goldfinger

    cat >> .profile << EOF
echo
echo Welcome to webOS: $HOSTNAME
echo
alias ls='ls --color'
alias ll='ls -la --color'
alias l='ls'
EOF

    cat >> isis2.bash << EOF
#!/bin/bash

source /etc/init.d/env.sh
export XDG_RUNTIME_DIR="/var/run/xdg" 
echo "nameserver 8.8.8.8" > /etc/resolv.conf
/usr/bin/isis2 -i com.palm.isis2 $@
EOF

    destination=${SERVER_USER}@${SERVER_NAME}:/var/webos-in/users/${SERVER_USER}/starfish/home/root/
    scp .profile ${destination}
    check
    scp isis2.bash ${destination}
    check
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Parse command line options
# -----------------------------------------------------------------------------

parse_arguments()
{
    # local variables
    local arg option

    # iterate through command line arguments
    until [ $# -eq 0 ]; do
        # get an option
        option=$1

        # get an argument for the option if needed
        case "${option}" in
            -*=*) arg=`echo "${option}" | sed 's/[-_a-zA-Z0-9]*=//'` ;;
            *) arg= ;;
        esac

        # parse the option
        case "${option}" in
            --without-vpn | novpn | nv)
                VPN=""
            ;;

            --image | image | all)
                TASK="image"
            ;;

            --webkit | webkit | wk)
                TASK="webkit"
            ;;

            --configure | configure | conf | cfg | cf)
                CONF="1"
            ;;

            --without-bitbake | nobb | nbb | nb)
                BAKE=""
            ;;

            --copy | copy | cp)
                COPY="1"
            ;;

            --help | -h) print_usage ;;

            *)
                echo "Unsupported argument: ${option}"
                print_usage
            ;;
        esac

        # shift to the next option
        shift
    done
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

do_main()
{
    do_start
    do_mount
    do_vpn
    do_gitconfig
    do_clone
    do_conf
    do_configure
    do_toolchain
    do_bake
    do_copy
    do_board
}

parse_arguments "$@"
do_main
title "DONE"
