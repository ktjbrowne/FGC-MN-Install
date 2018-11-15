#!/bin/bash
clear

TARBALLURL="https://github.com/FantasyGold/FantasyGold-Core/releases/download/v1.2.7/FantasyGold-1.2.7-Linux-x64.tar.gz"
TARBALLNAME="FantasyGold-1.2.7-Linux-x64.tar.gz"
FGCVERSION="1.2.7"

BOOTSTRAPURL="https://github.com/FantasyGold/FantasyGold-Core/releases/download/v1.2.7/FGC-Bootstrap-1.2.7.tar.gz"
BOOTSTRAPFILE="FGC-Bootstrap-1.2.7.tar.gz"

CHARS="/-\|"

clear
echo "
 +--------------------------------------------------script.v1.2.7+::
 | FantasyGold Masternode Update Script Version: $FGCVERSION           |::
 |                                                               |::
 | This script is complemintary to the original install script.  |::
 | If you manually installed, please update your VPS manually.   |::
 +---------------------------------------------------------------+::
"
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

#USER=`ps u $(pgrep fantasygoldd) | grep fantasygoldd | cut -d " " -f 1`
USER=root
USERHOME=`eval echo "~$USER"`

echo "Shutting down masternode..."
if [ -e /etc/systemd/system/fantasygoldd.service ]; then
  systemctl stop fantasygoldd
else
  su -c "fantasygold-cli stop" $USER
fi

echo "Upgrading fantasygold..."
#mkdir ./fantasygold-temp #&& cd ./fantasygold-temp
rm *
wget $TARBALLURL
tar xvf $TARBALLNAME #&& mv bin fantasygold-$FGCVERSION
rm $TARBALLNAME

cp -f ./fantasygoldd /usr/local/bin
cp -f ./fantasygold-cli /usr/local/bin
cp -f ./fantasygold-tx /usr/local/bin
rm test*
rm fan*-qt
#cd ..
#rm -rf ./fantasygold-temp

#if [ -e /usr/bin/fantasygoldd ];then rm -rf /usr/bin/fantasygoldd; fi
#if [ -e /usr/bin/fantasygold-cli ];then rm -rf /usr/bin/fantasygold-cli; fi
#if [ -e /usr/bin/fantasygold-tx ];then rm -rf /usr/bin/fantasygold-tx; fi

#sed -i '/^addnode/d' ./.fantasygold/fantasygold.conf
chmod 0600 ./.fantasygold/fantasygold.conf
#chown -R $USER:$USER ./.fantasygold

echo "Cleaning chain..."
rm -rf ./.fantasygold/blocks
rm -rf ./.fantasygold/chainstate
rm -f ./.fantasygold/peers.dat

echo "Rewriting fantasygold config..."
sed -i '/^addnode/d' ./.fantasygold/fantasygold.conf

echo "addnode=139.162.190.155
addnode=176.58.126.105
addnode=45.79.151.214
addnode=45.79.203.106
addnode=45.33.115.240
addnode=45.33.49.18" >> ./.fantasygold/fantasygold.conf

echo "Getting Bootstrap..."
wget $BOOTSTRAPURL
tar -xzf $BOOTSTRAPFILE -C $USERHOME/.fantasygold
rm $BOOTSTRAPFILE

sleep 6

echo "Restarting fantasygold daemon..."
if [ -e /etc/systemd/system/fantasygoldd.service ]; then
  systemctl start fantasygoldd
else
  cat > /etc/systemd/system/fantasygoldd.service << EOL
[Unit]
Description=fantasygoldd
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/fantasygoldd -conf=${USERHOME}/.fantasygold/fantasygold.conf -datadir=${USERHOME}/.fantasygold
ExecStop=/usr/local/bin/fantasygold-cli -conf=${USERHOME}/.fantasygold/fantasygold.conf -datadir=${USERHOME}/.fantasygold stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
  sudo systemctl enable fantasygoldd
  sudo systemctl start fantasygoldd.service

fi


sleep 6
cd /usr/local/bin
su -c "fantasygold-cli stop" $USER
sleep 6
echo "Starting"


#read -e -p "Start with Reindex? [y/n] : " RI

#if [[ ("$RI" == "y" || "$RI" == "Y") ]]; then
su -c "fantasygoldd" $USER
#else
#su -c "fantasygoldd" $USER
#fi

sleep 5

until su -c "fantasygold-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 7
    #echo -en "${CHARS:$i:1}" "\r"
    clear
    echo "Service Started. Your masternode is syncing.
    When Current = Synced then select your MN in the local wallet and start it.
    Script should auto finish here."
    echo "
    Current Block: "
    su -c "curl https://fantasygold.network/api/getblockcount" $USER
    echo "
    Synced Blocks: "
    su -c "fantasygold-cli getblockcount" $USER
  done
done

clear
su -c "/usr/local/bin/fantasygold-cli getinfo" $USER
su -c "/usr/local/bin/fantasygold-cli masternode status" $USER
echo "" && echo "Masternode setup completed." && echo ""
