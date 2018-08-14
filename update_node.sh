#!/bin/bash
clear

TARBALLURL="https://github.com/FantasyGold/FantasyGold-Core/releases/download/v1.2.5/FantasyGold-1.2.5-Linux-x64.tar.gz"
TARBALLNAME="FantasyGold-1.2.5-Linux-x64.tar.gz"
FGCVERSION="1.2.5"

CHARS="/-\|"

clear
echo "
 +----------------------------------------------------script.v1.3+::
 | FantasyGold Masternode Update Script Version: $FGCVERSION           |::
 |                                                               |::
 | This script is complemintary to the original install script.  |::
 | If you manually installed, please update your VPS manually.   |::
 |                                                               |::
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

sed -i '/^addnode/d' ./.fantasygold/fantasygold.conf
chmod 0600 ./.fantasygold/fantasygold.conf
#chown -R $USER:$USER ./.fantasygold

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
  #sudo systemctl start fantasygoldd.service
  ./usr/local/bin/fantasygoldd -reindex
fi

sleep 4

until su -c "fantasygold-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 5
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

su -c "/usr/lcoal/bin/fantasygold-cli getinfo" $USER
su -c "/usr/local/bin/fantasygold-cli masternode status" $USER
echo "" && echo "Masternode setup completed." && echo ""

