#!/bin/bash
clear

# Set these to change the version of FantasyGold to install
TARBALLURL="https://github.com/FantasyGold/FantasyGold-Core/releases/download/1.2.4/FantasyGold-1.2.4-Linux-x64.tar.gz"
TARBALLNAME="FantasyGold-1.2.4-Linux-x64.tar.gz"
FGCVERSION="1.2.4"

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Check if we have enough memory
if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 900 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# Check if we have enough disk space
if [[ `df -k --output=avail / | tail -n1` -lt 10485760 ]]; then
  echo "This installation requires at least 10GB of free disk space.";
  exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
clear

echo "
    ___T_
   | o o |
   |__-__|
   /| []|\\
 ()/|___|\()
    |_|_|
    /_|_\  ------- MASTERNODE INSTALLER v2.1 -------+
 |                                                |
 |You can choose between two installation options:|::
 |             default and advanced.              |::
 |                                                |::
 | The advanced installation will install and run |::
 |  the masternode under a non-root user. If you  |::
 |  don't know what that means, use the default   |::
 |              installation method.              |::
 |                                                |::
 | Otherwise, your masternode will not work, and  |::
 |the FGC Team CANNOT assist you in repairing |::
 |        it. You will have to start over.        |::
 |                                                |::
 |Don't use the advanced option unless you are an |::
 |            experienced Linux user.             |::
 |                                                |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::
"

sleep 5

read -e -p "Use the Advanced Installation? [N/y] : " ADVANCED

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]; then

USER=fantasygold

adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null

echo "" && echo 'Added user "fantasygold"' && echo ""
sleep 1

else

USER=root

fi

USERHOME=`eval echo "~$USER"`

read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
read -e -p "Masternode Private Key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h # THE KEY YOU GENERATED EARLIER) : " KEY
read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
read -e -p "Install UFW and configure ports? [Y/n] : " UFW

#####Test Multi MN: Get MN Number v1
read -e -p "Masternode Number: [0 bypass]" MNNUM
PORT=5781$NMNUM

clear

# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
if [[ ("$MNNUM" == "0") ]]; then
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget htop unzip
apt-get -qq install build-essential && apt-get -qq install libtool autotools-dev autoconf automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev
apt-get -qq install aptitude
fi

# Install Fail2Ban
if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
  aptitude -y -q install fail2ban
  service fail2ban restart
fi

# Install UFW
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
  apt-get -qq install ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow $PORT/tcp
  yes | ufw enable
fi

if [[ ("$MNNUM" == "0") ]]; then
# Install FantasyGold daemon
wget $TARBALLURL
tar -xzvf $TARBALLNAME #&& mv bin fantasygold-$FGCVERSION
rm $TARBALLNAME
cp ./fantasygoldd /usr/local/bin
cp ./fantasygold-cli /usr/local/bin
cp ./fantasygold-tx /usr/local/bin
cp ./fantasygold-qt /usr/local/bin
#rm -rf fantasygold-$FGCVERSION
fi

# Create .fantasygold directory
CONFDIR=$USERHOME/.fantasygold$MNNUM
mkdir $CONFDIR

# Create fantasygold.conf
touch $CONFDIR/fantasygold.conf
cat > $CONFDIR/fantasygold.conf << EOL
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=${IP}
bind=${IP}:${PORT}
masternodeaddr=${IP}
masternodeprivkey=${KEY}
masternode=1
EOL
chmod 0600 $CONFDIR/fantasygold.conf
chown -R $USER:$USER $CONFDIR

sleep 1

cat > /etc/systemd/system/fantasygoldd$MNNUM.service << EOL
[Unit]
Description=fantasygoldd${MNNUM}
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/fantasygoldd -conf=${CONFDIR}/fantasygold.conf -datadir=${CONFDIR}
ExecStop=/usr/local/bin/fantasygold-cli -conf=${CONFDIR}/fantasygold.conf -datadir=${CONFDIR} stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
sudo systemctl enable fantasygoldd$MNNUM
sudo systemctl start fantasygoldd$MNNUM
sudo systemctl start fantasygoldd$MNNUM.service

#clear

cat << EOL
Now, you need to start your masternode. Please go to your desktop wallet and
select your masternode and click the start buttom.
EOL

read -p "Press any key to continue after you've done that. " -n1 -s

#clear

echo "Your masternode is syncing. Please wait for this process to finish."
echo "CTRL+C to exit the masternode sync once you see the MN ENABLED in your local wallet." && echo ""

until su -c "fantasygold-cli -conf=/root/.fantasygold1/fantasygold.conf -datadir=/root/.fantasygold1/ startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 2
    echo -en "${CHARS:$i:1}" "\r"
  done
done

sleep 1
su -c "/usr/local/bin/fantasygold-cli -conf=/root/.fantasygold1/fantasygold.conf -datadir=/root/.fantasygold1/ startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/fantasygold-cli -conf=/root/.fantasygold1/fantasygold.conf -datadir=/root/.fantasygold1/ masternode status" $USER
sleep 5

echo "" && echo "Masternode setup completed." && echo ""
© 2018 GitHub, Inc.
