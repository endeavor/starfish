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

declare TASK="image"

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
    local dir=${DIR}/build-mirrors
    mkdir -p ${dir}
    check

    local mounted=`mount | grep ${MIRROR_PATH}`
    if [ -z "${mounted}" ]; then
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

do_clone()
{(
    title "Clone build-starfish"
    local dir=${DIR}/build-starfish
    if [ ! -d ${dir} ]; then
        print "git clone ssh://gpro.palm.com/starfish/build-starfish.git"
        git clone ssh://gpro.palm.com/starfish/build-starfish.git
        check
    else
        print "Already cloned:"
        print "${dir}"
    fi
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
    title "Bitbake"
    print "Source bitbake.rc"
    cd ${DIR}/build-starfish/BUILD-goldfinger
    source bitbake.rc

    case "${TASK}" in
        webkit)
            print "Compiling WebKit:"
            print "bitbake webkit-starfish -C compile"
            echo && echo
            bitbake webkit-starfish -C compile
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
    title "Copy"
    local buildir=${DIR}/build-starfish/BUILD-goldfinger

    case "${TASK}" in
        webkit)
            print "Copying WebKit..."
            webkitdir=${buildir}/work/armv7a-vfp-neon-starfish-linux-gnueabi/webkit-starfish-0.5.1-27-r17/packages-split/webkit-starfish
            destination=${SERVER_USER}@${SERVER_NAME}:/share/webos/users/${SERVER_USER}/starfish/
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
            webkit | wk)
                TASK="webkit"
            ;;

            image | all)
                TASK="image"
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
    do_clone
    do_configure
    do_toolchain
    #do_bake
    #do_copy
}

parse_arguments "$@"
do_main
title "DONE"
