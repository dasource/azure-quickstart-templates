#!/bin/bash
set -x

echo "initializing Shadow installation"

date
ps axjf

AZUREUSER=$2
HOMEDIR="/home/$AZUREUSER"
SHADOWPATH="$HOMEDIR/.shadowcoin"
VMNAME=`hostname`
echo "User: $AZUREUSER"
echo "User home dir: $HOMEDIR"
echo "User Shadow path: $SHADOWPATH"
echo "vmname: $VMNAME"


if [ $1 = 'From_Source' ]; then
	## Compile from Source
	sudo apt-get update
	sudo apt-get -y install git build-essential libssl-dev libdb-dev libdb++-dev libboost-all-dev libqrencode-dev unzip pwgen
	cd /usr/local/src/
	sudo git clone https://github.com/ShadowProject/shadow 
	cd shadow/src 
	sudo make -f makefile.unix 
	sudo strip shadowcoind
	sudo cp shadowcoind /usr/bin/shadowcoind
else    
	## Download Binaries
	sudo apt-get update
	sudo apt-get -y install curl unzip pwgen
	cd /usr/local/src/
	DOWNLOADFILE=$(curl -s https://api.github.com/repos/shadowproject/shadow/releases | grep browser_download_url | grep linux64 | head -n 1 | cut -d '"' -f 4)
	DOWNLOADNAME=$(curl -s https://api.github.com/repos/shadowproject/shadow/releases | grep name | grep linux64 | head -n 1 | cut -d '"' -f 4)
	sudo wget $DOWNLOADFILE
	sudo unzip $DOWNLOADNAME
	sudo cp shadowcoind /usr/bin/shadowcoind
fi

# Create Client Directory
if [ ! -e "$SHADOWPATH" ]; then
	su - $AZUREUSER -c "mkdir $SHADOWPATH"
fi

# Download Blockchain Data
su - $AZUREUSER -c "cd $SHADOWPATH; wget https://github.com/ShadowProject/blockchain/releases/download/latest/blockchain.zip"
su - $AZUREUSER -c "cd $SHADOWPATH; unzip blockchain.zip"

# Create Shadow configuration file
su - $AZUREUSER -c "touch $SHADOWPATH/shadowcoin.conf"
rpcu=$(pwgen -ncsB 35 1)
rpcp=$(pwgen -ncsB 75 1)
echo "rpcuser="$rpcu"
rpcpassword="$rpcp"
daemon=1
logtimestamps=1" > $SHADOWPATH/shadowcoin.conf

if [ $1 = 'From_Binaries_and_TOR' ]; then
	## Install and Enable Shadow Tor Support
	sudo add-apt-repository "deb http://deb.torproject.org/torproject.org $(lsb_release -s -c) main"
	sudo gpg --keyserver keys.gnupg.net --recv 886DDD89
	sudo gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | sudo apt-key add -
	sudo apt-get update
	sudo apt-get -y install tor deb.torproject.org-keyring
	sudo sh -c "cat >> /etc/tor/torrc << EOF
HiddenServiceDir /var/lib/tor/shadow-service/
HiddenServicePort 51737 127.0.0.1:51737
SocksPort 127.0.0.1:9150
EOF"
	sudo service tor reload
	sh -c "cat >> $SHADOWPATH/shadowcoin.conf << EOF
bind=127.0.0.1:51737
externalip=$(dig +short myip.opendns.com @resolver1.opendns.com)

externalip=$(sudo cat /var/lib/tor/shadow-service/hostname)
tor=127.0.0.1:9150
EOF"
fi

# Start Shadow Client
su - $AZUREUSER -c "shadowcoind"

echo "completed Shadow install $$"
exit 0
