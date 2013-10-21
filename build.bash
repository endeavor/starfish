#!/bin/bash

declare DIR=$PWD

# Define the following variables in build.conf file
declare VPN_SITE="vpn10.palm.com"
declare VPN_USER # Your VPN account login
declare VPN_PASS # Your VPN account password
declare MIRROR_PATH
declare MIRROR_DIR="build-mirrors"
declare MIRROR_USER # User name for cache server
declare MIRROR_PASS # Password for cache server
declare SERVER_NAME # Server name or IP
declare SERVER_USER # Your username at server
declare SERVER_PASS # Your password at server
declare NUMBER_OF_THREADS=8 # Put your number of threads e.g. 0

# -----------------------------------------------------------------------------
# build.conf samples
# -----------------------------------------------------------------------------

### LGERP:
#MIRROR_PATH="shareuser@172.26.123.186:/home/nightbuilder/build-starfish-completed"
#MIRROR_PATH="//ushquc001.palm.com/official_26/starfish_rsync"
#MIRROR_USER="shareuser"
#MIRROR_PASS="shareuser@palm2013"
#SERVER_NAME="jupiter.lge.net"

### LGSVL:
#MIRROR_PATH="//ushquc001.palm.com/official_26/starfish_rsync"
#MIRROR_DIR="../../build-starfish"
#MIRROR_USER="John Johnson"
#MIRROR_PASS="mulipassport"

### LGSVL (shared cache):
#MIRROR_PATH="//ushquc001.palm.com/official_26"
#MIRROR_DIR="../../../build-mirrors/starfish_rsync"

# -----------------------------------------------------------------------------
# Internal variables
# -----------------------------------------------------------------------------

declare TASK="image"
declare  VPN=""
declare CONF=""
declare BAKE="1"
declare COPY=""
declare TIME=0
declare TARGET="goldfinger"

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
    local times=`date +%T`
    echo
    echo "[[[[[[|]]]]]] ******************************************************"
    echo "[ ${times}  ] *** ${1}"
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

printUsage()
{
    cat << EOF

    Usage: ./build.bash [COMMAND] OPTIONS

    --with-vpn | vpn                            - Esteblish VPN connection
    --target=goldfinger | goldfinger | h13      - H/W target H13 "Goldfinger" (default)
    --target=m14tv | m14tv | m14                - H/W target M14 "m14tv"
    --image | image | all                       - build webOS image (default)
    --flash | flash                             - build flash image "epk"
    --devel | devel | dev                       - build development tools
    --webkit | webkit | wk                      - build WebKit
    --luna-surface-manager | lsm                - build Luna Surfase Manager (LSM)
    --webappmanager2 | wam2 | wam               - build Web Application Manager (WAM2)
    --valgrind | valgrind | vg                  - build Valgrind
    --configure | configure | conf | cfg | cf   - do configure before compilation
    --without-bitbake | nobb | nbb | nb         - skip build (bitbake)
    --copy | copy | cp                          - copy output to server
    --help | -h                                 - print this help
EOF
    kill -SIGINT $$
}

# -----------------------------------------------------------------------------
# Read configuration
# -----------------------------------------------------------------------------

doStart()
{
    title "Start (`date +%d.%m.%Y`)"
    TIME=$((`date +%s`))

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
    print "  Target: ${TARGET}"
    cd ${DIR}
    check
}

# -----------------------------------------------------------------------------
# Finish
# -----------------------------------------------------------------------------

doFinish()
{
    local delta=$((`date +%s` - $TIME))
    if (( delta > 60)); then
        delta=$(($delta/60))
        if ((  delta > 60 )); then
            hours=$(($delta/60))
            minutes=$(($delta-$hours*60))
            title "DONE in $hours hours $minutes min"
        else
            title "DONE in $delta min"
        fi
    else
        title "DONE"
    fi
}

# -----------------------------------------------------------------------------
# Mount shared mirror to get access to downloads and sstate-cache
# -----------------------------------------------------------------------------

mountSharedDownloads()
{(
    if [ ! "${MIRROR_PATH}" ]; then
        title "Mounting shared downloads: SKIP (No MIRROR_PATH)"
        return
    fi

    title "Mounting shared downloads"

    local mounted=`mount | grep ${MIRROR_PATH}`
    if [ -z "${mounted}" ]; then
        local dir=${DIR}/${MIRROR_DIR}
        mkdir -p ${dir}
        check
        print "Mounting: ${MIRROR_PATH}"
        print "to ${dir}"
#        echo ${MIRROR_PASS} | sshfs ${MIRROR_PATH} ${dir} -o workaround=rename -o password_stdin
        sudo smbmount --verbose -o username="${MIRROR_USER}" ${MIRROR_PATH} ${dir}
#print "WARNING: mounting is disabled!!!"
        check
    else
        print "Already mounted:"
        print "${mounted}"
    fi

); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Connect VPN
# -----------------------------------------------------------------------------

connectVpn()
{(
    if [ ! "${VPN}" ]; then
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

patchGitconfig()
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

cloneStarfish()
{(
    title "Clone build-starfish"
    local dir=${DIR}/build-starfish
    if [ ! -d ${dir} ]; then
        print "git clone ssh://gpro.palm.com/starfish/build-starfish.git"
        echo
        git clone ssh://gpro.palm.com/starfish/build-starfish.git
        check
    else
        print "Already cloned:"
        print "${dir}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Clone build-starfish.git
# -----------------------------------------------------------------------------

downloadStarfishDownloads()
{(
    title "Download starfish-downloads.tar.bz2"
    local dir=${DIR}/build-starfish/downloads
    local location="http://172.26.123.22/ftp"
    local downloads="starfish-downloads.tar.bz2"
    if [ ! -d ${dir} ]; then
        cd ${DIR}/build-starfish/
        print "wget ${location}/${downloads}"
        echo
        wget ${location}/${downloads}
        check
        print "tar -xjf ${downloads}"
        echo
        tar -xjf ${downloads}
        check
        print "rm ${downloads}"
        echo
        rm ${downloads}
        check
        cd -
    else
        print "Already have downloads:"
        print "${dir}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Clone WebKit
# -----------------------------------------------------------------------------

cloneWebKit()
{(
    title "Clone WebKit"
    local dir=${DIR}/WebKit
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
# Copy WebKit from downloads and checkout
# -----------------------------------------------------------------------------

copyWebKit()
{(
    if [ ! "${MIRROR_PATH}" ]; then
        title "Cannot copy WebKit (No MIRROR_PATH)"
        cloneWebKit
        return
    fi

    title "Copy WebKit"
    local dir=${DIR}/WebKit
    if [ ! -d ${dir} ]; then
        print "Create WebKit dir and copy bare repo from mirror downloads"
        mkdir $dir
        check
        cd $dir
        check
        cp -RP ${DIR}/${MIRROR_DIR}/downloads/git2/gpro.palm.com.starfish.WebKit .git
        check
        print "Set bare = false and checkout master"
        echo
#        sed -i "s/bare.=.true/bare = false/g" .git/config
        cat > .git/config << EOF
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
[remote "origin"]
	fetch = +refs/heads/*:refs/remotes/origin/*
	url = ssh://gpro.palm.com/starfish/WebKit
[branch "master"]
	remote = origin
	merge = refs/heads/master
EOF
        check
        git checkout master
        check
        print "Update repo: git pull"
        echo
        git pull
        check
    else
        print "Already copied:"
        print "${dir}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Clone build-starfish.git
# -----------------------------------------------------------------------------

createLocalConfiguration()
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
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Fixing git origin for WebKit
# -----------------------------------------------------------------------------

fixWebKitOrigin()
{(
    title "Fix WebKit origin"
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
    echo

    if [ ! -f ".git/hooks/commit-msg" ]; then
        print "Copying Gerrit hook:"
        print "scp -p gpro.palm.com:hooks/commit-msg .git/hooks/"
        scp -p gpro.palm.com:hooks/commit-msg .git/hooks/
        check
    else
        print "Gerrit hook exists: .git/hooks/commit-msg"
    fi

    cd ${DIR}
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Run mfc to configure starfish build
# -----------------------------------------------------------------------------

runMfc()
{(
    title "Configuring: mfc"
    local buildir=${DIR}/build-starfish/BUILD-$TARGET
    if [ ! -d ${buildir} ]; then
        cd ${DIR}/build-starfish
        print "Running mfc..."
        ./mcf -p $NUMBER_OF_THREADS -b $NUMBER_OF_THREADS --premirror=file://${DIR}/${MIRROR_DIR}/downloads --sstatemirror=file://${DIR}/${MIRROR_DIR}/sstate-cache $TARGET
   else
        print "Already configured:"
        print "${buildir}"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Clone build-starfish.git
# -----------------------------------------------------------------------------

unpackToolchain()
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

runBitbake()
{(
    if [ ! "${BAKE}" ]; then
        title "Bitbake: SKIP"
        return
    fi

    title "Bitbake"
    print "Source bitbake.rc"
    cd ${DIR}/build-starfish/BUILD-$TARGET
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

        valgrind)
            print "Compiling Valgrind:"
            print "bitbake valgrind"
            echo && echo
            bitbake valgrind
        ;;

        lsm)
            print "Compiling Luna Surface Manager:"
            print "bitbake starfish-luna-surface-manager"
            echo && echo
            bitbake starfish-luna-surface-manager -C patch
        ;;

        wam2)
            print "Compiling WAM2:"
            print "bitbake webappmanager2"
            echo && echo
            bitbake webappmanager2 -C patch
        ;;

        image)
            print "Bitbake starfish-image"
            echo
            bitbake starfish-image
        ;;

        flash)
            print "Bitbake starfish-flash"
            echo
            bitbake starfish-flash
        ;;

        devel)
            print "Bitbake starfish-image-devel"
            echo
            bitbake starfish-image-devel
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

copyFilesToServer()
{
    if [ ! "${COPY}" ]; then
        title "Copy: SKIP"
        return
    fi

    title "Copy"

    if [ ! "${SERVER_USER}" ]; then
        print "ERROR: SERVER_USER is not set"
        terminate
    fi

    local buildir=${DIR}/build-starfish/BUILD-$TARGET

    case "${TASK}" in
        webkit)
            print "Copying WebKit..."
            webkitdir=${buildir}/work/armv7a-vfp-neon-starfish-linux-gnueabi/webkit-starfish-*/packages-split/webkit-starfish/usr
            destination=${SERVER_USER}@${SERVER_NAME}:/var/webos-in/users/${SERVER_USER}/starfish/
            scp -r ${webkitdir} ${destination}
        ;;

        image)
            print "Copying starfish-image..."
            image=${buildir}/deploy/images/starfish-image-$TARGET.tar.gz 
            destination=${SERVER_USER}@${SERVER_NAME}:/home/${SERVER_USER}/starfish/
            scp ${image} ${destination}
        ;;

        *)
            print "ERROR: unspecified task"
            terminate
        ;;
    esac
}

# -----------------------------------------------------------------------------
# Target board preparation
# -----------------------------------------------------------------------------

prepareTargetBoard()
{(
    title "Target board preparation"
    local buildir=${DIR}/build-starfish/BUILD-$TARGET

    cat >> .profile << EOF
echo
echo Welcome to webOS: `hostname`
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
# Building Qt5 for PC/Linux
# -----------------------------------------------------------------------------

buildQt5()
{(
    title "Building Qt5 for PC/Linux"

    if [ ! -f "qtsdk/qtbase/bin/qmlmin" ]; then
        ./build-qt5.bash -D
        check
    else
        print "Qt5 is already built"
        print "qtsdk/qtbase"
    fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Building WebKit for PC/Linux
# -----------------------------------------------------------------------------

buildWebKit()
{(
    title "Building WebKit for PC/Linux"

    #if [ ! -d "WebKit/WebKitBuild/desktop" ]; then
        print "./build-webkit.bash > build-webkit.log"
        echo
        ./build-webkit.bash > build-webkit.log
        check
    #else
    #    print "WebKit is already built:"
    #    print "WebKit/WebKitBuild/desktop"
    #fi
); [ $? -eq 0 ] || terminate; }

# -----------------------------------------------------------------------------
# Parse command line options
# -----------------------------------------------------------------------------

parseArguments()
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
            --with-vpn | vpn)
                VPN="1"
            ;;

            --image | image | all)
                TASK="image"
            ;;

            --flash | flash)
                TASK="flash"
            ;;

            --devel | devel | dev)
                TASK="devel"
            ;;

            --webkit | webkit | wk)
                TASK="webkit"
            ;;

            --target=goldfinger | goldfinger | h13)
                TARGET="goldfinger"
            ;;

            --target=m14tv | m14tv | m14)
                TARGET="m14tv"
            ;;

            --luna-surface-manager | lsm)
                TASK="lsm"
            ;;

            --webappmanager2 | wam2 | wam)
                TASK="wam2"
            ;;

            --valgrind | valgrind | vg)
                TASK="valgrind"
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

            --linux | linux | pc)
                TASK="pc"
                BAKE=""
            ;;

            --help | -h) printUsage ;;

            *)
                echo "Unsupported argument: ${option}"
                printUsage
            ;;
        esac

        # shift to the next option
        shift
    done
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

runMain()
{
    doStart
    case "${TASK}" in
        pc)
            mountSharedDownloads
            copyWebKit
            buildQt5
            buildWebKit
        ;;

        *)
            mountSharedDownloads
            connectVpn
            #patchGitconfig
            cloneStarfish
            #cloneWebKit
            #fixWebKitOrigin
            copyWebKit
            createLocalConfiguration
            runMfc
            unpackToolchain
            runBitbake
            #copyFilesToServer
            #prepareTargetBoard
        ;;
    esac
    doFinish
}

parseArguments "$@"
runMain
