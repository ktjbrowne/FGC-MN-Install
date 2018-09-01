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
MNALIAS=''
UNCOUNTER=1

MN_KEY=''
TXHASH=''
OUTPUTIDX=''


###############################################################################
## MAIN Functions
###############################################################################
###############################################################################
#
# show script Details
doWelcome(){
  prettySection "Welcome to the FGC Multi MN Installer for v_1.2.5"
  read -e -p "Enter your Private Key (genkey):  " MN_KEY
}



###############################################################################
###############################################################################
## system Check
doSystemValidation(){
  prettySection "VALIDATING SYSTEM"
  sleep 1

  ################################
  # Only run if root.
  echo "check root user"
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
  echo "check systemd"
  systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04 or 18.04?" >&2; exit 1; }
  sleep 1

  ################################
  # Check for Ubuntu
  echo "check system version"
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
  sleep 1

  ################################
  ##Check Free Space
  echo "check free space"
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
  echo "check root swap file"
  if [ ! -f /swapfile  ]; then
    echo "no swap file, creating swap for root"
    fallocate -l 256M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap defaults 0 0" >> /etc/fstab
  else echo "swap exists for root"
  fi
  sleep 1

}
###############################################################################

###############################################################################
###############################################################################
doSystemVars(){
  prettySection "CONFIG SYSTEM VARIABLES"

  #get IPs
  echo "IPs..."
  PUBLIC_IP="$(wget -qO- -o- ipinfo.io/ip)"
  PRIVATE_IP="$(ip route get 8.8.8.8 | sed 's/ uid .*//' | awk '{print $NF; exit}')"

  #check default port v existing
  echo "Ports..."
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
  echo "UserName..."
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

}
###############################################################################


###############################################################################
###############################################################################
doReview(){
prettySection "REVIEW INPUTS"

echo
prettyPrint "Username" "${USER_NAME}"
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

doSystemConfig(){
return 0
}

## install dependencies
doSystemPackages(){
prettySection "INSTALLING DEPENDENCIES"
sleep 3
echo "updating system"
# Update the system.
DEBIAN_FRONTEND=noninteractive apt-get install -yq libc6 software-properties-common
DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
#DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
#apt-get -f install -y
DEBIAN_FRONTEND=noninteractive apt-get -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
apt-get -f install -y &
waitOnProgram "Updating system. This may take several minutes"

echo "installing bitcoin"
echo | add-apt-repository ppa:bitcoin/bitcoin
apt-get update
apt-get install -y libdb4.8-dev libdb4.8++-dev

# Add in older boost files if needed.
echo "intalling boost"
if [ ! -f /usr/lib/x86_64-linux-gnu/libboost_system.so.1.58.0 ]; then
  # Add in 16.04 repo.
  echo "deb http://archive.ubuntu.com/ubuntu/ xenial-updates main restricted" >> /etc/apt/sources.list
  apt-get update -y

  # Install old boost files.
  apt-get install -y libboost-system1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 libboost-thread1.58.0
fi

echo "installing apps"
# Make sure certain programs are installed.
apt-get install -y screen curl htop gpw unattended-upgrades jq bc pwgen libminiupnpc10 ufw lsof util-linux gzip denyhosts procps unzip

echo "setting auto update"
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

# Update system clock.
timedatectl set-ntp off
timedatectl set-ntp on
# Increase open files limit.
ulimit -n 4096

echo "checking user swap file"
if [ ! -f "/swapfile_${USER_NAME}"  ]; then
  echo "no user swap file, creating"
  fallocate -l 256M "/swapfile_${USER_NAME}"
  chmod 600 "/swapfile_${USER_NAME}"
  mkswap "/swapfile_${USER_NAME}"
  swapon "/swapfile_${USER_NAME}"
  echo "/swapfile_${USER_NAME} none swap defaults 0 0" >> /etc/fstab
else echo "user swap file already exists"
fi

}


## install dependencies
doSystemPackages_(){
prettySection "INSTALLING DEPENDENCIES"
sleep 3


echo "...install packages...start"
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget htop unzip
apt-get -qq install build-essential && apt-get -qq install libtool autotools-dev autoconf automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev
apt-get -qq install aptitude

aptitude -y -q install fail2ban
service fail2ban restart

apt-get -qq install ufw
echo "...install packages...end"

}

## Get Port and do ufw
doPorts() {
return 0
}

## download binaries
doDownload() {
return 0
}

## make config file
doConfigs() {
return 0
}

## get BootStrap
getBootStrap() {
return 0
}

## Enable & Start
startCoin() {
return 0
}

## check and show sync
checkSync() {
return 0
}

## check MN status
checkStatus() {
return 0
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
  echo -n -e "\\e[1;3m${LABEL}\\e[0m:"
  if [ $(echo -n "${LABEL}" | wc -m) -lt 7 ]; then
    echo -n -e "\t\t"
  elif [ $(echo -n "${LABEL}" | wc -m) -lt 15 ]; then
    echo -n -e "\t"
  fi
  echo -n -e "\t${VALUE}"
  if [ "${HINT}" != "" ]; then
    echo -n -e " \t\\e[2m(${HINT})\\e[0m"
  fi
  echo
}

prettySection() {
  printf "\\n\\n\\e[43;30m***    %-30s    ***\\e[0m\\n" "$1"
}

waitOnProgram() {
  local MESSAGE=$1
  local PID=$!
  local i=1
  while [ -d /proc/$PID ]; do
    printf "\\r${SPINNER:i++%${#SPINNER}:1} ${MESSAGE}"
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
doReview
doSystemPackages
#setInputs
#doReview






################################################################################
################################################################################
