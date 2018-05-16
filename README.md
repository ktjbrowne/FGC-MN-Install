## Firstly, Is Your Wallet Setup Correctly?

At this stage, you should have your local wallet fully installed and configured as per this tutorial.
```
https://github.com/ktjbrowne/FGC-Wallet-Install
```
Additionally, you should have all your coins in your wallet, including those required for a Masternode.
If you have not followed this process, please double check you have all required conifgs.

## STEP 1 : Local Wallet Masternode Funding

We preform these actions on your local wallet which is now fully setup.
  (These steps are NOT preformed on the VPS Masternode)

* First, we will do the initial collateral TX and send exactly 10000 FGC to one of our addresses. To keep things sorted in case we setup more masternodes we will label the addresses we use.

  - Open your FGC wallet and switch to the "Receive" tab.

  - Click into the label field and create a label, I will use MN1

  - Now click on "Request payment"

  - The generated address will now be labelled as MN1 If you want to setup more masternodes just repeat the steps so you end up with several addresses for the total number of nodes you wish to setup. Example: For 10 nodes you will need 10 addresses, label them all.

  - Once all addresses are created send 10000 FGC each to them. Ensure that you send exactly 10000 FGC and do it in a single transaction. You can double check where the coins are coming from by checking it via coin control usually, that's not an issue.

* As soon as all transactions are done, we will wait for 15 confirmations. You can check this in your wallet or use the explorer. It should take around 30 minutes if all transaction have 15 confirmations

## STEP 2 : Local Wallet Masternode Setup

Generate your Masternode Private Key

In your wallet, open Tools -> Debug console and run the following command to get your masternode key:

```bash
masternode genkey
```

Please note: If you plan to set up more than one masternode, you need to create a key with the above command for each one.

Run this command to get your output information:

```bash
masternode outputs
```

Copy both the key and output information to a text file.

Close your wallet and open the FantasyGold Appdata folder. Its location depends on your OS.

* **Windows:** Press Windows+R and write %appdata% - there, open the folder FantasyGold. 
  * Alternatively on your wallet, goto Menu, select Tool and "Open Masternode Configuration File".
* **macOS:** Press Command+Space to open Spotlight, write ~/Library/Application Support/FantasyGold and press Enter.  
  * Alternatively on your wallet, goto Menu, select Tool and "Open Masternode Configuration File".
* **Linux:** Open ~/.fantasygold

If not already open, in your appdata folder, open masternode.conf with a text editor and add a new line in this format to the bottom of the file:

```bash
masternodename ipaddress:57810 genkey collateralTxID outputID
```
It is critical your ManternodeName and TxID are matching if using multiple MN Addresses.
An example would be

```
mn1 127.0.0.2:57810 93HaYBVUCYjEMeeH1Y4sBGLALQZE1Yc1K64xiqgX37tGBDQL8Xg 2bcd3c84c84f87eaa86e4e56834c92927a07f9e18718810b92e0d0324456a67c 0
```

_masternodename_ is a name you choose, _ipaddress_ is the public IP of your VPS, masternodeprivatekey is the output from `masternode genkey`, and _collateralTxID_ & _outputID_ come from `masternode outputs`. Please note that _masternodename_ must not contain any spaces, and should not contain any special characters.

Restart and unlock your wallet, you should see your disabled MNs listed in the Masternode Tab in the wallet.

## STEP 3 : VPS MasterNode Configuration
## System requirements

The VPS you plan to install your masternode on needs to have at least 1GB of RAM and 10GB of free disk space. We do not recommend using servers who do not meet those criteria, and your masternode will not be stable.

Most people are using Vultr Servers
Location: Any
Type: 64bit Ubuntu 17.10
Size: $5 per month
(give your server a name, ie FGC-MN-1)
Start the server.

## Installation & Setting up your Server

SSH (Putty on Windows, Terminal.app on macOS) to your VPS.
  (meaning connect to your server throught an old DOS like command window)

Windows users can download Putty here: 
```
  https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
```

login as root (**Please note:** It's normal that you don't see your password after typing or pasting it) and run the following command:

```bash
bash <( curl https://raw.githubusercontent.com/FantasyGold/FGC-MN-Install/master/install.sh )
```

When the script asks, confirm your VPS IP Address and paste your masternode key (You can copy your key and paste into the VPS if connected with Putty by right clicking)

The installer will then present you with a few options.

**PLEASE NOTE**: Do not choose the advanced installation option unless you have experience with Linux and know what you are doing - if you do and something goes wrong, the fantasygold team CANNOT help you, and you will have to restart the installation.

Options:
Install using Advanced = n
Confirm the IP Address of your VPS (it should already display and be correct, just hit enter to continue)
Paste a unique Private Key generated from your local wallet when you ran genkey command in console, hit enter.
Install Fail2ban? = y
Install UFW and configure ports? = y

Sit back, relax, some dependancies will now install and the Masternode will configure.
This can take 10 or 15 minutes depending.

When prompted to Start your MN from your Local Wallet please do.
You can do this by right clicking the MasterNode in your wallets list and hitting start.
Occasionally this will fail for an IP error.
If a failure happens, open a command prompt on your local system where you have your fantasygold.exe and fantasygold-cli.exe files.
run the following command:

```
fantasygold-cli startmasternode alias lockwallet "YOUR-MN-NAME"
```
The MN should state its started.

Click continue in the VPS Console window..

After the basic installation is done, the wallet will sync. You will see the following message:

```
Your masternode is syncing. Please wait for this process to finish.
CTRL+C to exit the masternode sync once you see the MN ENABLED in your local wallet.
```

Once its fully synced copy and paste this command
```
fantasygold-cli startmasternode local false
```
Continue to attempt the above command intermittently until syncing is complete.
Once you see "Masternode setup completed." on screen, you are done.
then
```
fantasygold-cli masternode status
```


## Refreshing Node

If your masternode is stuck on a block or behaving badly, you can refresh it.
Please note that this script must be run as root.

```
bash <( curl https://raw.githubusercontent.com/FantasyGold/FGC-MN-Install/master/refresh_node.sh )
```

No other attention is required.

## Updating Node

To update your node please run this command and follow the instructions.
Please note that this script must be run as root.

```
bash <( curl https://raw.githubusercontent.com/FantasyGoldCoin/FGC-MN-Install/master/update_node.sh )
```
