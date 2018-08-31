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


##################################################################
## MAIN Functions

## show script Details
doWelcome(){
prettySection "...Welcome to the FGC Multi MN Installer for v_1.2.5"
read -e -p "Enter your Private Key (genkey)" MN_KEY
}

## system Check
doChecks(){
prettySection "...1: RUNNING SYSTEM CHECKS...START"
sleep 3

################################
# Only run if root.
echo "...check root...start"
if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  echo "To switch to the root user type"
  echo
  echo "sudo su"
  echo
  echo "And then re-run this command."
  exit -1
fi
echo "...check root...end"
sleep 3
################################

################################
# Check for systemd
echo "...check systemclt...start"
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04 or 18.04?" >&2; exit 1; }
echo "...check systemclt...end"
sleep 3

################################
# Check for Ubuntu
echo "...check system version...start"
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
echo "...check system version...end"
sleep 3

################################
##Check Free Space
echo "...check system space...start"
FREEPSPACE=$(df -P . | tail -1 | awk '{print $4}')
if [ ${FREEPSPACE} -lt 2097152 ]; then
  echo "${FREEPSACE} bytes of free disk space found. Need at least 2Gb of free space to proceed"
  exit 1
fi
echo "...check system space...end"
sleep 3
prettySection "...1- RUNNING SYSTEM CHECKS...END"
sleep 4
}

## get TX or PK
setInputs(){
prettySection "...SET VARIABLES...START"
PUBLIC_IP="$(wget -qO- -o- ipinfo.io/ip)"

PRIVATE_IP="$(ip route get 8.8.8.8 | sed 's/ uid .*//' | awk '{print $NF; exit}')"
MN_KEY=''

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

prettySection "...GET VARIABLES...END"
sleep 3
}

doReview(){
prettySection "...REVIEW INPUTS...start"

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
if [ -z "${PORTB}" ]; then
  prettyPrint "Port" "auto" "find available port"
else
  prettyPrint "Port" "${PORTB}"
fi
prettyPrint "Masternode Private Key" "auto" "self generate one"
prettyPrint "Transaction Hash" "${TXHASH}"
prettyPrint "Output Index Number" "${OUTPUTIDX}"
prettyPrint "Alias" "${USER_NAME}_${MNALIAS}"
echo

}

## install dependencies
doDependencies(){
prettySection "...2- INSTALLING DEPENDENCIES...START"

#Swap file
echo "...swap file...start"
if [ ! -f /swapfile  ]; then
  fallocate -l 256M /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile none swap defaults 0 0" >> /etc/fstab
fi
echo "...swap file...start"
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

prettySection "...2- INSTALLING DEPENDENCIES...END"
}

## Get Port and do ufw
doPorts() {

}

## download binaries
doDownload() {

}

## make config file
doConfigs() {

}

## get BootStrap
getBootStrap() {

}

## Enable & Start
startCoin() {

}

## check and show sync
checkSync() {

}

## check MN status
checkStatus() {

}

##############################################
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
  printf "\\n\\n\\e[42;1m***    %-40s    ***\\e[0m\\n" "$1"
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




#################################################################
## Main Program Run
echo "starting...."
doWelcome
doChecks
doDependencies
setInputs
doReview
