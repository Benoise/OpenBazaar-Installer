#!/bin/sh

## Version 0.1.0
##
## Usage
## ./make_openbazaar.sh OS
##	
## OS supported:
## win32 win64 linux osx
##


ELECTRONVER=0.36.9
NODEJSVER=5.1.1
PYTHONVER=2.7.11
UPXVER=391

OS="${1}"

# Get Version
PACKAGE_VERSION=$(cat package.json \
  | grep version \
  | head -1 \
  | awk -F: '{ print $2 }' \
  | sed 's/[",]//g' \
  | tr -d '[[:space:]]')
echo "OpenBazaar Version: $PACKAGE_VERSION"

# Check if user specified repository to pull code from
clone_url_server="https://github.com/OpenBazaar/OpenBazaar-Server.git"
clone_url_client="https://github.com/OpenBazaar/OpenBazaar-Client.git"

command_exists () {
    if ! [ -x "$(command -v $1)" ]; then
 	echo "$1 is not installed." >&2
    fi
}

clone_command() {
    if git clone ${clone_url_server} -b ${branch}; then
        echo "Cloned OpenBazaar Server successfully"
    else
        echo "OpenBazaar encountered an error and could not be cloned"
        exit 2
    fi
}

clone_command_client() {
    if git clone ${clone_url_client}; then
        echo "Cloned OpenBazaar Client successfully"
    else
        echo "OpenBazaar encountered an error and could not be cloned"
        exit 2
    fi
}

if ! [ -d OpenBazaar-Client ]; then
	echo "Cloning OpenBazaar-Client"
	clone_command_client
else
    cd OpenBazaar-Client
    git pull
    cd ..
fi

branch=master
if ! [ -d OpenBazaar-Server ]; then
    echo "Cloning OpenBazaar-Server"
    clone_command
else
    cd OpenBazaar-Server
    git pull
    cd ..
fi

if [ -z "${dir}" ]; then
    dir="."
fi
cd ${dir}
echo "Switched to ${PWD}"

if [ -d build-$OS ]; then
    rm -rf build-$OS
fi

mkdir -p temp-$OS
mkdir -p build-$OS/OpenBazaar-Server

# Clean past builds in OpenBazaar-Server
rm -rf OpenBazaar-Server/dist/*

#command_exists grunt
command_exists npm
#command_exists wine

# Notes about windows: In windows we want to compile the application for both
# 32 bit and 64 bit versions even if the host operating system is 64 bit.
# To make it possible to run either 32 bit and 64 bit versions of python
# we need to install Python 2.7 32 bit, Python 2.7 64 bit and afterwards
# we need to install latest Python 3 in either 32 or 64 bits. This is needed
# becuase starting with Python 3.3 a launcher is installed that allows us
# to run any python version that is already installed
# by calling either `py.exe -2.7-x64 ` or `py.exe -2.7-32`

# Download OS specific installer files to package
case $OS in win32*)
    export OB_OS=win32
    command_exists py
    ;;

    win64*)
        export OB_OS=win64

        command_exists python


        echo 'Building Server Binary...'
        cd OpenBazaar-Server
        pip install virtualenv
        virtualenv env
        env/scripts/activate.bat
        pip install pyinstaller==3.1
        pip install https://openbazaar.org/downloads/miniupnpc-1.9-cp27-none-win_amd64.whl
        pip install https://openbazaar.org/downloads/PyNaCl-0.3.0-cp27-none-win_amd64.whl
        pip install -r requirements.txt
        pyinstaller  -i ../windows/icon.ico ../openbazaard.win.spec --noconfirm
        cp -rf dist/openbazaard/* ../build-$OS/OpenBazaar-Server
        cp ob.cfg ../build-$OS/OpenBazaar-Server
        cd ..

        echo 'Installing Node modules'
        npm install electron-packager
        cd OpenBazaar-Client
        npm install

        echo 'Building Client Binary...'
        cd ../temp-$OS
        ../node_modules/.bin/electron-packager ../OpenBazaar-Client OpenBazaar --asar=true --protocol-name=OpenBazaar --version-string.ProductName=OpenBazaar --protocol=ob --platform=win32 --arch=x64 --icon=../windows/icon.ico --version=${ELECTRONVER} --overwrite
        cd ..

        echo 'Copying server files into application folder(s)...'
        cp -rf build-$OS/OpenBazaar-Server temp-$OS/OpenBazaar-win32-x64/resources/

        echo 'Building Installer...'

        npm install -g grunt
        npm install --save-dev grunt-electron-installer

        grunt create-windows-installer --obversion=$PACKAGE_VERSION

        echo "Do not forget to sign the release before distributing..."
        echo "signtool sign /t http://timestamp.digicert.com /a [filename]"
        ;;

    osx*)

        echo 'Building OS X binary...'

        echo 'Cleaning build directories...'
        if [ -d build-$OS ]; then
            rm -rf build-$OS/*
        fi

        if [ -d temp-$OS ]; then
            rm -rf temp-$OS/*
        fi

        echo 'Installing node.js packages for installer...'
        npm install electron-packager
        npm install electron-installer-dmg

        echo 'Installing node.js packages for OpenBazaar-Client...'
        cd OpenBazaar-Client
        npm install
        cd ..

        echo 'Creating virtualenv and building OpenBazaar-Server binary...'
        cd OpenBazaar-Server
        virtualenv env
        . env/bin/activate
        pip install --ignore-installed -r requirements.txt
        pip install --ignore-installed pyinstaller==3.1
        pip install setuptools==19.1
        env/bin/pyinstaller -F -n openbazaard -i ../osx/tent.icns --osx-bundle-identifier=com.openbazaar.openbazaard ../openbazaard.mac.spec
        echo 'Completed building OpenBazaar-Server binary...'

        echo 'Code-signing Daemon binaries...'
        codesign --force --sign "$SIGNING_IDENTITY" dist/openbazaard
        codesign --force --sign "$SIGNING_IDENTITY" ob.cfg
        cd ..

        echo 'Packaging Electron application...'
        cd temp-$OS
        ../node_modules/.bin/electron-packager ../OpenBazaar-Client OpenBazaar --app-category-type=public.app-category.business --protocol-name=OpenBazaar --protocol=ob --platform=darwin --arch=x64 --icon=../osx/tent.icns --version=${ELECTRONVER} --overwrite --app-version=$PACKAGE_VERSION
        cd ..

        echo 'Moving .app to build directory...'
        mv temp-$OS/OpenBazaar-darwin-x64/* build-$OS/
        rm -rf build-$OS/OpenBazaar-darwin-x64

        echo 'Create OpenBazaar-Server folder inside the .app...'
        mkdir build-$OS/OpenBazaar.app/Contents/Resources/OpenBazaar-Server

        cd OpenBazaar-Server
        echo 'Copy binary files to .app folder...'
        cp dist/openbazaard ../build-$OS/OpenBazaar.app/Contents/Resources/OpenBazaar-Server
        cp ob.cfg ../build-$OS/OpenBazaar.app/Contents/Resources/OpenBazaar-Server
        cd ..

        echo 'Creating DMG installer from build...'
        npm i electron-installer-dmg -g
        codesign --force --deep --sign "$SIGNING_IDENTITY" ./build-$OS/OpenBazaar.app
        electron-installer-dmg ./build-$OS/OpenBazaar.app OpenBazaar-$PACKAGE_VERSION --icon ./osx/tent.icns --out=./build-$OS --overwrite --background=./osx/finder_background.png --debug

        echo 'Codesign the DMG and zip'
        codesign --force --sign "$SIGNING_IDENTITY" ./build-$OS/OpenBazaar-$PACKAGE_VERSION.dmg
        cd build-$OS
        zip -r OpenBazaar-mac-$PACKAGE_VERSION.zip OpenBazaar.app

        ;;

    linux32*)

        echo 'Building Linux binary'
	if [ -d build-$OS ]; then
		rm -rf build-$OS
	fi

	if ! [ -d temp-$OS ]; then
		mkdir -p temp-$OS
	fi

	branch=master
	if ! [ -d OpenBazaar-Server ]; then
		echo "Cloning OpenBazaar-Server"
		clone_command
	else
        cd OpenBazaar-Server
        git pull
        cd ..
	fi

	npm install electron-packager

        echo 'Compiling node packages'
        cd OpenBazaar-Client
        npm install

	echo 'Packaging Electron application'
        cd ../temp-$OS
        ../node_modules/.bin/electron-packager ../OpenBazaar-Client openbazaar --platform=linux --arch=all --version=${ELECTRONVER} --overwrite

         cd ..
        # Set up build directories
        cp -rf OpenBazaar-Client build-$OS
        mkdir build-$OS/OpenBazaar-Server

        # Build OpenBazaar-Server Binary
        cd OpenBazaar-Server
        virtualenv2 env
        source env/bin/activate
        pip2 install -r requirements.txt
        pip2 install git+https://github.com/pyinstaller/pyinstaller.git
        env/bin/pyinstaller -F -n openbazaard openbazaard.py
        cp dist/openbazaard ../build-$OS/OpenBazaar-Server
        cp ob.cfg ../build-$OS/OpenBazaar-Server
	echo "Build done in build-$OS"
	;;
    linux64*)

        echo "Building Linux binary (x64)"

        echo "Clean/empty build-$OS"
        if [ -d build-$OS ]; then
            rm -rf build-$OS/*
        else
            mkdir build-$OS
        fi

        echo "Create clean temp-$OS folder if necessary"
        if ! [ -d temp-$OS ]; then
            mkdir -p temp-$OS
        else
            rm -rf temp-$OS/*
        fi

        echo "Pull code from GitHub"
        branch=master
        if ! [ -d OpenBazaar-Server ]; then
            echo "Cloning OpenBazaar-Server"
            clone_command
        else
            cd OpenBazaar-Server
            git pull
            cd ..
        fi

        echo "Installing npm packages for installer"
        sudo apt-get install npm python-pip python-virtualenv python-dev libffi-dev
        npm install electron-packager

        echo "Installing npm packages for the Client"
        cd OpenBazaar-Client
        npm install
        cd ..

        # Build OpenBazaar-Server Binary
        echo "Building OpenBazaar-Server binary"

        mkdir build-$OS/OpenBazaar-Server
        cd OpenBazaar-Server
        virtualenv env
        . env/bin/activate
        pip install -r requirements.txt
        pip install pyinstaller==3.1
        pyinstaller -D -F -n openbazaard ../openbazaard.linux.spec

        echo "Copy openbazaard to build folder"
        cp dist/openbazaard ../build-$OS/OpenBazaar-Server
        cp ob.cfg ../build-$OS/OpenBazaar-Server

	    echo "Packaging Electron application"
        cd ../temp-$OS
        ../node_modules/.bin/electron-packager ../OpenBazaar-Client openbazaar --platform=linux --arch=all --version=${ELECTRONVER} --overwrite --prune

        cd ..

        cp -rf build-$OS/OpenBazaar-Server temp-$OS/openbazaar-linux-x64/resources

        if [ "$(uname)" == "Darwin" ]; then
            brew install fakeroot dpkg
        elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
            sudo apt-get install fakeroot dpkg
        elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
            echo "Nothing yet"
        fi

	npm install -g electron-packager
	npm install -g grunt-cli
        npm install -g grunt-electron-installer --save-dev
        npm install -g grunt-electron-installer-debian --save-dev

        grunt


	echo "Build done in build-$OS"

esac

