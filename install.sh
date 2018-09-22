#!/bin/bash
clear
##bash <( curl https://raw.githubusercontent.com/ktjbrowne/FGC-MN-Install/master/install.sh )
# Set these to change the version of FantasyGold to install
TARBALLURL="https://github.com/FantasyGold/FantasyGold-Core/releases/download/v1.2.5/FantasyGold-1.2.5-Linux-x64.tar.gz"
TARBALLNAME="FantasyGold-1.2.5-Linux-x64.tar.gz"
FGCVERSION="1.2.5"
BOOTSTRAPURL="https://github.com/FantasyGold/FantasyGold-Core/releases/download/v1.2.5/FGC-Bootstrap-1.2.5-20180922.tar.gz"
BOOTSTRAPFILE="FGC-Bootstrap-1.2.5-20180922.tar.gz"

##############################################################################
##Functions
printHead0() {
  printf "\\n\\n\\e[43;30m***    %-30s    ***\\e[0m\\n" "$1"
}

printHead1() {
  printf "\\e[96;40m* %-30s *\\e[0m\\n" "$1"
}

waitOnProgram() {
  local MESSAGE=$1
  local PID=$!
  local i=1
  while [ -d /proc/$PID ]; do
    printf "\\e[96;40m\\r${SPINNER:i++%${#SPINNER}:1} ${MESSAGE}\\e[0m"
    sleep 0.3
  done
  echo
}
#############################################################################
echo "
 :::::::::::::::::::::::::::::::::::::::::::::::::::
 +-------------------------------------------------+
            __________________________
            ___  ____/_  ____/_  ____/
            __  /_   _  / __ _  /
            _  __/   / /_/ / / /___
            /_/      \____/  \____/

 +-------------------------------------------------+
 +-------  FGC MASTERNODE INSTALLER v1.2.5  -------+
 :::::::::::::::::::::::::::::::::::::::::::::::::::


"
sleep 3

printHead0 "Performing System Checks"
sleep 1
# Check if we are root
if [ "$(id -u)" != "0" ]; then
   printHead1 "This script must be run as root." 1>&2
   exit 1
fi

# Check if we have enough memory
if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 900 ]]; then
  printHead1 "This installation requires at least 1GB of RAM.";
  exit 1
fi

# Check if we have enough disk space
if [[ `df -k --output=avail / | tail -n1` -lt 10485760 ]]; then
  printHead1 "This installation requires at least 10GB of free disk space.";
  exit 1
fi

# Install tools for dig and systemctl
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`

USER=root
USERHOME=`eval echo "~$USER"`

printHead0 "ASKING FOR INFORMATION"

read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
read -e -p "Masternode Private Key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h # THE KEY YOU GENERATED EARLIER) : " KEY
#read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
#read -e -p "Install UFW and configure ports? [Y/n] : " UFW

#clear

# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
printHead0 "INSTALLING DEPENDENCIES"
printHead1 "updating system"
sleep 0.5
# Update the system.
DEBIAN_FRONTEND=noninteractive apt-get install -yq libc6 software-properties-common
DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
#DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
#apt-get -f install -y
DEBIAN_FRONTEND=noninteractive apt-get -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

sleep 0.5

echo
apt-get -f install -y &
waitOnProgram "Updating system. This may take several minutes"

printHead1 "installing bitcoin"
sleep 0.5
echo | add-apt-repository ppa:bitcoin/bitcoin
apt-get update
apt-get install -y libdb4.8-dev libdb4.8++-dev

# Add in older boost files if needed.
printHead1 "installing boost"
sleep 0.5
if [ ! -f /usr/lib/x86_64-linux-gnu/libboost_system.so.1.58.0 ]; then
  # Add in 16.04 repo.
  echo "deb http://archive.ubuntu.com/ubuntu/ xenial-updates main restricted" >> /etc/apt/sources.list
  apt-get update -y

  # Install old boost files.
  apt-get install -y libboost-system1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 libboost-thread1.58.0
fi

printHead1 "installing apps"
sleep 0.5
# Make sure certain programs are installed.
apt-get install -y screen curl htop gpw unattended-upgrades jq bc pwgen libminiupnpc10 ufw lsof util-linux gzip denyhosts procps unzip

printHead1 "writing auto update config"
sleep 0.5
if [ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
  # Enable auto updating of Ubuntu security packages.
  printf 'APT::Periodic::Enable "1";
  APT::Periodic::Download-Upgradeable-Packages "1";
  APT::Periodic::Update-Package-Lists "1";
  APT::Periodic::Unattended-Upgrade "1";
  APT::Get::Assume-Yes "true";
  ' > /etc/apt/apt.conf.d/20auto-upgrades
fi

echo
unattended-upgrade &
waitOnProgram  "upgrading software, please wait some time"
#sleep 0.5

# Update system clock.
timedatectl set-ntp off
timedatectl set-ntp on

printHead1 "installing fail2ban"
sleep 0.5
apt-get -qq install aptitude
aptitude -y -q install fail2ban
service fail2ban restart

printHead1 "configuring firewall"
sleep 0.5
apt-get -qq install ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 57810/tcp
yes | ufw enable



printHead0 "INSTALLING FGC"
sleep 1
# Install FantasyGold daemon
wget $TARBALLURL
tar -xzvf $TARBALLNAME #&& mv bin fantasygold-$FGCVERSION
rm $TARBALLNAME
cp ./fantasygoldd /usr/local/bin
cp ./fantasygold-cli /usr/local/bin
cp ./fantasygold-tx /usr/local/bin
cp ./fantasygold-qt /usr/local/bin
#rm -rf fantasygold-$FGCVERSION

# Create .fantasygold directory
mkdir $USERHOME/.fantasygold

printHead0 "INSTALLING BOOTSTRAP"
sleep 1

wget $BOOTSTRAPURL
tar -xzf $BOOTSTRAPFILE -C $USERHOME/.fantasygold
rm $BOOTSTRAPFILE

# Install bootstrap file
#if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
#  echo "Installing bootstrap file..."
#  wget $BOOTSTRAPURL && unzip $BOOTSTRAPARCHIVE -d $USERHOME/.fantasygold/ && rm $BOOTSTRAPARCHIVE
#fi

printHead0 "CREATING CONFIGS"

# Create fantasygold.conf
touch $USERHOME/.fantasygold/fantasygold.conf
cat > $USERHOME/.fantasygold/fantasygold.conf << EOL
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=${IP}
bind=${IP}:57810
masternodeaddr=${IP}
masternodeprivkey=${KEY}
masternode=1
addnode=45.33.115.240:57810
addnode=45.79.203.106:57810
addnode=45.79.151.214:57810
addnode=176.58.126.105:57810
addnode=139.162.190.155:57810
addnode=104.238.161.199:57810
addnode=45.77.79.164:57810
addnode=217.69.3.8:57810
addnode=128.199.170.82:57810
EOL
chmod 0600 $USERHOME/.fantasygold/fantasygold.conf
chown -R $USER:$USER $USERHOME/.fantasygold

sleep 1

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

printHead0 "STARTING FGC"
sudo systemctl enable fantasygoldd
sudo systemctl start fantasygoldd
sudo systemctl start fantasygoldd.service

#clear

#clear
#echo "Your masternode is syncing. Please wait for this process to finish."

printHead0 "BEGINING SYNC"
until su -c "fantasygold-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 5
    #echo -en "${CHARS:$i:1}" "\r"
  #  clear
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

#echo "Your masternode is syncing. Please wait for this process to finish."
#echo "CTRL+C to exit the masternode sync once you see the MN ENABLED in your local wallet." && echo ""

#until su -c "fantasygold-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
#  for (( i=0; i<${#CHARS}; i++ )); do
#    sleep 2
#    echo -en "${CHARS:$i:1}" "\r"
#  done
#done

sleep 1
su -c "/usr/local/bin/fantasygold-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/fantasygold-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode setup completed." && echo ""
