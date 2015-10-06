#!/bin/sh

## Version 0.1.0
##
## Usage
## ./make_openbazaar.sh [url]
##
## The script make_openbazaar.sh allows you to clone, setup, and build a version of OpenBazaar
## The [url] handle is optional and allows you to pick what repository you wish to clone
## If you use 'ssh' in the place of the optional [url] parameter, it will clone via ssh instead of http
##
## Optionally, you can also pass in a specific branch to build or clone, by making url contain a branch specifier
## ./make_openbazaar.sh '-b release/0.3.4 https://github.com/OpenBazaar/OpenBazaar.git'
##

OS="${1}"

# Check if user specified repository to pull code from
clone_repo="True"
clone_url_server="https://github.com/OpenBazaar/OpenBazaar-Server.git"
clone_url_client="https://github.com/OpenBazaar/OpenBazaar-Client.git"

execsudo() {
    case ${OSTYPE} in msys*)
       echo $OSTYPE
       $1
       ;;
    *)
       sudo $1
       ;;
    esac
}

clone_command() {
    if git clone ${clone_url_server} ${dir}; then
        echo "Cloned OpenBazaar Server successfully"
    else
        echo "OpenBazaar encountered an error and could not be cloned"
        exit 2
    fi
}

clone_command_client() {
    if git clone ${clone_url_client} ${dir}; then
        echo "Cloned OpenBazaar Client successfully"
    else
        echo "OpenBazaar encountered an error and could not be cloned"
        exit 2
    fi
}

if [ -e ".git/config" ]; then
    dat=`cat .git/config | grep 'url'`
    case ${dat} in *OpenBazaar-6*)
        echo "You appear to be inside of a OpenBazaar repository already, not cloning"
        clone_repo="False"
        ;;
    *)
        try="True"
        tries=0
        while [ "${try}" = "True" ]; do
            read -p "Looks like we are inside a git repository, do you wish to clone inside it? (yes/no) [no] " rd_cln
            if [ -z "${rd_cln}" ]; then
                rd_cln='no'
            fi
            tries=$((${tries}+1))
            if [ "${rd_cln}" = "yes" ] || [ "${rd_cln}" = "no" ]; then
                try="False"
            elif [ "$tries" -ge "3" ]; then
                echo "No valid input, exiting"
                exit 1
            else
                echo "Not a valid answer, please try again"
            fi
        done
        if [ "$rd_cln" = "no" ]; then
            echo "You appear to be inside of a OpenBazaar repository already, not cloning"
            clone_repo="False"
        else
            echo "You've chosen to clone inside the current directory"
        fi
        ;;
    esac
fi
if [ "${clone_repo}" = "True" ]; then
    echo "Cloning OpenBazaar-Server"
    read -p "Where do you wish to clone OpenBazaar-Server to? [OpenBazaar-Server] " dir
    if [ -z "${dir}" ]; then
        dir='OpenBazaar-Server'
    elif [ "${dir}" = "/" ]; then
        dir='OpenBazaar-Server'
    fi
    if [ ! -d "${dir}" ]; then
        clone_command
    else
        try="True"
        tries=0
        while [ "$try" = "True" ]; do
            read -p "Directory ${dir} already exists, do you wish to delete it and redownload? (yes/no) [no] " rd_ans
            if [ -z "${rd_ans}" ]; then
                rd_ans='no'
            fi
            tries=$((${tries}+1))
            if [ "${rd_ans}" = "yes" ] || [ "${rd_ans}" = "no" ]; then
                try="False"
            elif [ "$tries" -ge "3" ]; then
                echo "No valid input, exiting"
                exit 3
            else
                echo "Not a valid answer, please try again"
            fi
        done
        if [ "${rd_ans}" = "yes" ]; then
            echo "Removing old directory"
            if [ "${dir}" != "." ] || [ "${dir}" != "$PWD" ]; then
                echo "Cleaning up from inside the destination directory"
                sudo rm -rf ${dir}/*
            else
                echo "Cleaning up from outside the destination directory"
                sudo rm -rf ${dir}
            fi
            clone_command
        else
            echo "Directory already exists and you've chosen not to clone again"
        fi
    fi

    echo "Cloning OpenBazaar-Client"
    read -p "Where do you wish to clone OpenBazaar-Client to? [OpenBazaar-Client] " dir
    if [ -z "${dir}" ]; then
        dir='OpenBazaar-Client'
    elif [ "${dir}" = "/" ]; then
        dir='OpenBazaar-Client'
    fi
    if [ ! -d "${dir}" ]; then
        clone_command_client
    else
        try="True"
        tries=0
        while [ "$try" = "True" ]; do
            read -p "Directory ${dir} already exists, do you wish to delete it and redownload? (yes/no) [no] " rd_ans
            if [ -z "${rd_ans}" ]; then
                rd_ans='no'
            fi
            tries=$((${tries}+1))
            if [ "${rd_ans}" = "yes" ] || [ "${rd_ans}" = "no" ]; then
                try="False"
            elif [ "$tries" -ge "3" ]; then
                echo "No valid input, exiting"
                exit 3
            else
                echo "Not a valid answer, please try again"
            fi
        done
        if [ "${rd_ans}" = "yes" ]; then
            echo "Removing old directory"
            if [ "${dir}" != "." ] || [ "${dir}" != "$PWD" ]; then
                echo "Cleaning up from inside the destination directory"
                sudo rm -rf ${dir}/*
            else
                echo "Cleaning up from outside the destination directory"
                sudo rm -rf ${dir}
            fi
            clone_command
        else
            echo "Directory already exists and you've chosen not to clone again"
        fi
    fi
fi
try="True"
tries=0
while [ "${try}" = "True" ]; do
    read -p "Do you wish to install the required dependencies for OpenBazaar and setup for building? (yes/no) [yes] " rd_dep
    if [ -z "${rd_dep}" ]; then
        rd_dep="yes"
    fi
    tries=$((${tries}+1))
    if [ "${rd_dep}" = "yes" ] || [ "${rd_dep}" = "no" ]; then
        try="False"
    elif [ "$tries" -ge "3" ]; then
        echo "No valid input, exiting"
        exit 3
    else
        echo "Not a valid answer, please try again"
    fi
done

if [ -z "${dir}" ]; then
    dir="."
fi
cd ${dir}
echo "Switched to ${PWD}"

if [ "${rd_dep}" = "yes" ]; then
    echo "Installing global dependencies"
    if execsudo "npm install -g grunt-cli"; then
        echo "Global dependencies installed successfully!"
    else
        echo "Global dependencies encountered an error while installing"
        exit 4
    fi

    echo "Installing local dependencies"
    if execsudo "npm install"; then
        echo "Local dependencies installed successfully!"
    else
        echo "Local dependencies encountered an error while installing"
        exit 4
    fi

    curh=$HOME
    case ${OSTYPE} in msys*)
        ;;
        *)
        if execsudo "chown -R $USER ." && execsudo "chown -R $USER $curh/.cache"; then
            echo "Local permissions corrected successfully!"
        else
            echo "Local permissions encountered an error while correcting"
            exit 4
        fi
        ;;
    esac

    echo "Successfully setup for OpenBazaar"
fi

# Check for temp folder and create if does not exist
mkdir -p temp

# Download OS specific installer files to package
case $OS in win32*)
        export OB_OS=win32
        
        cd temp/

        if [ ! -f python-2.7.10.msi ]; then
            wget https://www.python.org/ftp/python/2.7.10/python-2.7.10.msi -O python-2.7.10.msi
        fi
        if [ ! -f node.msi ]; then
            wget https://nodejs.org/download/release/v4.1.2/node-v4.1.2-x86.msi -O node.msi
        fi
        if [ ! -f electron.zip ]; then
            wget https://github.com/atom/electron/releases/download/v0.33.1/electron-v0.33.1-win32-ia32.zip -O electron.zip && unzip electron.zip -d electron && rm electron.zip
        fi
        if [ ! -f pywin32.exe ]; then
            wget http://sourceforge.net/projects/pywin32/files/pywin32/Build%20219/pywin32-219.win32-py2.7.exe/download -O pywin32.exe
        fi
        if [ ! -f vcredist.exe ]; then
            wget http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe -O vcredist.exe
        fi

        wget https://download.libsodium.org/libsodium/releases/libsodium-1.0.3-msvc.zip -O libsodium.zip && unzip libsodium.zip -d libsodium && rm libsodium.zip
        wget http://msinttypes.googlecode.com/svn/trunk/inttypes.h -O inttypes.h
        wget http://msinttypes.googlecode.com/svn/trunk/stdint.h -O stdint.h
        wget https://github.com/pyca/pynacl/archive/v0.3.0.zip -O pynacl.zip && unzip pynacl.zip  -d pynacl && rm pynacl.zip
        wget https://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi -O VCForPython27.msi

        cd ..

        makensis windows/ob.nsi
        ;;
    win64*)
        export OB_OS=win64
        
        cd temp/

        if [ ! -f python-2.7.10.msi ]; then
            wget https://www.python.org/ftp/python/2.7.10/python-2.7.10.amd64.msi -O python-2.7.10.msi
        fi
        if [ ! -f node.msi ]; then
            wget https://nodejs.org/download/release/v4.1.2/node-v4.1.2-x64.msi -O node.msi
        fi
        if [ ! -f electron.zip ]; then
            wget https://github.com/atom/electron/releases/download/v0.33.1/electron-v0.33.1-win32-x64.zip -O electron.zip && unzip electron.zip -d electron && rm electron.zip
        fi
        if [ ! -f pywin32.exe ]; then
            wget http://sourceforge.net/projects/pywin32/files/pywin32/Build%20219/pywin32-219.win-amd64-py2.7.exe/download -O pywin32.exe
        fi
        if [ ! -f vcredist.exe ]; then
            wget http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe -O vcredist.exe
        fi
        
        wget https://download.libsodium.org/libsodium/releases/libsodium-1.0.3-msvc.zip -O libsodium.zip && unzip libsodium.zip -d libsodium && rm libsodium.zip
        wget http://msinttypes.googlecode.com/svn/trunk/inttypes.h -O inttypes.h
        wget http://msinttypes.googlecode.com/svn/trunk/stdint.h -O stdint.h
        wget https://github.com/pyca/pynacl/archive/v0.3.0.zip -O pynacl.zip && unzip pynacl.zip -d pynacl && rm pynacl.zip
        wget https://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi -O VCForPython27.msi

        cd ..

        makensis windows/ob.nsi
        ;;
    osx*)
        echo 'No installer for OSX yet.'
esac



#if grunt build; then
#    echo "OpenBazaar built successfully!"
#    echo "Run 'grunt start' from inside the repository to launch the app"
#    echo "Enjoy!"
#else
#    echo "OpenBazaar encountered an error and couldn't be built"
#    exit 5
#fi