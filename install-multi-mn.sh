#!/usr/bin/env bash
# Run this file
#bash <( curl https://raw.githubusercontent.com/FantasyGold/FGC-MN-Install/master/install-multi-mn.sh )

COIN_SYMBOL="FGC"
COIN_NAME="FantasyGold"
COIN_DAEMON="fantasygoldd"
COIN_CLI="fantasygold-cli"
COIN_APP_URL="https://github.com/FantasyGold/FantasyGold-Core/releases/download/v1.2.5/FantasyGold-1.2.5-Linux-x64.tar.gz"
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

# Only run if root.
if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  echo "To switch to the root user type"
  echo
  echo "sudo su"
  echo
  echo "And then re-run this command."
  exit -1
fi

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

coinStartOLD() {
  local OPTIONS=$1
  su - ${USER_NAME} -c "~/.local/bin/${COIN_DAEMON} --daemon ${OPTIONS}"

  i=1
  while [[ $(lslocks | grep "/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/.lock" | wc -c ) -eq 0 ]]; do
    printf "\\r${SPINNER:i++%${#SPINNER}:1} Starting ${COIN_NAME}"
    sleep 0.5
    if [ ${i} -gt 34 ]; then
      su - "${USER_NAME}" -c "~/.local/bin/${COIN_DAEMON} --daemon"
      break
    fi
  done

  # Give it a few seconds once starting to make sure it is ready to run
  sleep 3
}
coinStart() {
  local OPTIONS=$1
  su - ${USER_NAME} -c "~/.local/bin/${COIN_DAEMON} ${OPTIONS}"

  i=1
  while [[ $(lslocks | grep "/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/.lock" | wc -c ) -eq 0 ]]; do
    printf "\\r${SPINNER:i++%${#SPINNER}:1} Starting ${COIN_NAME}"
    sleep 0.5
    if [ ${i} -gt 34 ]; then
      su - "${USER_NAME}" -c "~/.local/bin/${COIN_DAEMON} "
      break
    fi
  done

  # Give it a few seconds once starting to make sure it is ready to run
  sleep 3
}

coinStop() {
  i=1
  while [[ $(lslocks | grep "/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/.lock" | wc -c ) -ne 0 ]]; do
    printf "\\r${SPINNER:i++%${#SPINNER}:1} Stopping ${COIN_NAME} (might say cannot connect to server)"
    # Use kill if daemon isn't going away see https://www.youtube.com/watch?v=Fow7iUaKrq4
    if [ ${i} -gt 20 ]; then
      PID=$(ps -aux | grep "${USER_NAME}" | grep "${COIN_DAEMON} | grep -v "bash" | awk '{ print $2 }')
      kill "${PID}"
      echo "${PID} is stuck"
      echo "force stopping it kill ${PID}"
      sleep 5
    fi

    # Wait a half a second if after the 3st time in this loop.
    if [ ${i} -gt 3 ]; then
      sleep 0.5
    fi

    # Check systemctl is being used.
    if [ ! -f "/etc/systemd/system/${USER_NAME}.service" ]
    then
      TEXT=$( { /home/"${USER_NAME}"/.local/bin/${COIN_CLI} -datadir=/home/"${USER_NAME}"/${COIN_CONFIG_FOLDER}/ stop; } 2>&1 )
    else
      TEXT=$( { systemctl stop "${USER_NAME}"; } 2>&1 )
    fi

  done
  echo "${TEXT}"
  echo
  sleep 2
  return 0
}

coinBootstrap() {
  #cp /tmp/blk0001.dat "/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/"

  echo "Downloading and extracting bootstrap"
  curl -L "${BOOTSTRAP_URL}.sha256sum" -o bootstrap.tar.gz.sha256sum
  local SHA256SUM=$(cat bootstrap.tar.gz.sha256sum | awk '{print $1}')
  local BOOTSTRAP_SUM=$(sha256sum /root/bootstrap.tar.gz | awk '{print $1}')

  if [ "${SHA256SUM}" == "${BOOTSTRAP_SUM}" ]; then
    echo "Bootstrap found and is unchanged. Using existing bootstrap"
  else
    echo "Bootstrap out of date. Downloading new bootstrap"
    curl -L "${BOOTSTRAP_URL}" -o /root/bootstrap.tar.gz
  fi

  tar xvfz /root/bootstrap.tar.gz -C /home/${USER_NAME}/${COIN_CONFIG_FOLDER}/
  chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/${COIN_CONFIG_FOLDER}/

  echo "Initializing blocks, this may take over an hour to complete."
  coinStart

  # Monitor the block count synchronization and make sure everything is good
  local PEER_BLOCK_COUNT=500000
  local LOCAL_BLOCK_COUNT=$(/home/${USER_NAME}/.local/bin/${COIN_CLI} -datadir=/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/ getblockcount)
  local COUNTER=0
  while [ "0${LOCAL_BLOCK_COUNT}" -lt "0${PEER_BLOCK_COUNT}" ]; do
    local ETA=$(expr ${PEER_BLOCK_COUNT} - ${LOCAL_BLOCK_COUNT})
    local ETA=$(expr ${ETA} / 90)
    printf "\\r${SPINNER:COUNTER++%${#SPINNER}:1} Synchronizing blocks. Explorer Count: ${PEER_BLOCK_COUNT}, Node Count: ${LOCAL_BLOCK_COUNT} (${ETA} seconds)"
    sleep 0.5
    if [ ${COUNTER} -gt 60 ]; then
      COUNTER=0
      PEER_BLOCK_COUNT=$(/home/${USER_NAME}/.local/bin/${COIN_CLI} -datadir=/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/ getpeerinfo | jq '.[] | .startingheight' | sort -r | uniq | head -1)
    fi
    LOCAL_BLOCK_COUNT=$(/home/${USER_NAME}/.local/bin/${COIN_CLI} -datadir=/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/ getblockcount)
  done

  printf "\\r"
  echo

  coinStop
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

prettySection "Step 1: System Validation"

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04 or 18.04?" >&2; exit 1; }

# Check for Ubuntu
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

FREEPSPACE=$(df -P . | tail -1 | awk '{print $4}')
if [ ${FREEPSPACE} -lt 2097152 ]; then
  echo "${FREEPSACE} bytes of free disk space found. Need at least 2Gb of free space to proceed"
  exit 1
fi

if [ ! -f /swapfile  ]; then
  fallocate -l 256M /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile none swap defaults 0 0" >> /etc/fstab
fi

echo -e "\\e[0m"
clear

exec > >(tee -i install.log) 2>&1

prettySection "Step 2: ${COIN_NAME} Installation"

cat << "EOF"
System validation completed. Installing ${COIN_NAME}




EOF

# Set Defaults
PUBLIC_IP="$(wget -qO- -o- ipinfo.io/ip)"
## Alternative Public IP determination in case the above fails to work for some reason
# PUBLIC_IP=`dig +short myip.opendns.com @resolver1.opendns.com`

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

echo "${COIN_NAME} Masternode Installation"

echo

# Ask for txhash.
while :
do
  TXHASH=''
  echo "To start with, please provide the collateral transaction id."
  echo
  printf "In your wallet go to \\e[33;1m%s\\e[0m and type in\\n" "tools -> debug console"
  printf "\\t\\e[43;1m%s\\e[0m\\n" "masternode outputs"
  echo
  echo "Paste in the transaction id for this masternode; or leave blank to skip this step."
  read -r -p "txhash: " input
  TXHASH="${input:-$TXHASH}"
  # Trim whitespace.

  TXHASH="$(echo -e "${TXHASH}" | tr -d '[:space:]' | sed 's/\://g' | sed 's/\"//g' | sed 's/,//g' | sed 's/txhash//g')"
  MYLENGTH=$(printf "%s" "${TXHASH}" | wc -m)

  if [ "${MYLENGTH}" -eq 64 ] || [ -z "${TXHASH}" ]
  then
    break
  else
    echo "${TXHASH} is not 64 characters long."
  fi
done

# Ask for outputidx.
if [[ ${TXHASH} ]]; then
  while :
  do
    read -r -e -i "${OUTPUTIDX}" -p "outputidx: " input
    OUTPUTIDX="${input:-$OUTPUTIDX}"
    # Trim whitespace.
    OUTPUTIDX="$(echo -e "${OUTPUTIDX}" | tr -d '[:space:]' | sed 's/\://g' | sed 's/\"//g' | sed 's/outputidx//g' | sed 's/outidx//g' | sed 's/,//g')"

    if [ "${OUTPUTIDX}" -eq 0 ] || [ "${OUTPUTIDX}" -eq 1 ] || [ "${OUTPUTIDX}" -eq 2 ] || [ "${OUTPUTIDX}" -eq 3 ] || [ "${OUTPUTIDX}" -eq 4 ] || [ "${OUTPUTIDX}" -eq 5 ] || [ "${OUTPUTIDX}" -eq 6 ]
    then
      break
    else
      echo "${OUTPUTIDX} is not a 0, 1, 2, 3, 4, 5 or a 6."
    fi
  done
fi

echo
prettySection "Step 3: Review installation settings to be used"
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

REPLY='y'
#echo "Full string to paste into masternode.conf will be shown at the end of the setup script"
echo
#echo -e "\\e[4mPress Enter to continue\\e[0m"
read -r -p $'Use given defaults \e[7m(y/n)\e[0m? ' -e -i "${REPLY}" input
REPLY="${input:-$REPLY}"

if [[ $REPLY =~ ^[Nn] ]]; then
  # Create new user mn1.
  echo
  echo "If you are unsure about what to type in, press enter to select the default."
  echo

  # Ask for username.
  while :
  do
    read -r -e -i "${USER_NAME}" -p "Username (lowercase): " input
    USER_NAME="${input:-$USER_NAME}"
    # Convert to lowercase.
    USER_NAME=$(echo "${USER_NAME}" | awk '{print tolower($0)}')

    if id "${USER_NAME}" >/dev/null 2>&1; then
      echo "User ${USER_NAME} already exists."
    else
      break
    fi
  done

  # Get IPv4 public address.
  while :
  do
    read -r -e -i "${PUBLIC_IP}" -p "Public IPv4 Address: " input
    PUBLIC_IP="${input:-$PUBLIC_IP}"
    if isValidIp "${PUBLIC_IP}"
    then
      break;
    else
      echo "${PUBLIC_IP} is not a valid IP"
      PUBLIC_IP="$(wget -qO- -o- ipinfo.io/ip)"
    fi
  done

  # Get IPv4 private address.
  if [ "${PUBLIC_IP}" != "${PRIVATE_IP}" ]
  then
    if [ "${PRIVATE_IP}" == "0" ]
    then
      PRIVATE_IP="${PUBLIC_IP}"
    fi
    while :
    do
      read -r -e -i "${PRIVATE_IP}" -p "Private IPv4 Address: " input
      PRIVATE_IP="${input:-$PRIVATE_IP}"
      if isValidIp "${PRIVATE_IP}"
      then
        break;
      else
        echo "${PRIVATE_IP} is not a valid IP"
        PRIVATE_IP="$(ip route get 8.8.8.8 | sed 's/ uid .*//' | awk '{print $NF; exit}')"
      fi
    done
  fi

  # Get port if user want's to supply one.
  echo
  echo "Recommended you leave this blank to have script pick a free port automatically"
  while :
  do
    read -r -e -i "${PORTB}" -p "Port: " input
    PORTB="${input:-$PORTB}"
    if [ -z "${PORTB}" ]
    then
      break
    else
      #PORTB=$(STRING_TO_INT "${PORTB}" 2>/dev/null)
      if isValidPort "${PORTB}"
      then
        break
      else
        PORTB=''
      fi
    fi
  done

  # Get private key if user want's to supply one.
  echo
  echo "Recommend you leave this blank to have script automatically generate one"
  read -r -e -i "${MN_KEY}" -p "masternodeprivkey: " input
  MN_KEY="${input:-$MN_KEY}"
else
  echo "Using the above default values."
fi

echo
echo "Starting the ${COIN_NAME} install process; please wait for this to finish."
echo "Script will end when you see the big string to add to masternode.conf"
echo "Let the script run and keep your terminal open"
echo
read -r -t 10 -p "Hit ENTER to continue or wait 10 seconds"
echo

prettySection "Step 4: Updating System Software"
# Update the system.
DEBIAN_FRONTEND=noninteractive apt-get install -yq libc6 software-properties-common
DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
#DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
#apt-get -f install -y
DEBIAN_FRONTEND=noninteractive apt-get -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
apt-get -f install -y &
waitOnProgram "Updating system. This may take several minutes"


prettySection "Step 5: Installing bitcoin's libdb4.8"
# Install bitcoin repo and get older db code from there.
echo | add-apt-repository ppa:bitcoin/bitcoin
apt-get update
apt-get install -y libdb4.8-dev libdb4.8++-dev

# Add in older boost files if needed.
if [ ! -f /usr/lib/x86_64-linux-gnu/libboost_system.so.1.58.0 ]; then
  # Add in 16.04 repo.
  echo "deb http://archive.ubuntu.com/ubuntu/ xenial-updates main restricted" >> /etc/apt/sources.list
  apt-get update

  # Install old boost files.
  apt-get install -y libboost-system1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 libboost-thread1.58.0
fi


prettySection "Step 6: Installing Security Software"
# Make sure certain programs are installed.
apt-get install screen curl htop gpw unattended-upgrades jq bc pwgen libminiupnpc10 ufw lsof util-linux gzip denyhosts procps unzip

if [ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
  # Enable auto updating of Ubuntu security packages.
  printf 'APT::Periodic::Enable "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
' > /etc/apt/apt.conf.d/20auto-upgrades
fi

# Force run unattended upgrade to get everything up to date.
echo
unattended-upgrade &
waitOnProgram  "Upgrading software dependencies. This may take up to 15 minutes."

# Update system clock.
timedatectl set-ntp off
timedatectl set-ntp on
# Increase open files limit.
ulimit -n 4096

# Turn on firewall, only allow port 22.
ufw limit 22
ufw allow 123
echo "y" | ufw enable
ufw reload

if [ ! -f "/swapfile_${USER_NAME}"  ]; then
  fallocate -l 256M "/swapfile_${USER_NAME}"
  chmod 600 "/swapfile_${USER_NAME}"
  mkswap "/swapfile_${USER_NAME}"
  swapon "/swapfile_${USER_NAME}"
  echo "/swapfile_${USER_NAME} none swap defaults 0 0" >> /etc/fstab
fi

clear
echo "System upgrade completed. Preparing masternode installation now"
echo
prettySection "Step 7: Masternode Installation"

# Set new user mn1 password to a big string.
useradd -m "${USER_NAME}" -s /bin/bash
if ! [ -x "$(command -v pwgen)" ]
then
  USERPASS=$(openssl rand -hex 36)
  echo "${USER_NAME}:${USERPASS}" | chpasswd
else
  USERPASS=$(pwgen -1 -s 44)
  echo "${USER_NAME}:${USERPASS}" | chpasswd
fi

## TODO: Grab this off of the auto-refreshed compiled results of all the monitored mn owners
ADDNODES=`printf '

'`

# Good starting point is the home dir.
cd ~/ || exit

prettySection "Step A: **** downloading"
# Download and extract binary
curl -L ${COIN_APP_URL} -o artifact
mkdir -p /tmp/extract
${EXTRACT_CMD}

# Copy binary to user home directory
prettySection "Step A: **** installing"
mkdir -p /home/${USER_NAME}/.local/bin
find /tmp/extract -type f | xargs chmod 755
find /tmp/extract -type f -exec mv -- "{}" /home/${USER_NAME}/.local/bin \;
rm -rf /tmp/extract
chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.local

prettySection "Step B: **** finding port"
# Find open port.
echo "Searching for an unused port"
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
server=1
daemon=1
txindex=1
port=${PORTB}
externalip=${PUBLIC_IP}:${PORTB}
masternode=0
masternodeprivkey=
masternodeaddr=${PRIVATE_IP}:${PORTB}
" > "/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE}"

echo ${ADDNODES} | tr " " "\\n" >> "/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE}"

coinStart

# TODO: Monitor connection count and wait for it to be 6 or more. Can only do that after the addnodes TODO is handled though as this can take ages otherwise

# Generate key and stop master node.
if [ -z "${MN_KEY}" ]; then
  MN_KEY=$(/home/${USER_NAME}/.local/bin/${COIN_CLI} -datadir=/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/ masternode genkey)
  if [ -z "${MN_KEY}" ]; then
    echo "Unable to generate KEY for masternode. Terminating script"
    exit 1
  fi
fi
coinStop


printf "rpcuser=rpc_${USER_NAME}
rpcpassword=${PWA}
rpcallowip=127.0.0.1
rpcport=${PORTA}
server=1
daemon=1
txindex=1
port=${PORTB}
externalip=${PUBLIC_IP}:${PORTB}
masternode=1
masternodeprivkey=${MN_KEY}
" > "/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE}"

echo ${ADDNODES} | tr " " "\\n" >> "/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_CONFIG_FILE}"


prettySection "Step 8: Bootstrapping Masternode for quicker usage"
# Monitor block count and wait for it to be caught up.
if [ -z "$var" ]
then
      echo "\$BOOTSTRAP_URL is empty"
else
      coinBootstrap
fi


prettySection "Step 9: Setting up System Services"
# Setup systemd to start masternode on restart.
printf "[Unit]
Description=${COIN_NAME} Masternode for user ${USER_NAME}
After=network.target

[Service]
Type=forking
User=${USER_NAME}
WorkingDirectory=/home/${USER_NAME}
PIDFile=/home/${USER_NAME}/${COIN_CONFIG_FOLDER}/${COIN_NAME}.pid
ExecStart=/home/${USER_NAME}/.local/bin/${COIN_DAEMON} --daemon
ExecStop=/home/${USER_NAME}/.local/bin/${COIN_CLI} stop
Restart=always
RestartSec=30s
TimeoutSec=30s

[Install]
WantedBy=multi-user.target" > "/etc/systemd/system/${USER_NAME}.service"

# Run master node.
prettySection "Step C: **** starting node"
systemctl daemon-reload
systemctl enable "${USER_NAME}"
sleep 1
systemctl start "${USER_NAME}"
sleep 1

clear

# Output info.
systemctl status --no-pager --full "${USER_NAME}"
sleep 2
echo
ufw status
sleep 4
echo


until su -c "home/${USER_NAME}/.local/bin/${COIN_CLI} getblockcount | grep curl https://fantasygold.network/api/getblockcount" $USER; do
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

prettySection "Step 10: Setup Complete. Document the below information"
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
