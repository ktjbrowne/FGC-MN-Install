#bash <( curl https://raw.githubusercontent.com/ktjbrowne/FGC-MN-Install/master/install-multi-mn1.sh )

## Set Coin Details
COIN_SYMBOL="FGC"
COIN_NAME="FantasyGold"
COIN_DAEMON="fantasygoldd"
COIN_CLI="fantasygold-cli"
COIN_APP_URL="https://github.com/FantasyGold/FantasyGold-Core/releases/download/v1.2.5/FantasyGold-1.2.5-Linux-x64.tar.gz"
COIN_FILE="FantasyGold-1.2.5-Linux-x64.tar.gz"
COIN_CONFIG_FOLDER=".fantasygold"
COIN_CONFIG_FILE="fantasygold.conf"
COIN_BLOCK_COUNT_URL="http://fantasygold.network/api/getblockcount"
DONATION_ADDRESS=""
DEFAULT_PORT=57810
BOOTSTRAP_URL=""
#EXTRACT_CMD="unzip artifact -d /tmp/extract"
EXTRACT_CMD="tar xvf artifact -C /tmp/extract"

# Chars for spinner.
SPINNER="/-\\|"
# Regex to check if output is a number.
REGEX_NUMBER='^[0-9]+$'

PUBLIC_IP=''
PRIVATE_IP=''
PORTA=''
PORTB=''

USER_NAME=''
USER_PASS=''
MNALIAS=''
UNCOUNTER=1

MN_KEY=''
TXHASH=''
OUTPUTIDX=''

ADDNODES="addnode=188.166.80.20:57810
addnode=173.230.141.205:57810
addnode=140.82.51.61:57810
addnode=167.99.33.74:57810
addnode=45.33.55.198:57810"


###############################################################################
## MAIN Functions
###############################################################################
###############################################################################
#
# show script Details
doWelcome(){
  printHead0 "Welcome to the FGC Multi MN Installer for v_1.2.5"
  echo "V4"
  #read -e -p "Enter your Private Key (genkey):  " MN_KEY
}



###############################################################################
###############################################################################
## system Check
doSystemValidation(){
  printHead0 "VALIDATING SYSTEM"
  sleep 1

  ################################
  # Only run if root.
  printHead1 "check root user"
  sleep 0.5
  if [ "$(whoami)" != "root" ]; then
    echo "Script must be run as user: root"
    echo "To switch to the root user type"
    echo
    echo "sudo su"
    echo
    echo "And then re-run this command."
    exit -1
  fi

  ################################
  # Check for systemd
  printHead1 "check systemd"
  sleep 0.5
  systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04 or 18.04?" >&2; exit 1; }


  ################################
  # Check for Ubuntu
  printHead1 "check system version"
  sleep 0.5
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=${NAME}
    VER=${VERSION_ID}
  elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=${DISTRIB_ID}
    VER=${DISTRIB_RELEASE}
  elif [ -f /etc/debian_version ]; then
    OS=Debian
    VER=$(cat /etc/debian_version)
  else
    OS=$(uname -s)
    VER=$(uname -r)
  fi

  if [ "$OS" != "Ubuntu" ]
  then
    cat /etc/*-release
    echo
    echo "Are you using Ubuntu 16.04 or higher?"
    echo
    exit 1
  fi

  TARGET='16.03'
  if [ ${VER%.*} -eq ${TARGET%.*} ] && [ ${VER#*.} \> ${TARGET#*.} ] || [ ${VER%.*} -gt ${TARGET%.*} ]
  then
    :
  else
    cat /etc/*-release
    echo
    echo "Are you using Ubuntu 16.04 or higher?"
    echo
    exit 1
  fi

  ################################
  ##Check Free Space
  printHead1 "check free space"
  sleep 0.5
  FREEPSPACE=$(df -P . | tail -1 | awk '{print $4}')
  if [ ${FREEPSPACE} -lt 2097152 ]; then
    echo "${FREEPSACE} bytes of free disk space found. Need at least 2Gb of free space to proceed"
    exit 1
  fi
  sleep 1

  # Check if we have enough memory
  if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 900 ]]; then
    echo "This installation requires at least 1GB of RAM.";
    exit 1
  fi

  ################################
  #Check Swap file for Root, will only create on first run.
  printHead2 "check root swap file"
  sleep 0.5
  if [ ! -f /swapfile  ]; then
    printHead1 "no swap file, creating swap for root"
    fallocate -l 256M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    #echo "/swapfile none swap defaults 0 0" >> /etc/fstab
  else printHead2 "swap exists for root"
  fi

}
###############################################################################

###############################################################################
###############################################################################
doSystemVars(){
  printHead0 "CONFIG SYSTEM VARIABLES"
  sleep 1
  #get IPs
  printHead1 "IPs..."
  PUBLIC_IP="$(wget -qO- -o- ipinfo.io/ip)"
  PRIVATE_IP="$(ip route get 8.8.8.8 | sed 's/ uid .*//' | awk '{print $NF; exit}')"

  #check default port v existing
  printHead1 "Ports..."
  sleep 0.5
  PORTB=''
  if [ -z "${PORTB}" ] && [ -x "$(command -v netstat)" ] && [[ $( netstat -tulpn | grep "/${COIN_DAEMON}" | grep "${DEFAULT_PORT}" | wc -c ) -gt 0 ]]
  then
    PORTB="${DEFAULT_PORT}a"
  fi
  if [ -z "${PORTB}" ] && [ -x "$(command -v ufw)" ] && [[ $( ufw status | grep "${DEFAULT_PORT}" | wc -c ) -gt 0 ]]
  then
    PORTB="${DEFAULT_PORT}b"
  fi
  if [ -z "${PORTB}" ] && [ -x "$(command -v iptables)" ] && [[ $( iptables -t nat -L | grep "${DEFAULT_PORT}" | wc -c) -gt 0 ]]
  then
    PORTB="${DEFAULT_PORT}c"
  fi
  if [ -z "${PORTB}" ]
  then
    PORTB="${DEFAULT_PORT}"
  else
    PORTB=''
  fi

  #Set Username
  printHead1 "UserName..."
  sleep 0.5
  # Set alias as the hostname.
  USER_NAME="${COIN_SYMBOL,,}_mn1"
  MNALIAS="$(hostname)"
  # Auto pick a user that is blank.
  UNCOUNTER=1
  while :
  do
    if id "${USER_NAME}" >/dev/null 2>&1; then
      UNCOUNTER=$((UNCOUNTER+1))
      USER_NAME="${COIN_SYMBOL,,}_mn${UNCOUNTER}"
    else
      break
    fi
  done

  # Set new user mn1 password to a big string.
  printHead1 "User Pass"
  useradd -m "${USER_NAME}" -s /bin/bash
  if ! [ -x "$(command -v pwgen)" ]
  then
    USERPASS=$(openssl rand -hex 36)
    echo "${USER_NAME}:${USERPASS}" | chpasswd
  else
    USERPASS=$(pwgen -1 -s 44)
    echo "${USER_NAME}:${USERPASS}" | chpasswd
  fi


}
###############################################################################


###############################################################################
###############################################################################
doReview(){
printHead0 "REVIEW INPUTS"
sleep 1
echo
prettyPrint "Username" "${USER_NAME}"
prettyPrint "UserPass" "${USERPASS}"
# Get public and private ip addresses.
if [ "${PUBLIC_IP}" != "${PRIVATE_IP}" ] && [ "${PRIVATE_IP}" == "0" ]; then
  PRIVATE_IP=${PUBLIC_IP}
fi
if [ "${PUBLIC_IP}" != "${PRIVATE_IP}" ]; then
  prettyPrint "Public Address" "${PUBLIC_IP}"
  prettyPrint "Private Address" "${PRIVATE_IP}"
else
  prettyPrint "Public Address" "${PUBLIC_IP}"
fi
# ports
if [ -z "${PORTB}" ]; then
  prettyPrint "Port" "auto" "find available port"
else
  prettyPrint "Port" "${PORTB}"
fi
prettyPrint "Masternode Private Key" "${MN_KEY}"
#prettyPrint "Transaction Hash" "${TXHASH}"
#prettyPrint "Output Index Number" "${OUTPUTIDX}"
prettyPrint "Alias" "${USER_NAME}_${MNALIAS}"

echo
}



## install dependencies
doSystemPackages(){
printHead0 "INSTALLING DEPENDENCIES"
sleep 1
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
waitOnProgram  "upgrading software"
#sleep 0.5

# Update system clock.
timedatectl set-ntp off
timedatectl set-ntp on
# Increase open files limit.
ulimit -n 4096

printHead1 "config firewall"
sleep 0.5
ufw allow 22
ufw allow 123
echo "y" | ufw enable
ufw reload


printHead1 "checking user swap file"
sleep 0.5
if [ ! -f "/swapfile_${USER_NAME}"  ]; then
  printHead2 "no user swap file, creating"
  fallocate -l 256M "/swapfile_${USER_NAME}"
  chmod 600 "/swapfile_${USER_NAME}"
  mkswap "/swapfile_${USER_NAME}"
  swapon "/swapfile_${USER_NAME}"
  #echo "/swapfile_${USER_NAME} none swap defaults 0 0" >> /etc/fstab
  SWAP="$(swapon -s)"
  printHead2 "${SWAP}"
else printHead2 "user swap file already exists"
fi
}



## download binaries
doDownload() {

  printHead0 "DOWNLOADING ${COIN_NAME}"
  cd ~/ || exit
  # Download and extract binary
  curl -L ${COIN_APP_URL} -o artifact
  mkdir -p /tmp/extract
  ${EXTRACT_CMD}

}

# Copy binary to user home directory
doInstall() {

  printHead0 "INSTALLING ${COIN_NAME}"
  sleep 1
  printHead1 "make directory"
  sleep 0.5
  mkdir -p /home/${USER_NAME}/.local/bin
  find /tmp/extract -type f | xargs chmod 755
  find /tmp/extract -type f -exec mv -- "{}" /home/${USER_NAME}/.local/bin \;
  rm -rf /tmp/extract
  chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.local
  printHead1 "move files"
  sleep 0.5
  printHead1 "set attributes"
  sleep 0.5
}


## Get Port and do ufw
doPorts() {
  printHead0 "CONFIGURING PORTS"
  sleep 1
  # Find open port.
  read -r LOWERPORT UPPERPORT < /proc/sys/net/ipv4/ip_local_port_range
  while :
  do
    PORTA=$(shuf -i "$LOWERPORT"-"$UPPERPORT" -n 1)
    ss -lpn 2>/dev/null | grep -q ":$PORTA " || break
  done

  # Find open port if one wasn't provided.
  if [ -z "$PORTB" ]
  then
    while :
    do
      PORTB=$(shuf -i "$LOWERPORT"-"$UPPERPORT" -n 1)
      ss -lpn 2>/dev/null | grep -q ":$PORTB " || break
    done
  fi

  # Open up port.
  ufw allow ${PORTB}
  echo "y" | ufw enable
  ufw reload

  PORTS="$(netstat -l)"
  printHead2 "${PORTS}"

}

## make config file
doConfigs() {
printHead0 "CREATING COIN CONFIGS"
sleep 1
  # Generate random password.
  if ! [ -x "$(command -v pwgen)" ]; then
    PWA="$(openssl rand -hex 36)"
  else
    PWA="$(pwgen -1 -s 44)"
  fi

  # TODO: Seed an addnodes list but first create a monitor script that auto-monitors/maintains a valid list of peer nodes

su - "${USER_NAME}" -c "mkdir -p /home/${USER_NAME}/${COIN_CONFIG_FOLDER}/ && touch /home/${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE}"
printf "rpcuser=rpc_${USER_NAME}
rpcpassword=${PWA}
rpcallowip=127.0.0.1
rpcport=${PORTA}
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=${PUBLIC_IP}
bind=${PUBLIC_IP}:${PORTB}
masternodeaddr=${PUBLIC_IP}
masternodeprivkey=${MN_KEY}
masternode=1
${ADDNODES}
" > "/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE}"

chmod 0600 /home/${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE}
chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/${COIN_CONFIG_FOLDER}

printHead0 "CREATING SERVICE CONFIGS"
sleep 1
printf "[Unit]
Description=${COIN_NAME} Masternode for user ${USER_NAME}
After=network.target
[Service]
Type=forking
User=${USER_NAME}
WorkingDirectory=/home/${USER_NAME}
ExecStart=/home/${USER_NAME}/.local/bin/${COIN_DAEMON} -conf=/home${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE} -datadir=/home/${USER_NAME}/${COIN_CONFIG_FOLDER}
ExecStop=/home/${USER_NAME}/.local/bin/${COIN_CLI} -conf=/home${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE} -datadir=/home${USER_NAME}/${COIN_CONFIG_FOLDER} stop
Restart=on-abort
[Install]
WantedBy=multi-user.target" > "/etc/systemd/system/${USER_NAME}.service"


}

## Enable & Start
enableCoin() {
printHead0 "STARTING ${COIN_NAME}"
sleep 1
sudo systemctl enable "${USER_NAME}"
sudo systemctl start "${USER_NAME}"
sudo systemctl start "${USER_NAME}".service

}

## Enable & Start
startCoin() {
printHead0 "STARTING ${COIN_NAME}"
sleep 1
/home/${USER_NAME}/.local/bin/${COIN_DAEMON} -conf=/home${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE} -datadir=/home/${USER_NAME}/${COIN_CONFIG_FOLDER}

# Output info.
systemctl status --no-pager --full "${USER_NAME}"
sleep 2
echo
ufw status
sleep 4
echo

sleep 10
/home/${USER_NAME}/.local/bin/${COIN_DAEMON} getblockcount
}

## stop COIN
stopCoin() {
printHead0 "STOPPING ${COIN_NAME}"
sleep 1
/home/${USER_NAME}/.local/bin/${COIN_CLI} stop
}

## get BootStrap
doBootStrap() {
  printHead0 "BOOTSTRAPPING"
  sleep 1
  # Monitor block count and wait for it to be caught up.
  if [ -z "$var" ]
  then
        printHead1 "BOOTSTRAP_URL is empty"
  else
        printHead1 "No Bootstrap functionality yet"
  fi
}



## check and show sync
checkSync() {
return 0
}

## check MN status
checkStatus() {
  printHead0 "Step 10: Setup Complete. Document the below information"
  # Output more info.
  #echo ========== Donation Information ==================
  #echo
  #echo "# Send a tip in ${COIN_NAME} to the author of this script"
  #prettyPrint "${COIN_SYMBOL} Donation" "${DONATION_ADDRESS}"
  #echo
  echo ========== Useful Root Commands ==================
  echo
  prettyPrint "Daemon Status" "systemctl status --no-pager --full ${USER_NAME}"
  prettyPrint " Daemon Start" "systemctl start ${USER_NAME}"
  prettyPrint "  Daemon Stop" "systemctl stop ${USER_NAME}"
  prettyPrint "    MN Status" "su - ${USER_NAME} -c '${COIN_CLI} masternode status'"
  prettyPrint "  Block Count" "su - ${USER_NAME} -c '${COIN_CLI} getblockcount'"
  echo

  # Print IP and PORT.
  echo ========== Access and Credentials ================
  echo
  echo Masternode is installed under user ${USER_NAME}, you must ssh into the system using credentials below
  echo
  prettyPrint "SSH Info" "ssh ${USER_NAME}@${PUBLIC_IP}"
  prettyPrint "Username" "${USER_NAME}"
  prettyPrint "Password" "${USERPASS}"
  echo
  echo "Useful commands to know"
  prettyPrint "     Get Info" "${COIN_CLI} getinfo"
  prettyPrint "    MN Status" "${COIN_CLI} masternode status"
  prettyPrint "  Block Count" "${COIN_CLI} getblockcount"
  echo
  echo ========== Masternode Information ================
  echo
  /home/${USER_NAME}/.local/bin/${COIN_CLI} -datadir=/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/ masternode status
  echo
  prettyPrint "           Alias" "${USER_NAME}_${MNALIAS}"
  prettyPrint "            Host" "${PUBLIC_IP}:${PORTB}"
  prettyPrint "     Private Key" "${MN_KEY}"
  if [ ! -z "${TXHASH}" ]
  then
    prettyPrint " Collateral txid" "${TXHASH}"
    prettyPrint "Collateral index" "${OUTPUTIDX}"
    echo
    printf "\\e[33;1m%s\\e[0m\\n\\t%s" "Add to the masternode.conf configuration" "${USER_NAME}_${MNALIAS} ${PUBLIC_IP}:${PORTB} ${MN_KEY} ${TXHASH} ${OUTPUTIDX}"
  else
    echo
    printf "\\e[33;1m%s\\e[0m\\n\\t%s" "Append the txhash and outputidx onto the masternode.conf configuration below" "${USER_NAME}_${MNALIAS} ${PUBLIC_IP}:${PORTB} ${MN_KEY} ${TXHASH} ${OUTPUTIDX}"
  fi

  echo
  echo "Masternode is fully up to date now. Make sure the above information has been captured for your reference"

}

################################################################################
################################################################################
## Other Functions

stringToInt() {
  local -i num="10#${1}"
  echo "${num}"
}

isValidPort() {
  local port="$1"
  local -i port_num
  port_num=$(stringToInt "${port}" 2>/dev/null)

  if (( port_num < 1025 || port_num > 65535 || port_num == 22 ))
  then
    echo "${port} is not a valid port number (1025 to 65535 and not 22)" 1>&2
    return 255
  fi
}

isValidIp() {
  local IPA1=$1
  local stat=1

  if [[ ${IPA1} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];
  then
    OIFS=${IFS}

  IFS='.'               #read man, you will understand, this is internal field separator; which is set as '.'
    ip=($ip)            # IP value is saved as array
    IFS=${OIFS}         #setting IFS back to its original value;

    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
      && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]  # It's testing if any part of IP is more than 255
    stat=$? #If any part of IP as tested above is more than 255 stat will have a non zero value
  fi
  return $stat # as expected returning
}

prettyPrint() {
  local LABEL=$1
  local VALUE=$2
  local HINT=$3
  echo -n -e "\\e[96;40m${LABEL}\\e[0m:"
  if [ $(echo -n "${LABEL}" | wc -m) -lt 7 ]; then
    echo -n -e "\t\t"
  elif [ $(echo -n "${LABEL}" | wc -m) -lt 15 ]; then
    echo -n -e "\t"
  fi
  echo -n -e "\t${VALUE}"
  if [ "${HINT}" != "" ]; then
    echo -n -e " \t\\e[96;40m(${HINT})\\e[0m"
  fi
  echo
}

printHead0() {
  printf "\\n\\n\\e[43;30m***    %-30s    ***\\e[0m\\n" "$1"
}

printHead1() {
  printf "\\e[96;40m* %-30s *\\e[0m\\n" "$1"
}

printHead2() {
  printf "\\e[96;40m -%-30s *\\e[0m\\n" "$1"
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


################################################################################
################################################################################
## Main Program Run


doWelcome
doSystemValidation
doSystemVars
doSystemPackages
doReview
doDownload
doInstall
doPorts
doConfigs


################################################################################
################################################################################
