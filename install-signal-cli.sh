#!/bin/bash
# get lastest Signal-cli release version
export VERSION=$(curl -s 'https://api.github.com/repos/AsamK/signal-cli/releases/latest' | python3 -c "import sys, json; print(json.load(sys.stdin)['name'][1:])")
echo "Installing version $VERSION"

export signalUrl=$(curl -s 'https://api.github.com/repos/AsamK/signal-cli/releases/latest' | python3 -c "import sys, json; assets=json.load(sys.stdin)['assets']; url = [x for x in assets if 'signal-cli-$VERSION.tar.gz' in x['browser_download_url']]; print(url[0]['browser_download_url']);")

export libUrl=$(curl -s 'https://api.github.com/repos/exquo/signal-libs-build/releases/latest' | python3 -c "import sys, json; assets=json.load(sys.stdin)['assets']; url = [x for x in assets if '-aarch64-unknown-linux-' in x['browser_download_url']]; print(url[0]['browser_download_url']);")

# get lastest libsignal release version
export LIBVERSION=$(curl --silent "https://api.github.com/repos/exquo/signal-libs-build/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'| sed 's/libsignal_v//')

set -euxo pipefail

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root or with sudo rights" 1>&2
   exit 1
fi

# default install
if [ -d "/opt/signal-cli-${VERSION}" ]
then
    echo "signal-cli is alerady installed with this version: ${VERSION}"
    exit 0
fi

# script Dependencies
command_check_dependencies=(zip curl)
apt update

for i in "${apt_dependencies[@]}"
do
    if ! command -v $i &> /dev/null
    then
        apt install $i -y
    fi
done

# java
if ! command -v java &> /dev/null
then
    apt install openjdk-17-jdk -y
fi

# delete temp folder if it exists
if [ -d "/tmp/signal-cli-install" ]
then
    rm -r /tmp/signal-cli-install
fi

mkdir /tmp/signal-cli-install

rm -R /opt/signal-cli

curl --proto '=https' --tlsv1.2 -L -o /tmp/signal-cli-install/signal-cli-"${VERSION}"-Linux.tar.gz $signalUrl
tar xf /tmp/signal-cli-install/signal-cli-"${VERSION}"-Linux.tar.gz -C /opt
rm /tmp/signal-cli-install/signal-cli-"${VERSION}"-Linux.tar.gz
ln -sf /opt/signal-cli-"${VERSION}"/bin/signal-cli /usr/local/bin/

# libsignal
curl --proto '=https' --tlsv1.2 -L -o /tmp/signal-cli-install/libsignal.tar.gz $libUrl
tar xf /tmp/signal-cli-install/libsignal.tar.gz -C /tmp/signal-cli-install
rm /tmp/signal-cli-install/libsignal.tar.gz

# replace libsignal_jni.so
cd
# Delete the old one
zip -d /opt/signal-cli-"${VERSION}"/lib/libsignal-client-*.jar libsignal_jni.so
# add the new one
zip /opt/signal-cli-"${VERSION}"/lib/libsignal-client-*.jar /tmp/signal-cli-install/libsignal_jni.so

# fallback of libsignal_jni.so
## create folder if it dosent exist
if [ -d "/usr/java/packages/lib" ]
then
    mkdir -p /usr/java/packages/lib
fi

## copy libsignal_jni.so to Java library path
cp  /tmp/signal-cli-install/libsignal_jni.so /usr/java/packages/lib

# permissions
chown root:root /usr/java/packages/lib/libsignal_jni.so
chmod 755 /usr/java/packages/lib/libsignal_jni.so
chmod 755 -R /opt/signal-cli-${VERSION}
chown root:root -R /opt/signal-cli-${VERSION}

# cleanup temp folder
rm -r /tmp/signal-cli-install

/opt/signal-cli-${VERSION}/bin/signal-cli --version

exit 0
