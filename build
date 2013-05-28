#!/bin/bash

DIR=${HOME}/Work/starfish
USERNAME="John Smith"
USERPASS=""
MIRROR=""
MIPASS=""
SERVER="jupiter.lge.net"
SUSER="john"
declare TASK

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
    echo "?????????????????? $$"
    kill -SIGINT $$
}

# -----------------------------------------------------------------------------
#
# -----------------------------------------------------------------------------

do_start()
{(
    title "Start"
    print "Location: "$DIR
    print "    Task: "$TASK
    cd ${DIR}
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
#
# -----------------------------------------------------------------------------

do_clone()
{(
    title "Clone build-starfish"
    local dir=${DIR}/build-starfish
    if [ ! -d ${dir} ]; then
        print "git clone ssh://gpro.palm.com/starfish/build-starfish.git"
        git clone ssh://gpro.palm.com/starfish/build-starfish.git
        check
        print "Unpack toolchain for H13:"
        print "tar xf arm-taskone-linux-gnueabi.tar.bz2"
        cd ${dir}/GF_ToolChain/H13/
        check
        tar xf arm-taskone-linux-gnueabi.tar.bz2
        check
    else
        print "Already cloned:"
        print "${dir}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
#
# -----------------------------------------------------------------------------

do_mount()
{(
    title "Mounting shared downloads"
    local dir=${DIR}/build-mirrors
    mkdir -p ${dir}
    check

    local mounted=`mount | grep ${MIRROR}`
    if [ -z ${mounted} ]; then
        print "Mounting: ${MIRROR}"
        print "to ${dir}"
        echo ${MIPASS} | sshfs ${MIRROR} ${dir} -o workaround=rename -o password_stdin
        check
    else
        print "Already mounted:"
        print "${mounted}"
    fi

); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
#
# -----------------------------------------------------------------------------

do_vpn()
{(
    title "Connecting VPN"
    local pid=${DIR}/openconnect-pid
    if [ ! -f ${pid} ]; then
        print "Openconnect..."
        print "----------------------------------------------------------"
        if [ ${USERPASS} ]; then
            echo ${USERPASS} | sudo openconnect vpn10.palm.com --user="${USERNAME}" --background --pid-file=${pid} --script /etc/vpnc/vpnc-script --passwd-on-stdin
        else
            sudo openconnect vpn10.palm.com --user="${USERNAME}" --background --pid-file=${pid} --script /etc/vpnc/vpnc-script
        fi
    else
        print "Already connected:"
        print "${pid}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
#
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
#
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
#
# -----------------------------------------------------------------------------

do_copy()
{(
    title "Copy"
    local buildir=${DIR}/build-starfish/BUILD-goldfinger

    case "${TASK}" in
        webkit)
            print "Copying WebKit..."
            webkitdir=${buildir}/work/armv7a-vfp-neon-starfish-linux-gnueabi/webkit-starfish-0.5.1-27-r17/packages-split/webkit-starfish
            destination=${SUSER}@${SERVER}:/share/webos/users/${SUSER}/starfish/
            scp -r ${webkitdir} ${destination}
        ;;

        image)
            print "Copying starfish-image..."
            image=${buildir}/deploy/images/starfish-image-goldfinger.tar.gz 
            destination=${SUSER}@${SERVER}:/home/${SUSER}/starfish/
            scp ${image} ${destination}
        ;;

        *)
            print "ERROR: unspecified task"
            terminate
        ;;
    esac
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
#
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
                if [ $? -ne 0 ]; then
                    print_usage
                else
                    TASK="image"
                fi
            ;;
        esac

        # shift to the next option
        shift
    done
}

# -----------------------------------------------------------------------------
#
# -----------------------------------------------------------------------------

do_main()
{
    do_start
    do_mount
    do_vpn
    do_clone
return
    do_configure
    do_bake
    do_copy
}

parse_arguments "$@"
do_main
title "DONE"