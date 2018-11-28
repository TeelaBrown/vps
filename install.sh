#!/bin/bash
#  ███╗   ██╗ ██████╗ ██████╗ ███████╗███╗   ███╗ █████╗ ███████╗████████╗███████╗██████╗
#  ████╗  ██║██╔═══██╗██╔══██╗██╔════╝████╗ ████║██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗
#  ██╔██╗ ██║██║   ██║██║  ██║█████╗  ██╔████╔██║███████║███████╗   ██║   █████╗  ██████╔╝
#  ██║╚██╗██║██║   ██║██║  ██║██╔══╝  ██║╚██╔╝██║██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗
#  ██║ ╚████║╚██████╔╝██████╔╝███████╗██║ ╚═╝ ██║██║  ██║███████║   ██║   ███████╗██║  ██║
#  ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
#                                                              ╚╗ @marsmensch 2016-2018 ╔╝                   				
#                   
# version 	v0.9.4
# date    	2018-04-04
#
# function:	part of the masternode scripts, source the proper config file
#
# 	Instructions:
#               Run this script w/ the desired parameters. Leave blank or use -h for help.
#
#	Platforms:
#               - Linux Ubuntu 16.04 LTS ONLY on a Vultr, Hetzner or DigitalOcean VPS
#               - Generic Ubuntu support will be added at a later point in time
#
# Twitter 	@marsmensch

# Useful variables
declare -r CRYPTOS=`ls -l config/ | egrep '^d' | awk '{print $9}' | xargs echo -n; echo`
declare -r DATE_STAMP="$(date +%y-%m-%d-%s)"
declare -r SCRIPTPATH=$( cd $(dirname ${BASH_SOURCE[0]}) > /dev/null; pwd -P )
declare -r MASTERPATH="$(dirname "${SCRIPTPATH}")"
declare -r SCRIPT_VERSION="v0.9.4"
declare -r SCRIPT_LOGFILE="/tmp/nodemaster_${DATE_STAMP}_out.log"
declare -r IPV4_DOC_LINK="https://www.vultr.com/docs/add-secondary-ipv4-address"
declare -r DO_NET_CONF="/etc/network/interfaces.d/50-cloud-init.cfg"

function showbanner() {
cat << "EOF"
 ███╗   ██╗ ██████╗ ██████╗ ███████╗███╗   ███╗ █████╗ ███████╗████████╗███████╗██████╗
 ████╗  ██║██╔═══██╗██╔══██╗██╔════╝████╗ ████║██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗
 ██╔██╗ ██║██║   ██║██║  ██║█████╗  ██╔████╔██║███████║███████╗   ██║   █████╗  ██████╔╝
 ██║╚██╗██║██║   ██║██║  ██║██╔══╝  ██║╚██╔╝██║██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗
 ██║ ╚████║╚██████╔╝██████╔╝███████╗██║ ╚═╝ ██║██║  ██║███████║   ██║   ███████╗██║  ██║
 ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
                                                             ╚╗ @marsmensch 2016-2018 ╔╝
EOF
}

# /*
# confirmation message as optional parameter, asks for confirmation
# get_confirmation && COMMAND_TO_RUN or prepend a message
# */
#
function get_confirmation() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

#
# /* no parameters, displays the help message */
#
function show_help(){
    clear
    showbanner
    echo "install.sh, version $SCRIPT_VERSION";
    echo "Usage example:";
    echo "install.sh (-p|--project) string [(-h|--help)] [(-n|--net) int] [(-c|--count) int] [(-r|--release) string] [(-w|--wipe)] [(-u|--update)] [(-x|--startnodes)]";
    echo "Options:";
    echo "-h or --help: Displays this information.";
    echo "-p or --project string: Project to be installed. REQUIRED.";
    echo "-n or --net: IP address type t be used (4 vs. 6).";
    echo "-c or --count: Number of masternodes to be installed.";
    echo "-r or --release: Release version to be installed.";
    echo "-s or --sentinel: Add sentinel monitoring for a node type. Combine with the -p option";
    echo "-w or --wipe: Wipe ALL local data for a node type. Combine with the -p option";
    echo "-u or --update: Update a specific masternode daemon. Combine with the -p option";
    echo "-r or --release: Release version to be installed.";
	echo "-x or --startnodes: Start masternodes after installation to sync with blockchain";
    exit 1;
}

#
# /* no parameters, checks if we are running on a supported Ubuntu release */
#
function check_distro() {
	# currently only for Ubuntu 16.04
	if [[ -r /etc/os-release ]]; then
		. /etc/os-release
		if [[ "${VERSION_ID}" != "16.04" ]]; then
			echo "This script only supports ubuntu 16.04 LTS, exiting."
			exit 1
		fi
	else
		# no, thats not ok!
		echo "This script only supports ubuntu 16.04 LTS, exiting."
		exit 1
	fi
}

#
# /* no parameters, installs the base set of packages that are required for all projects */
#

# Script to Harden Security on Ubuntu
# I got a several ideas and commands for this script from AMega's VPS hardening script which I found
# on Github seemingly abandoned; and I am very happy to pick up and finish the work.
# 
# ###### SECTIONS ######
# 1. UPDATE AND UPGRADE / update operating system & pkgs
# 2. USER SETUP / add new sudo user, copy SSH keys
# 3. SSH CONFIG / change SSH port, disable root login
# 4. UFW CONFIG / UFW - add rules, harden, enable firewall
# 5. HARDENING / before rules, secure shared memory, etc
# 6. KSPLICE INSTALL / automatically update without reboot
# 7. MOTD EDIT / replace boring banner with customized one
# 8. RESTART SSHD / apply settings by restarting systemctl
# 9. INSTALL COMPLETE / display new SSH and login info

# Add to log command and display output on screen
# echo " `date +%d.%m.%Y" "%H:%M:%S` : $MESSAGE" | tee -a "$LOGFILE"
# Add to log command and do not display output on screen
# echo " `date +%d.%m.%Y" "%H:%M:%S` : $MESSAGE" >> $LOGFILE 2>&1

# write to log only, no output on screen # echo  -e "---------------------------------------------------- " >> $LOGFILE 2>&1
# write to log only, no output on screen # echo  -e "    ** This entry gets written to the log file directly. **" >> $LOGFILE 2>&1
# write to log only, no output on screen # echo  -e "---------------------------------------------------- \n" >> $LOGFILE 2>&1

### add colors ###
lightred='\033[1;31m'  # light red
red='\033[0;31m'  # red
lightgreen='\033[1;32m'  # light green
green='\033[0;32m'  # green
lightblue='\033[1;34m'  # light blue
blue='\033[0;34m'  # blue
lightpurple='\033[1;35m'  # light purple
purple='\033[0;35m'  # purple
lightcyan='\033[1;36m'  # light cyan
cyan='\033[0;36m'  # cyan
lightgray='\033[0;37m'  # light gray
white='\033[1;37m'  # white
brown='\033[0;33m'  # brown
yellow='\033[1;33m'  # yellow
darkgray='\033[1;30m'  # dark gray
black='\033[0;30m'  # black
nocolor='\033[0m'    # no color

# Used this while testing color output
# printf " ${lightred}Light Red${nocolor}\n"
# printf " ${red}Red${nocolor}\n"
# printf " ${lightgreen}Light Green${nocolor}\n"
# printf " ${green}Green${nocolor}\n"
# printf " ${lightblue}Light Blue${nocolor}\n"
# printf " ${blue}Blue${nocolor}\n"
# printf " ${lightpurple}Light Purple${nocolor}\n"
# printf " ${purple}Purple${nocolor}\n"
# printf " ${lightcyan}Light Cyan${nocolor}\n"
# printf " ${cyan}Cyan${nocolor}\n"
# printf " ${lightgray}Light Gray${nocolor}\n"
# printf " ${white}White${nocolor}\n"
# printf " ${lightbrown}Brown${nocolor}\n"
# printf " ${yellow}Yellow${nocolor}\n"
# printf " ${darkgray}Dark Gray${nocolor}\n"
# printf " ${black}Black${nocolor}\n"
# figlet " hello $(whoami)" -f small

printf "${lightred}"
printf "${red}"
printf "${lightgreen}"
printf "${green}"
printf "${lightblue}"
printf "${blue}"
printf "${lightpurple}"
printf "${purple}"
printf "${lightcyan}"
printf "${cyan}"
printf "${lightgray}"
printf "${white}"
printf "${lightbrown}"
printf "${yellow}"
printf "${darkgray}"
printf "${black}"
printf "${nocolor}"

clear
# Set Vars
LOGFILE='/var/log/server_hardening.log'
SSHDFILE='/etc/ssh/sshd_config'

# Create Log File and Begin
	# echo -e "\n" >> $LOGFILE 2>&1
	rm /var/log/server_hardening.log
	printf "${lightcyan}"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e " `date +%d.%m.%Y_%H:%M:%S` : SCRIPT STARTED SUCCESSFULLY " | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e "------- AKcryptoGUY's VPS Hardening Script --------- " | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
	
##########################
## 1. UPDATE & UPGRADE ###
##########################

function update_upgrade() {

# NOTE I learned the hard way that you must put a "\" BEFORE characters "\" and "`"
echo -e "${lightcyan}"
printf "  ___  ____    _   _           _       _ \n" | tee -a "$LOGFILE"
printf " / _ \/ ___|  | | | |_ __   __| | __ _| |_ ___ \n" | tee -a "$LOGFILE"
printf "| | | \\___ \\  | | | | '_ \\ / _\` |/ _\` | __/ _ \\ \n" | tee -a "$LOGFILE"
printf "| |_| |___) | | |_| | |_) | (_| | (_| | ||  __/ \n" | tee -a "$LOGFILE"
printf " \___/|____/   \___/| .__/ \__,_|\__,_|\__\___| \n" | tee -a "$LOGFILE"
printf "                    |_| \n"
printf "${yellow}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : INITIATING SYSTEM UPDATE " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${white}"
	# remove grub to prevent interactive user prompt: https://tinyurl.com/y9pu7j5s
	echo '# rm /boot/grub/menu.lst     (prevent update issue)' | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
 	rm /boot/grub/menu.lst
 	echo '# update-grub-legacy-ec2 -y  (prevent update issue)' | tee -a "$LOGFILE"
	echo -e "--------------------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
 	update-grub-legacy-ec2 -y | tee -a "$LOGFILE"
	printf "${white}"
	echo '# apt-get -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true update' | tee -a "$LOGFILE"
	echo -e "--------------------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
	apt-get -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true update | tee -a "$LOGFILE"
	printf "${white}"
	echo -e "----------------------------------------------------------------------------- " | tee -a "$LOGFILE"
	echo ' # apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install figlet' | tee -a "$LOGFILE"
	printf "${nocolor}"
	apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install figlet | tee -a "$LOGFILE"
	printf "${lightgreen}"
	echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e " `date +%d.%m.%Y_%H:%M:%S` : SYSTEM UPDATED SUCCESSFULLY " | tee -a "$LOGFILE"
	echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"

	printf "${cyan}"
	figlet System Upgrade | tee -a "$LOGFILE"
	printf "${yellow}"
	echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e " `date +%d.%m.%Y_%H:%M:%S` : INITIATING SYSTEM UPGRADE " | tee -a "$LOGFILE"
	echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${white}"
	echo ' # apt-get upgrade -y' | tee -a "$LOGFILE"
	# the next line seemed to break it so I install without new-pkgs
	# echo ' # apt-get --with-new-pkgs upgrade -y' | tee -a "$LOGFILE"
	echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
	apt-get upgrade -y | tee -a "$LOGFILE"
printf "${lightgreen}"	
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : SYSTEM UPGRADED SUCCESSFULLY " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${nocolor}"
}

#
#  PROMPT WHETHER USER WANTS TO INSTALL FAVORED PACKAGES OR ALSO ADD THEIR OWN CUSTOM PACKAGES
#

function favored_packages() {
# install my favorite and commonly used packages
printf "${lightcyan}"
figlet Install Favored | tee -a "$LOGFILE"
printf "${yellow}"
echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : INSTALLING FAVORED PACKAGES " | tee -a "$LOGFILE"
echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${white}"
	echo ' # apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install ' | tee -a "$LOGFILE"
	echo '   htop nethogs ufw fail2ban wondershaper glances ntp figlet lsb-release ' | tee -a "$LOGFILE"
	echo '   update-motd unattended-upgrades secure-delete' | tee -a "$LOGFILE"
	echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
	apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install \
	htop nethogs ufw fail2ban wondershaper glances ntp figlet lsb-release \
	update-motd unattended-upgrades secure-delete | tee -a "$LOGFILE"
printf "${lightgreen}"
echo -e "----------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : FAVORED INSTALLED SUCCESFULLY " | tee -a "$LOGFILE"
echo -e "----------------------------------------------------- " | tee -a "$LOGFILE"
printf "${nocolor}"
}

#
#  PROMPT WHETHER USER WANTS TO INSTALL COMMON CRYPTO PACKAGES TO SAVE TIME LATER
#

function crypto_packages() {
# install development and build packages that are common on all cryptos
printf "${lightcyan}"
figlet Install Crypto | tee -a "$LOGFILE"
printf "${yellow}"
echo -e "-------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : INSTALLING CRYPTO PACKAGES " | tee -a "$LOGFILE"
echo -e "-------------------------------------------------- " | tee -a "$LOGFILE"
printf "${white}"
	echo ' # add-apt-repository -yu ppa:bitcoin/bitcoin' | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
	add-apt-repository -yu ppa:bitcoin/bitcoin | tee -a "$LOGFILE"
	printf "${white}"
	echo -e "---------------------------------------------------------------------- " | tee -a "$LOGFILE"
	echo ' # apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install ' | tee -a "$LOGFILE"
	echo '   protobuf-compiler libboost-all-dev autotools-dev ' | tee -a "$LOGFILE"
        echo '   automake libcurl4-openssl-dev libboost-all-dev libssl-dev ' | tee -a "$LOGFILE"
        echo '   make autoconf automake libtool git apt-utils libprotobuf-dev ' | tee -a "$LOGFILE"
        echo '   libcurl3-dev libudev-dev libqrencode-dev bsdmainutils ' | tee -a "$LOGFILE"
        echo '   libgmp3-dev libevent-dev jp2a pv virtualenv build-essential ' | tee -a "$LOGFILE"
	echo '   libdb++-dev pkg-config libssl-dev g++ ' | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
	apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install \
	protobuf-compiler libboost-all-dev autotools-dev \
        automake libcurl4-openssl-dev libboost-all-dev libssl-dev \
        make autoconf automake libtool git apt-utils libprotobuf-dev \
        libcurl3-dev libudev-dev libqrencode-dev bsdmainutils \
        libgmp3-dev libevent-dev jp2a pv virtualenv build-essential \
        libdb++-dev pkg-config libssl-dev g++ \
	jp2a pv virtualenv | tee -a "$LOGFILE"
# need more testing to see if autoremove breaks the script or not
# apt autoremove -y | tee -a "$LOGFILE"
clear
printf "${lightgreen}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : CRYPTO INSTALLED SUCCESFULLY " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${nocolor}"
}

####################
## 2. USER SETUP ###
####################
#skipped as nodemaster does this

#################### 
##  3. SSH CONFIG ##
####################

function collect_sshd() {
# Prompt for custom SSH port between 11000 and 65535
printf "${lightcyan}"
figlet SSH Config | tee -a "$LOGFILE"
printf "${nocolor}"
SSHPORTWAS=$(sed -n -e '/^Port /p' $SSHDFILE)
printf "${yellow}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : CONFIGURE SSH SETTINGS " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " --> Your current SSH port number is ${SSHPORTWAS} <-- " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- \n" | tee -a "$LOGFILE"
printf "${nocolor}"
	printf "${lightcyan}"
	echo -e " By default, SSH traffic occurs on port 22, so hackers are always"
	echo -e " scanning port 22 for vulnerabilities. If you change your server to"
	echo -e " use a different port, you gain some security through obscurity.\n"
	while :; do
		printf "${cyan}"
		read -p " Enter a custom port for SSH between 11000 and 65535 or use 22: " SSHPORT
		[[ $SSHPORT =~ ^[0-9]+$ ]] || { printf "${lightred}";echo -e " --> Try harder, that's not even a number. \n";printf "${nocolor}";continue; }
		if (($SSHPORT >= 11000 && $SSHPORT <= 65535)); then break
		elif [ $SSHPORT = 22 ]; then break
		else printf "${lightred}"
			echo -e " --> That number is out of range, try again. \n"
			echo "---------------------------------------------------- " >> $LOGFILE 2>&1
			echo " `date +%d.%m.%Y_%H:%M:%S` : ERROR: User entered: $SSHPORT " >> $LOGFILE 2>&1
			echo "---------------------------------------------------- " >> $LOGFILE 2>&1
			printf "${nocolor}"
		fi
	done
		# Take a backup of the existing config
		BTIME=$(date +%F_%R)
		cat $SSHDFILE > $SSHDFILE.$BTIME.bak
		echo -e "\n"
		printf "${yellow}"
		echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
		echo -e "     SSH config file backed up to :" | tee -a "$LOGFILE"
		echo -e " $SSHDFILE.$BTIME.bak" | tee -a "$LOGFILE"
        	echo -e "---------------------------------------------------- \n" | tee -a "$LOGFILE"
		printf "${nocolor}"
		sed -i "s/$SSHPORTWAS/Port $SSHPORT/" $SSHDFILE >> $LOGFILE 2>&1
		clear
			# Error Handling
			if [ $? -eq 0 ]
	        	then
	                printf "${lightgreen}"
			echo -e "---------------------------------------------------- "
			echo " `date +%d.%m.%Y_%H:%M:%S` : SUCCESS : SSH port set to $SSHPORT " | tee -a "$LOGFILE"
			echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
			printf "${nocolor}"
			else
			printf "${lightred}"
			echo -e "---------------------------------------------------- "
	                echo -e " ERROR: SSH Port couldn't be changed. Check log file for details."
                	echo -e " `date +%d.%m.%Y_%H:%M:%S` : ERROR: SSH port couldn't be changed " | tee -a "$LOGFILE"
			echo -e "---------------------------------------------------- \n" | tee -a "$LOGFILE"
			printf "${nocolor}"
			fi
			
# Set SSHPORTIS to the final value of the SSH port
SSHPORTIS=$(sed -n -e '/^Port /p' $SSHDFILE)
}

function prompt_rootlogin {
# Prompt use to permit or deny root login
ROOTLOGINP=$(sed -n -e '/^PermitRootLogin /p' $SSHDFILE)
printf "${lightcyan}"
figlet Root Login | tee -a "$LOGFILE"
printf "${yellow}"
echo -e "-------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : CONFIGURE ROOT LOGIN " | tee -a "$LOGFILE"
echo -e "-------------------------------------------- \n" | tee -a "$LOGFILE"
printf "${nocolor}"
if [ -n "${UNAME,,}" ]
then 
	if [ -z "$ROOTLOGINP" ]
        then ROOTLOGINP=$(sed -n -e '/^# PermitRootLogin /p' $SSHDFILE)
        else :
        fi
	printf "${lightcyan}"
	echo -e " If you have a non-root user, you can disable root login to prevent"
	echo -e " anyone from logging into your server remotely as root. This can"
	echo -e " improve security. Disable root login if you don't need it.\n"
	printf "${yellow}"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e " Your root login settings are: " $ROOTLOGINP  | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------- \n" | tee -a "$LOGFILE"
	printf "${cyan}"
        read -p " Would you like to disable root login? y/n  " ROOTLOGIN
	printf "${nocolor}"
	while [ "${ROOTLOGIN,,}" != "yes" ] && [ "${ROOTLOGIN,,}" != "no" ] && [ "${ROOTLOGIN,,}" != "y" ] && [ "${ROOTLOGIN,,}" != "n" ]; do
	echo -e "\n"
	printf "${lightred}"
	read -p " --> I don't understand. Enter 'y' for yes or 'n' for no: " ROOTLOGIN
	printf "${nocolor}"
	done		
	# check if ROOTLOGIN is valid
        if [ "${ROOTLOGIN,,}" = "yes" ] || [ "${ROOTLOGIN,,}" = "y" ]
        then :
		# search for root login and change to no
                sed -i "s/PermitRootLogin yes/PermitRootLogin no/" $SSHDFILE >> $LOGFILE
                sed -i "s/# PermitRootLogin yes/PermitRootLogin no/" $SSHDFILE >> $LOGFILE
                sed -i "s/# PermitRootLogin no/PermitRootLogin no/" $SSHDFILE >> $LOGFILE
	        # Error Handling
                if [ $? -eq 0 ]
                then
                	printf "${lightgreen}"
			echo -e "---------------------------------------------------- " | tee -a "$LOGFILE" 
			echo -e " `date +%d.%m.%Y_%H:%M:%S` : SUCCESS : Root login disabled " | tee -a "$LOGFILE"
			echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
			printf "${nocolor}"
                else
			printf "${lightred}"
                        echo -e "---------------------------------------------------- " | tee -a "$LOGFILE" 
                        echo -e " `date +%d.%m.%Y_%H:%M:%S` : ERROR: Couldn't disable root login" | tee -a "$LOGFILE" 
			echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
			printf "${nocolor}"
                fi
        else  	printf "${yellow}"
		echo -e "------------------------------------------------------------- " | tee -a "$LOGFILE"
		echo "It looks like you want to enable root login; making it so..." | tee -a "$LOGFILE"
                sed -i "s/PermitRootLogin no/PermitRootLogin yes/" $SSHDFILE >> $LOGFILE 2>&1
                sed -i "s/# PermitRootLogin no/PermitRootLogin yes/" $SSHDFILE >> $LOGFILE 2>&1
                sed -i "s/# PermitRootLogin yes/PermitRootLogin yes/" $SSHDFILE >> $LOGFILE 2>&1
		echo -e "------------------------------------------------------------- " | tee -a "$LOGFILE"
		printf "${nocolor}"
        fi
	ROOTLOGINP=$(sed -n -e '/^PermitRootLogin /p' $SSHDFILE)
else 	printf "${yellow}"
	echo -e "---------------------------------------------------- "
	echo " Since you chose not to create a non-root user, "
     	echo " I did not disable root login for obvious reasons."
     	echo -e "---------------------------------------------------- \n"
	echo -e "----------------------------------------------------- " >> $LOGFILE 2>&1
	echo -e " Root login not changed; no non-root user was created " >> $LOGFILE 2>&1
	echo -e "----------------------------------------------------- \n" >> $LOGFILE 2>&1
	printf "${nocolor}"
fi
clear
printf "${yellow}"
echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " Your root login settings are:" $ROOTLOGINP | tee -a "$LOGFILE"
echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"
printf "${nocolor}"
}

function disable_passauth() {
# query user to disable password authentication or not

printf "${lightcyan}"
figlet Pass Auth | tee -a "$LOGFILE"
printf "${yellow}"
echo -e "----------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : PASSWORD AUTHENTICATION " | tee -a "$LOGFILE"
echo -e "----------------------------------------------- \n"
printf "${lightcyan}"
	echo -e " You can log into your server using an RSA public-private key pair or"
	echo -e " a password.  Using RSA keys for login is tremendously more secure"
	echo -e " than just using a password. If you have installed an RSA key-pair"
	echo -e " and use that to login, you should disable password authentication.\n"
printf "${nocolor}"
if [ -n "/root/.ssh/authorized_keys" ]
then
        PASSWDAUTH=$(sed -n -e '/^PasswordAuthentication /p' $SSHDFILE)
                if [ -z "${PASSWDAUTH}" ]
                then PASSWDAUTH=$(sed -n -e '/^# PasswordAuthentication /p' $SSHDFILE)
                else :
                fi
        # Prompt user to see if they want to disable password login
	printf "${yellow}"
	# output to screen
	echo -e "     --------------------------------------------------- "
        echo -e "      Your current password authentication settings are   "
	echo -e "             ** $PASSWDAUTH ** " | tee -a "$LOGFILE"
	echo -e "     --------------------------------------------------- \n"
	# output to log
	echo -e "--------------------------------------------------- " >> $LOGFILE 2>&1
        echo -e " Your current password authentication settings are   " >> $LOGFILE 2>&1
	echo -e "      ** $PASSWDAUTH ** " >> $LOGFILE 2>&1
	echo -e "--------------------------------------------------- \n" >> $LOGFILE 2>&1
	printf "${cyan}"
        read -p " Would you like to disable password login & require RSA key login? y/n  " PASSLOGIN
	printf "${nocolor}"
	while [ "${PASSLOGIN,,}" != "yes" ] && [ "${PASSLOGIN,,}" != "no" ] && [ "${PASSLOGIN,,}" != "y" ] && [ "${PASSLOGIN,,}" != "n" ]; do
	echo -e "\n"
	printf "${lightred}"
	read -p " --> I don't understand. Enter 'y' for yes or 'n' for no: " PASSLOGIN
	printf "${nocolor}"
	done
	echo -e "\n"	
        # check if PASSLOGIN is valid
        if [ "${PASSLOGIN,,}" = "yes" ] || [ "${PASSLOGIN,,}" = "y" ]
        then 	sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" $SSHDFILE >> $LOGFILE
                sed -i "s/# PasswordAuthentication yes/PasswordAuthentication no/" $SSHDFILE >> $LOGFILE
                sed -i "s/# PasswordAuthentication no/PasswordAuthentication no/" $SSHDFILE >> $LOGFILE
                # Error Handling
                if [ $? -eq 0 ]
                then
			printf "${lightgreen}"
			echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
			echo " `date +%d.%m.%Y_%H:%M:%S` : SUCCESS : PassAuth set to NO " | tee -a "$LOGFILE"
			echo -e "---------------------------------------------------- \n" | tee -a "$LOGFILE"
			printf "${nocolor}"
                else
			printf "${lightred}"
			echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
                        echo " `date +%d.%m.%Y_%H:%M:%S` : ERROR: PasswordAuthentication couldn't be changed to no : " | tee -a "$LOGFILE"
			echo -e "---------------------------------------------------- \n" | tee -a "$LOGFILE"
			printf "${nocolor}"
                fi
        else 
		sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" $SSHDFILE | tee -a "$LOGFILE"
                sed -i "s/# PasswordAuthentication no/PasswordAuthentication yes/" $SSHDFILE | tee -a "$LOGFILE"
                sed -i "s/# PasswordAuthentication yes/PasswordAuthentication yes/" $SSHDFILE | tee -a "$LOGFILE"
        fi
else	
	printf "${yellow}"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e " With no RSA key; I can't disable PasswordAuthentication." | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------- \n" | tee -a "$LOGFILE"
	printf "${nocolor}"
fi
	PASSWDAUTH=$(sed -n -e '/^PasswordAuthentication /p' $SSHDFILE)
	printf "${lightgreen}"
	echo -e "-------------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e " `date +%d.%m.%Y_%H:%M:%S` : PASSWORD AUTHENTICATION COMPLETE " | tee -a "$LOGFILE"
	echo -e "-------------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e "    Your PasswordAuthentication settings are now "  | tee -a "$LOGFILE"
	echo -e "        ** $PASSWDAUTH ** " | tee -a "$LOGFILE"
	echo -e "------------------------------------------- \n" | tee -a "$LOGFILE"
	printf "${nocolor}"
clear
printf "${lightgreen}"
echo -e "------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : SSH CONFIG COMPLETE " | tee -a "$LOGFILE"
echo -e "------------------------------------------- " | tee -a "$LOGFILE"
printf "${nocolor}"
}

#################### 
##  4. UFW CONFIG ##
####################
#this is skipped as nodemaster does it


#################### 
## 5. Hardening  ###
####################

function server_hardening() {
# prompt users on whether to harden server or not
printf "${lightcyan}"
figlet Get Hard | tee -a "$LOGFILE"
printf "${yellow}"
echo -e "-------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : QUERY TO HARDEN THE SERVER " | tee -a "$LOGFILE"
echo -e "-------------------------------------------------- \n" | tee -a "$LOGFILE"
printf "${lightcyan}"
echo -e " The next steps are to secure your server's shared memory, prevent"
echo -e " IP spoofing, enable DDOS protection, harden the networking layer, "
echo -e " and enable automatic installation of security updates."
echo -e "\n"
	printf "${cyan}"
	read -p " Would you like to perform these steps now? y/n  " GETHARD
	printf "${nocolor}"
	while [ "${GETHARD,,}" != "yes" ] && [ "${GETHARD,,}" != "no" ] && [ "${GETHARD,,}" != "y" ] && [ "${GETHARD,,}" != "n" ]; do
	echo -e "\n"
	printf "${lightred}"
	read -p " --> I don't understand. Enter 'y' for yes or 'n' for no: " GETHARD
	printf "${nocolor}"
	done
	echo -e "\n"
        # check if GETHARD is valid
        if [ "${GETHARD,,}" = "yes" ] || [ "${GETHARD,,}" = "y" ]
        then
		
# secure shared memory
printf "${yellow}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : SECURING SHARED MEMORY " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${white}"
echo -e ' --> Adding line to bottom of file /etc/fstab'  | tee -a "$LOGFILE"
echo -e ' tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- \n" | tee -a "$LOGFILE"
sleep 2	; #  dramatic pause
# only add line if line does not already exist in /etc/fstab
if grep -q "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" /etc/fstab; then :
else echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' >> /etc/fstab
fi

# prevent IP spoofing
printf "${yellow}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : PREVENTING IP SPOOFING " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${white}"
echo -e " --> Updating /etc/host.conf to include 'nospoof' " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- \n " | tee -a "$LOGFILE"
sleep 2	; #  dramatic pause
cat etc/host.conf > /etc/host.conf

# enable DDOS protection
printf "${yellow}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : ENABLING DDOS PROTECTION " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${white}"
echo -e " Replace /etc/ufw/before.rules with hardened rules " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- \n " | tee -a "$LOGFILE"
sleep 2	; #  dramatic pause
cat etc/ufw/before.rules > /etc/ufw/before.rules

# harden the networking layer
printf "${yellow}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : HARDENING NETWORK LAYER " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${white}"
echo -e " --> Secure /etc/sysctl.conf with hardening rules " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- \n " | tee -a "$LOGFILE"
sleep 2	; #  dramatic pause
cat etc/sysctl.conf > /etc/sysctl.conf

# enable automatic security updates
printf "${yellow}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : ENABLING SECURITY UPDATES " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${white}"
echo -e " Configure system to auto install security updates " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- \n " | tee -a "$LOGFILE"
sleep 2	; #  dramatic pause
cat etc/apt/apt.conf.d/10periodic > /etc/apt/apt.conf.d/10periodic
cat etc/apt/apt.conf.d/50unattended-upgrades > /etc/apt/apt.conf.d/50unattended-upgrades
# consider editing the above 50-unattended-upgrades to automatically reboot when necessary

                # Error Handling
                if [ $? -eq 0 ]
                then 	echo -e " \n" ; clear
			printf "${green}"
			echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
			echo " `date +%d.%m.%Y_%H:%M:%S` : SUCCESS : Server Hardened" | tee -a "$LOGFILE"
			echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
			printf "${nocolor}"
                else	clear
			printf "${lightred}"
                        echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
			echo " `date +%d.%m.%Y_%H:%M:%S` : ERROR: Hardening Failed" | tee -a "$LOGFILE"
			echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
			printf "${nocolor}"
		fi
		
        else :
	clear
	printf "${yellow}"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e " *** User elected not to GET HARD at this time *** " | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
        fi
}

#########################
##  6. Ksplice Install ##
#########################

function ksplice_install() {

# -------> I still need to install an error check after installing Ksplice to make sure \
#          the install completed before moving on the configuration

# prompt users on whether to install Oracle ksplice or not
# install created using https://tinyurl.com/y9klkx2j and https://tinyurl.com/y8fr4duq
# Official page: https://ksplice.oracle.com/uptrack/guide
printf "${lightcyan}"
figlet Ksplice Uptrack | tee -a "$LOGFILE"
printf "${yellow}"
echo -e "---------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : INSTALL ORACLE KSPLICE " | tee -a "$LOGFILE"
echo -e "---------------------------------------------- \n" | tee -a "$LOGFILE"
printf "${lightcyan}"
echo -e " Normally, kernel updates in Linux require a system reboot. Ksplice"
echo -e " Uptrack installs these patches in memoery for Ubuntu and Fedora"
echo -e " Linux so reboots are not needed. It is free for non-commercial use"
echo -e " To minimize server downtime, this is a good thing to install."
echo -e "\n"
printf "${cyan}"
	read -p " Would you like to install Oracle Ksplice Uptrack now? y/n  " KSPLICE
	while [ "${KSPLICE,,}" != "yes" ] && [ "${KSPLICE,,}" != "no" ] && [ "${KSPLICE,,}" != "y" ] && [ "${KSPLICE,,}" != "n" ]; do
	echo -e "\n"
	printf "${lightred}"
	read -p " --> I don't understand. Enter 'y' for yes or 'n' for no: " GETHARD
	printf "${nocolor}"
	done
	echo -e "\n"
        # check if KSPLICE is valid
        if [ "${KSPLICE,,}" = "yes" ] || [ "${KSPLICE,,}" = "y" ]
        then
		
# install ksplice uptrack
printf "${yellow}"
echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : INSTALLING KSPLICE PACKAGES " | tee -a "$LOGFILE"
echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${white}"
	echo ' # apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install ' | tee -a "$LOGFILE"
	echo '   libgtk2-perl consolekit iproute libck-connector0 libcroco3 libglade2-0 ' | tee -a "$LOGFILE"
	echo '   libpam-ck-connector librsvg2-2 librsvg2-common python-cairo ' | tee -a "$LOGFILE"
	echo '   python-dbus python-gi python-glade2 python-gobject-2 ' | tee -a "$LOGFILE"
	echo '   python-gtk2 python-pycurl python-yaml dbus-x11' | tee -a "$LOGFILE"
	echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
	apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install \
	libgtk2-perl consolekit iproute libck-connector0 libcroco3 libglade2-0 \
	libpam-ck-connector librsvg2-2 librsvg2-common python-cairo \
	python-dbus python-gi python-glade2 python-gobject-2 \
	python-gtk2 python-pycurl python-yaml dbus-x11 | tee -a "$LOGFILE"
printf "${yellow}"

echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : KSPLICE PACKAGES INSTALLED" | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " --> Download & install Ksplice package from Oracle " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${nocolor}"
wget -o /var/log/ksplicew1.log https://ksplice.oracle.com/uptrack/dist/xenial/ksplice-uptrack.deb
dpkg --log "$LOGFILE" -i ksplice-uptrack.deb
printf "${yellow}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : KSPLICE UPTRACK INSTALLED" | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " ** Enabling autoinstall & correcting permissions ** " | tee -a "$LOGFILE"
sed -i "s/autoinstall = no/autoinstall = yes/" /etc/uptrack/uptrack.conf
chmod 755 /etc/cron.d/uptrack
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " ** Activate & install Ksplice patches & updates ** " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${nocolor}"
cat $LOGFILE /var/log/ksplicew1.log > /var/log/join.log
cat /var/log/join.log > $LOGFILE
rm /var/log/ksplicew1.log
rm /var/log/join.log
uptrack-upgrade -y | tee -a "$LOGFILE"
printf "${yellow}"
echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : KSPLICE UPDATES INSTALLED" | tee -a "$LOGFILE"
echo -e "------------------------------------------------- \n" | tee -a "$LOGFILE"
printf "${nocolor}"
sleep 1	; #  dramatic pause
clear
printf "${lightgreen}"
echo -e "------------------------------------------------- " | tee -a "$LOGFILE"
echo " `date +%d.%m.%Y_%H:%M:%S` : SUCCESS : Ksplice Enabled" | tee -a "$LOGFILE"
echo -e "------------------------------------------------- \n" | tee -a "$LOGFILE"
printf "${nocolor}"
        else :
	clear
	printf "${yellow}"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e "     ** User elected not to install Ksplice ** " | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------- \n" | tee -a "$LOGFILE"
	printf "${nocolor}"
        fi

# original steps I gathered
# sudo apt-get install libgtk2-perl consolekit iproute libck-connector0 libcroco3 libglade2-0 libpam-ck-connector librsvg2-2 librsvg2-common python-cairo python-dbus python-gi python-glade2 python-gobject-2 python-gtk2 python-pycurl python-yaml dbus-x11 -y
# sudo wget https://ksplice.oracle.com/uptrack/dist/xenial/ksplice-uptrack.deb
# sudo dpkg -i ksplice-uptrack.deb
# sudo sed -i "s/autoinstall = no/autoinstall = yes/" /etc/uptrack/uptrack.conf
# sudo chmod 755 /etc/cron.d/uptrack
# sudo uptrack-upgrade -y
}

#######################
##  7. MOTD Install  ##
#######################

function motd_install() {
# prompt users to install custom MOTD or not
printf "${lightcyan}"
figlet Enhance MOTD | tee -a "$LOGFILE"
printf "${yellow}"
echo -e "--------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : PROMPT USER TO INSTALL MOTD " | tee -a "$LOGFILE"
echo -e "--------------------------------------------------- \n" | tee -a "$LOGFILE"
printf "${lightcyan}"
echo -e " The normal MOTD banner displayed after a successful SSH login"
echo -e " is pretty boring so this mod edits it to include more useful"
echo -e " information along with a login banner prohibiting unauthorized"
echo -e " access.  All modifications are strictly cosmetic."
echo -e "\n"
	printf "${cyan}"
	read -p " Would you like to enhance your MOTD & login banner? y/n  " MOTDP
	printf "${nocolor}"
	while [ "${MOTDP,,}" != "yes" ] && [ "${MOTDP,,}" != "no" ] && [ "${MOTDP,,}" != "y" ] && [ "${MOTDP,,}" != "n" ]; do
	echo -e "\n"
	printf "${lightred}"
	read -p " --> I don't understand. Enter 'y' for yes or 'n' for no: " MOTDP
	printf "${nocolor}"
	done
	echo -e "\n"
        # check if MOTDP is affirmative
        if [ "${MOTDP,,}" = "yes" ] || [ "${MOTDP,,}" = "y" ]
        then
		sudo apt-get -o Acquire::ForceIPv4=true update -y
		sudo apt-get -o Acquire::ForceIPv4=true install lsb-release update-motd curl -y
		rm -r /etc/update-motd.d/
		mkdir /etc/update-motd.d/
		touch /etc/update-motd.d/00-header ; touch /etc/update-motd.d/10-sysinfo ; touch /etc/update-motd.d/90-footer ; touch /etc/update-motd.d/99-esm
		chmod +x /etc/update-motd.d/*
		cat motdcustom/00-header > /etc/update-motd.d/00-header
		cat motdcustom/10-sysinfo > /etc/update-motd.d/10-sysinfo
		cat motdcustom/90-footer > /etc/update-motd.d/90-footer
		cat motdcustom/99-esm > /etc/update-motd.d/99-esm
		sed -i 's,#Banner /etc/issue.net,Banner /etc/issue.net,' /etc/ssh/sshd_config
		cat etc/issue.net > /etc/issue.net
		clear	
		# Error Handling
                if [ $? -eq 0 ]
                then printf "${lightgreen}"
			echo -e "------------------------------------------------------- " | tee -a "$LOGFILE"
				echo " `date +%d.%m.%Y_%H:%M:%S` : SUCCESS : MOTD & Banner updated" | tee -a "$LOGFILE"
				echo -e "------------------------------------------------------- " | tee -a "$LOGFILE"
				printf "${nocolor}"
                else printf "${lightred}"
			echo -e "------------------------------------------------------- " | tee -a "$LOGFILE"
			echo " `date +%d.%m.%Y_%H:%M:%S` : ERROR: MOTD not updated" | tee -a "$LOGFILE"
                	echo -e "------------------------------------------------------- \n" | tee -a "$LOGFILE"
		fi
		
        else echo -e "\n"
	clear
	printf "${yellow}"
	echo -e "----------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e " *** User elected not to customize MOTD & banner *** " | tee -a "$LOGFILE"
	echo -e "----------------------------------------------------- \n" | tee -a "$LOGFILE"
	printf "${nocolor}"
        fi
}

#######################
##  8. Restart SSHD  ##
#######################

function restart_sshd() {
# prompt users to leave this session open, then create a second connection after restarting SSHD to make sure they can connect
printf "${lightcyan}"
figlet Restart SSH | tee -a "$LOGFILE"
printf "${yellow}"
echo -e "-------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " `date +%d.%m.%Y_%H:%M:%S` : PROMPT USER TO RESTART SSH " | tee -a "$LOGFILE"
echo -e "-------------------------------------------------- \n" | tee -a "$LOGFILE"
printf "${lightcyan}"
echo " Changes to login security will not take effect until SSHD restarts"
echo " and firewall is enabled. You should keep this existing connection"
echo " open while restarting SSHD just in case you have a problem or"
echo " copied down the information incorrectly. This will prevent you"
echo " from getting locked out of your server."
echo -e "\n"
	printf "${cyan}"
	read -p " Would you like to restart SSHD and enable UFW now? y/n  " SSHDRESTART
	printf "${nocolor}"
	while [ "${SSHDRESTART,,}" != "yes" ] && [ "${SSHDRESTART,,}" != "no" ] && [ "${SSHDRESTART,,}" != "y" ] && [ "${SSHDRESTART,,}" != "n" ]; do
	echo -e "\n"
	printf "${lightred}"
	read -p " --> I don't understand. Enter 'y' for yes or 'n' for no: " SSHDRESTART
	printf "${nocolor}"
	done
	echo -e "\n"
        # check if SSHDRESTART is valid
        if [ "${SSHDRESTART,,}" = "yes" ] || [ "${SSHDRESTART,,}" = "y" ]
        then
                # insert a pause or delay to add suspense
		systemctl restart sshd
			if [ $FIREWALLP = "yes" ] || [ $FIREWALLP = "y" ]
			then ufw --force enable | tee -a "$LOGFILE"
			echo -e " \n" | tee -a "$LOGFILE"
			else :
			fi			
		# Error Handling
                if [ $? -eq 0 ]
                then 	printf "${lightgreen}"
			echo -e "------------------------------------------------------ " | tee -a "$LOGFILE"
			echo " `date +%d.%m.%Y_%H:%M:%S` : SUCCESS : SSHD restart complete" | tee -a "$LOGFILE"
			echo -e "------------------------------------------------------ " | tee -a "$LOGFILE"	
			printf "${nocolor}"
			if [ $FIREWALLP = "yes" ] || [ $FIREWALLP = "y" ]
			printf "${lightgreen}"
			then echo " `date +%d.%m.%Y_%H:%M:%S` : SUCCESS : UFW firewall enabled" | tee -a "$LOGFILE"
			echo -e "------------------------------------------------------ " | tee -a "$LOGFILE"	
			printf "${nocolor}"
			else :
			fi
                else
                        printf "${lightred}"
			echo -e "------------------------------------------------------ " | tee -a "$LOGFILE"
			echo " `date +%d.%m.%Y_%H:%M:%S` : ERROR: SSHD could not restart" | tee -a "$LOGFILE"
			echo -e "------------------------------------------------------ " | tee -a "$LOGFILE"
                fi
		
        else echo -e "\n"
	printf "$yellow"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	echo -e " *** User elected not to restart SSH at this time *** " | tee -a "$LOGFILE"
	echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
	printf "${nocolor}"
        fi
}

#########################
## 9. Install Complete ##
#########################


function install_complete() {
# Display important login variables before exiting script
clear
printf "${lightcyan}"
figlet Install Complete -f small | tee -a "$LOGFILE"
printf "${lightgreen}"
echo -e "---------------------------------------------------- " >> $LOGFILE 2>&1
echo -e " `date +%d.%m.%Y_%H:%M:%S` : YOUR SERVER IS NOW SECURE " >> $LOGFILE 2>&1
printf "${lightpurple}"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e "  * * * Save these important login variables! * * *  " | tee -a "$LOGFILE"
echo -e "---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${yellow}"
echo -e " --> Your SSH port for remote access is" $SSHPORTIS	| tee -a "$LOGFILE"
echo -e " --> Root login settings are:" $ROOTLOGINP | tee -a "$LOGFILE"
	printf "${white}"
	if [ -n "${UNAME,,}" ] 
	then echo -e " We created a non-root user named (lower case):" ${UNAME,,} | tee -a "$LOGFILE" 
	else echo -e " A new user was not created during the setup process" | tee -a "$LOGFILE" 
	fi
	printf "${nocolor}"
printf "${white}"
echo " PasswordAuthentication settings:" $PASSWDAUTH | tee -a "$LOGFILE"
	printf "${lightcyan}"
	if [ ${FIREWALLP,,} = "yes" ] || [ ${FIREWALLP,,} = "y" ]
	then echo -e " --> UFW was installed and basic firewall rules were added" | tee -a "$LOGFILE" 
	else echo -e " --> UFW was not installed or configured" | tee -a "$LOGFILE" 
	fi
		# if [ "${GETHARD,,}" = "yes" ] || [ "${GETHARD,,}" = "y" ]
		# then echo -e " --> The server and networking layer were hardened <--" | tee -a "$LOGFILE" 
		# else echo -e " --> The server and networking layer were NOT hardened" | tee -a "$LOGFILE" 
		# fi
			printf "${lightcyan}"
			if [ "${KSPLICE,,}" = "yes" ] || [ "${KSPLICE,,}" = "y" ]
			then echo -e " You installed Oracle's Ksplice to update without reboot" | tee -a "$LOGFILE"
			else echo -e " You chose NOT to auto-update OS with Oracle's Ksplice" | tee -a "$LOGFILE"
			fi
printf "${yellow}"
echo -e "-------------------------------------------------------- " | tee -a "$LOGFILE"	
echo -e " Installation log saved to" $LOGFILE | tee -a "$LOGFILE"
echo -e " Before modification, your SSH config was backed up to" | tee -a "$LOGFILE"
echo -e " --> $SSHDFILE.$BTIME.bak"				| tee -a "$LOGFILE"
printf "${lightred}"
echo -e " ---------------------------------------------------- " | tee -a "$LOGFILE"
echo -e " | NOTE: Please create a new connection to test SSH | " | tee -a "$LOGFILE"
echo -e " |       settings before you close this session     | " | tee -a "$LOGFILE"
echo -e " ---------------------------------------------------- " | tee -a "$LOGFILE"
printf "${nocolor}"
}


update_upgrade
favored_packages
crypto_packages
collect_sshd
prompt_rootlogin
disable_passauth
server_hardening
ksplice_install
motd_install
restart_sshd
install_complete


# /* no parameters, creates and activates a swapfile since VPS servers often do not have enough RAM for compilation */
#
function swaphack() {
#check if swap is available
if [ $(free | awk '/^Swap:/ {exit !$2}') ] || [ ! -f "/var/mnode_swap.img" ];then
	echo "* No proper swap, creating it"
	# needed because ant servers are ants
	rm -f /var/mnode_swap.img
	dd if=/dev/zero of=/var/mnode_swap.img bs=1024k count=${MNODE_SWAPSIZE} &>> ${SCRIPT_LOGFILE}
	chmod 0600 /var/mnode_swap.img
	mkswap /var/mnode_swap.img &>> ${SCRIPT_LOGFILE}
	swapon /var/mnode_swap.img &>> ${SCRIPT_LOGFILE}
	echo '/var/mnode_swap.img none swap sw 0 0' | tee -a /etc/fstab &>> ${SCRIPT_LOGFILE}
	echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf               &>> ${SCRIPT_LOGFILE}
	echo 'vm.vfs_cache_pressure=50' | tee -a /etc/sysctl.conf		&>> ${SCRIPT_LOGFILE}
else
	echo "* All good, we have a swap"
fi
}

#
# /* no parameters, creates and activates a dedicated masternode user */
#
function create_mn_user() {

    # our new mnode unpriv user acc is added
    if id "${MNODE_USER}" >/dev/null 2>&1; then
        echo "user exists already, do nothing" &>> ${SCRIPT_LOGFILE}
    else
        echo "Adding new system user ${MNODE_USER}"
        adduser --disabled-password --gecos "" ${MNODE_USER} &>> ${SCRIPT_LOGFILE}
    fi

}

#
# /* no parameters, creates a masternode data directory (one per masternode)  */
#
function create_mn_dirs() {

    # individual data dirs for now to avoid problems
    echo "* Creating masternode directories"
    mkdir -p ${MNODE_CONF_BASE}
	for NUM in $(seq 1 ${count}); do
	    if [ ! -d "${MNODE_DATA_BASE}/${CODENAME}${NUM}" ]; then
	         echo "creating data directory ${MNODE_DATA_BASE}/${CODENAME}${NUM}" &>> ${SCRIPT_LOGFILE}
             mkdir -p ${MNODE_DATA_BASE}/${CODENAME}${NUM} &>> ${SCRIPT_LOGFILE}
        fi
	done

}

#
# /* no parameters, creates a sentinel config for a set of masternodes (one per masternode)  */
#
function create_sentinel_setup() {

	# if code directory does not exists, we create it clone the src
	if [ ! -d /usr/share/sentinel ]; then
		cd /usr/share                                               &>> ${SCRIPT_LOGFILE}
		git clone https://github.com/dashpay/sentinel.git sentinel  &>> ${SCRIPT_LOGFILE}
		cd sentinel                                                 &>> ${SCRIPT_LOGFILE}
		rm -f rm sentinel.conf                                      &>> ${SCRIPT_LOGFILE}
	else
		echo "* Updating the existing sentinel GIT repo"
		cd /usr/share/sentinel        &>> ${SCRIPT_LOGFILE}
		git pull                      &>> ${SCRIPT_LOGFILE}
		rm -f rm sentinel.conf        &>> ${SCRIPT_LOGFILE}
	fi

	# create a globally accessible venv and install sentinel requirements
	virtualenv --system-site-packages /usr/share/sentinelvenv      &>> ${SCRIPT_LOGFILE}
	/usr/share/sentinelvenv/bin/pip install -r requirements.txt    &>> ${SCRIPT_LOGFILE}

    # create one sentinel config file per masternode
	for NUM in $(seq 1 ${count}); do
	    if [ ! -f "/usr/share/sentinel/${CODENAME}${NUM}_sentinel.conf" ]; then
	         echo "* Creating sentinel configuration for ${CODENAME} masternode number ${NUM}" &>> ${SCRIPT_LOGFILE}
		     echo "dash_conf=${MNODE_CONF_BASE}/${CODENAME}_n${NUM}.conf"   > /usr/share/sentinel/${CODENAME}${NUM}_sentinel.conf
             echo "network=mainnet"                                         >> /usr/share/sentinel/${CODENAME}${NUM}_sentinel.conf
             echo "db_name=database/${CODENAME}_${NUM}_sentinel.db"         >> /usr/share/sentinel/${CODENAME}${NUM}_sentinel.conf
             echo "db_driver=sqlite"                                        >> /usr/share/sentinel/${CODENAME}${NUM}_sentinel.conf
        fi
	done

    echo "Generated a Sentinel config for you. To activate Sentinel run"
    echo "export SENTINEL_CONFIG=${MNODE_CONF_BASE}/${CODENAME}${NUM}_sentinel.conf; /usr/share/sentinelvenv/bin/python /usr/share/sentinel/bin/sentinel.py"
    echo ""
    echo "If it works, add the command as cronjob:  "
    echo "* * * * * export SENTINEL_CONFIG=${MNODE_CONF_BASE}/${CODENAME}${NUM}_sentinel.conf; /usr/share/sentinelvenv/bin/python /usr/share/sentinel/bin/sentinel.py 2>&1 >> /var/log/sentinel/sentinel-cron.log"

}

#
# /* no parameters, creates a minimal set of firewall rules that allows INBOUND masternode p2p & SSH ports */
#
function configure_firewall() {

    echo "* Configuring firewall rules"
	# disallow everything except ssh and masternode inbound ports
	ufw default deny                          &>> ${SCRIPT_LOGFILE}
	ufw logging on                            &>> ${SCRIPT_LOGFILE}
	ufw allow ${SSH_INBOUND_PORT}/tcp         &>> ${SCRIPT_LOGFILE}
	# KISS, its always the same port for all interfaces
	ufw allow ${MNODE_INBOUND_PORT}/tcp       &>> ${SCRIPT_LOGFILE}
	# This will only allow 6 connections every 30 seconds from the same IP address.
	ufw limit OpenSSH	                      &>> ${SCRIPT_LOGFILE}
	ufw --force enable                        &>> ${SCRIPT_LOGFILE}
	echo "* Firewall ufw is active and enabled on system startup"

}

#
# /* no parameters, checks if the choice of networking matches w/ this VPS installation */
#
function validate_netchoice() {

    echo "* Validating network rules"

	# break here of net isn't 4 or 6
	if [ ${net} -ne 4 ] && [ ${net} -ne 6 ]; then
		echo "invalid NETWORK setting, can only be 4 or 6!"
		exit 1;
	fi

	# generate the required ipv6 config
	if [ "${net}" -eq 4 ]; then
	    IPV6_INT_BASE="#NEW_IPv4_ADDRESS_FOR_MASTERNODE_NUMBER"
	    NETWORK_BASE_TAG=""
        echo "IPv4 address generation needs to be done manually atm!"  &>> ${SCRIPT_LOGFILE}
	fi	# end ifneteq4

}

#
# /* no parameters, generates one masternode configuration file per masternode in the default
#    directory (eg. /etc/masternodes/${CODENAME} and replaces the existing placeholders if possible */
#
function create_mn_configuration() {

        # always return to the script root
        cd ${SCRIPTPATH}
        for NUM in $(seq 1 ${count}); do
          if [ -n "${PRIVKEY[${NUM}]}" ]; then
            echo ${PRIVKEY[${NUM}]} >> tmp.txt
          fi
        done
        if [ -f tmp.txt ]; then
            dup=$(sort -t 8 tmp.txt | uniq -c | sort -nr | head -1 | awk '{print substr($0, 7, 1)}')
            if [ 1 -ne "$dup" ]; then
                echo "Private key was duplicated. Please restart this script."
                rm -r /etc/masternodes
                rm tmp.txt
                exit 1
            fi
            rm tmp.txt
        fi

        # create one config file per masternode
        for NUM in $(seq 1 ${count}); do
        PASS=$(date | md5sum | cut -c1-24)

	# we dont want to overwrite an existing config file
	if [ ! -f ${MNODE_CONF_BASE}/${CODENAME}_n${NUM}.conf ]; then
        	echo "individual masternode config doesn't exist, generate it!"                  &>> ${SCRIPT_LOGFILE}
		# if a template exists, use this instead of the default
		if [ -e config/${CODENAME}/${CODENAME}.conf ]; then
			echo "custom configuration template for ${CODENAME} found, use this instead"                      &>> ${SCRIPT_LOGFILE}
			cp ${SCRIPTPATH}/config/${CODENAME}/${CODENAME}.conf ${MNODE_CONF_BASE}/${CODENAME}_n${NUM}.conf  &>> ${SCRIPT_LOGFILE}
		else
			echo "No ${CODENAME} template found, using the default configuration template"			          &>> ${SCRIPT_LOGFILE}
			cp ${SCRIPTPATH}/config/default.conf ${MNODE_CONF_BASE}/${CODENAME}_n${NUM}.conf                  &>> ${SCRIPT_LOGFILE}
		fi
		# replace placeholders
		echo "running sed on file ${MNODE_CONF_BASE}/${CODENAME}_n${NUM}.conf"                                &>> ${SCRIPT_LOGFILE}
	fi
	
        if [ -n "${PRIVKEY[${NUM}]}" ]; then
        	if [ ${#PRIVKEY[${NUM}]} -eq 51 ]; then
        		sed -e "s/HERE_GOES_YOUR_MASTERNODE_KEY_FOR_MASTERNODE_XXX_GIT_PROJECT_XXX_XXX_NUM_XXX/${PRIVKEY[${NUM}]}/" -i ${MNODE_CONF_BASE}/${CODENAME}_n${NUM}.conf
          	else
            		echo "input private key ${PRIVKEY[${NUM}]} was invalid. Please check the key, and restart this script."
            		rm -r /etc/masternodes
            		exit 1
          	fi
        else :
        fi
        sed -e "s/XXX_GIT_PROJECT_XXX/${CODENAME}/" -e "s/XXX_NUM_XXY/${NUM}]/" -e "s/XXX_NUM_XXX/${NUM}/" -e "s/XXX_PASS_XXX/${PASS}/" -e "s/XXX_IPV6_INT_BASE_XXX/[${IPV6_INT_BASE}/" -e "s/XXX_NETWORK_BASE_TAG_XXX/${NETWORK_BASE_TAG}/" -e "s/XXX_MNODE_INBOUND_PORT_XXX/${MNODE_INBOUND_PORT}/" -i ${MNODE_CONF_BASE}/${CODENAME}_n${NUM}.conf
	if [ -z "${PRIVKEY[${NUM}]}" ]; then
		if [ "$startnodes" -eq 1 ]; then
			#uncomment masternode= and masternodeprivkey= so the node can autostart and sync
			sed 's/\(^.*masternode\(\|privkey\)=.*$\)/#\1/' -i ${MNODE_CONF_BASE}/${CODENAME}_n${NUM}.conf
		fi
	fi
        done
}

#
# /* no parameters, generates a masternode configuration file per masternode in the default */
#
function create_control_configuration() {
    	# delete any old stuff that's still around
    	rm -f /tmp/${CODENAME}_masternode.conf &>> ${SCRIPT_LOGFILE}
	# create one line per masternode with the data we have
	for NUM in $(seq 1 ${count}); do
		if [ -n "${PRIVKEY[${NUM}]}" ]; then
    			echo ${CODENAME}MN${NUM} [${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${NUM}]:${MNODE_INBOUND_PORT} ${PRIVKEY[${NUM}]} COLLATERAL_TX_FOR_${CODENAME}MN${NUM} OUTPUT_NO_FOR_${CODENAME}MN${NUM} >> /tmp/${CODENAME}_masternode.conf
    		else
			echo ${CODENAME}MN${NUM} [${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${NUM}]:${MNODE_INBOUND_PORT} MASTERNODE_PRIVKEY_FOR_${CODENAME}MN${NUM} COLLATERAL_TX_FOR_${CODENAME}MN${NUM} OUTPUT_NO_FOR_${CODENAME}MN${NUM} >> /tmp/${CODENAME}_masternode.conf
		fi
	done
}

#
# /* no parameters, generates a a pre-populated masternode systemd config file */
#
function create_systemd_configuration() {

    echo "* (over)writing systemd config files for masternodes"
	# create one config file per masternode
	for NUM in $(seq 1 ${count}); do
	PASS=$(date | md5sum | cut -c1-24)
		echo "* (over)writing systemd config file ${SYSTEMD_CONF}/${CODENAME}_n${NUM}.service"  &>> ${SCRIPT_LOGFILE}
		cat > ${SYSTEMD_CONF}/${CODENAME}_n${NUM}.service <<-EOF
			[Unit]
			Description=${CODENAME} distributed currency daemon
			After=network.target

			[Service]
			User=${MNODE_USER}
			Group=${MNODE_USER}

			Type=forking
			PIDFile=${MNODE_DATA_BASE}/${CODENAME}${NUM}/${CODENAME}.pid
			ExecStart=${MNODE_DAEMON} -daemon -pid=${MNODE_DATA_BASE}/${CODENAME}${NUM}/${CODENAME}.pid \
			-conf=${MNODE_CONF_BASE}/${CODENAME}_n${NUM}.conf -datadir=${MNODE_DATA_BASE}/${CODENAME}${NUM}

			Restart=always
			RestartSec=5
			PrivateTmp=true
			TimeoutStopSec=60s
			TimeoutStartSec=5s
			StartLimitInterval=120s
			StartLimitBurst=15

			[Install]
			WantedBy=multi-user.target
		EOF
	done

}

#
# /* set all permissions to the masternode user */
#
function set_permissions() {

	# maybe add a sudoers entry later
	chown -R ${MNODE_USER}:${MNODE_USER} ${MNODE_CONF_BASE} ${MNODE_DATA_BASE} /var/log/sentinel &>> ${SCRIPT_LOGFILE}
	# make group permissions same as user, so vps-user can be added to masternode group
	chmod -R g=u ${MNODE_CONF_BASE} ${MNODE_DATA_BASE} /var/log/sentinel &>> ${SCRIPT_LOGFILE}

}

#
# /* wipe all files and folders generated by the script for a specific project */
#
function wipe_all() {

    	echo "Deleting all ${project} related data!"
	rm -f /etc/masternodes/${project}_n*.conf
	rmdir --ignore-fail-on-non-empty -p /var/lib/masternodes/${project}*
	rm -f /etc/systemd/system/${project}_n*.service
	rm -f ${MNODE_DAEMON}
	echo "DONE!"
	exit 0

}

#
#Generate masternode private key
#
function generate_privkey() {
	echo -e "rpcuser=test\nrpcpassword=passtest" >> ${MNODE_CONF_BASE}/${CODENAME}_test.conf
  	mkdir -p ${MNODE_DATA_BASE}/${CODENAME}_test
  	heliumd -daemon -conf=${MNODE_CONF_BASE}/${CODENAME}_test.conf -datadir=${MNODE_DATA_BASE}/${CODENAME}_test
  	sleep 5
  	
	for NUM in $(seq 1 ${count}); do
    		if [ -z "${PRIVKEY[${NUM}]}" ]; then
    			PRIVKEY[${NUM}]=$(helium-cli -conf=${MNODE_CONF_BASE}/${CODENAME}_test.conf -datadir=${MNODE_DATA_BASE}/${CODENAME}_test masternode genkey)
    		fi
  	done
  	helium-cli -conf=${MNODE_CONF_BASE}/${CODENAME}_test.conf -datadir=${MNODE_DATA_BASE}/${CODENAME}_test stop
  	sleep 5
  	rm -r ${MNODE_CONF_BASE}/${CODENAME}_test.conf ${MNODE_DATA_BASE}/${CODENAME}_test
}

#
# /*
# remove packages and stuff we don't need anymore and set some recommended
# kernel parameters
# */
#
function cleanup_after() {

	apt-get -qqy -o=Dpkg::Use-Pty=0 --force-yes autoremove
	apt-get -qqy -o=Dpkg::Use-Pty=0 --force-yes autoclean

	echo "kernel.randomize_va_space=1" > /etc/sysctl.conf  &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.conf.all.accept_source_route=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.conf.all.log_martians=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.conf.default.log_martians=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.conf.all.accept_redirects=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv6.conf.all.accept_redirects=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.conf.all.send_redirects=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "kernel.sysrq=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.tcp_timestamps=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	echo "net.ipv4.icmp_ignore_bogus_error_responses=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
	sysctl -p

}

#
# /* project as parameter, sources the project specific parameters and runs the main logic */
#

# source the default and desired crypto configuration files
function source_config() {

    SETUP_CONF_FILE="${SCRIPTPATH}/config/${project}/${project}.env"

    # first things first, to break early if things are missing or weird
    check_distro

	if [ -f ${SETUP_CONF_FILE} ]; then
		echo "Script version ${SCRIPT_VERSION}, you picked: ${project}"
		echo "apply config file for ${project}"	&>> ${SCRIPT_LOGFILE}
		source "${SETUP_CONF_FILE}"

		# count is from the default config but can ultimately be
		# overwritten at runtime
		if [ -z "${count}" ]
		then
			count=${SETUP_MNODES_COUNT}
			echo "No number given, installing default number of nodes: ${SETUP_MNODES_COUNT}" &>> ${SCRIPT_LOGFILE}
		fi

		# release is from the default project config but can ultimately be
		# overwritten at runtime
		if [ -z "$release" ]
		then
			release=${SCVERSION}
			echo "release empty, setting to project default: ${SCVERSION}"  &>> ${SCRIPT_LOGFILE}
		fi

		# net is from the default config but can ultimately be
		# overwritten at runtime
		if [ -z "${net}" ]; then
			net=${NETWORK_TYPE}
			echo "net EMPTY, setting to default: ${NETWORK_TYPE}" &>> ${SCRIPT_LOGFILE}
		fi

		# main block of function logic starts here
	    	# if update flag was given, delete the old daemon binary first & proceed
		if [ "$update" -eq 1 ]; then
			echo "update given, deleting the old daemon NOW!" &>> ${SCRIPT_LOGFILE}
			rm -f ${MNODE_DAEMON}
		fi

		echo "************************* Installation Plan *****************************************"
		echo ""
		echo "I am going to install and configure "
       		echo "=> ${count} ${project} masternode(s) in version ${release}"
        	echo "for you now."
        	echo ""
		echo "You have to add your masternode private key to the individual config files afterwards"
		echo ""
		echo "Stay tuned!"
        	echo ""
		# show a hint for MANUAL IPv4 configuration
		if [ "${net}" -eq 4 ]; then
			NETWORK_TYPE=4
			echo "WARNING:"
			echo "You selected IPv4 for networking but there is no automatic workflow for this part."
			echo "This means you will have some mamual work to do to after this configuration run."
			echo ""
			echo "See the following link for instructions how to add multiple ipv4 addresses on vultr:"
			echo "${IPV4_DOC_LINK}"
		fi
		# sentinel setup
		if [ "$sentinel" -eq 1 ]; then
			echo "I will also generate a Sentinel configuration for you."
		fi
		# start nodes after setup
		if [ "$startnodes" -eq 1 ]; then
			echo "I will start your masternodes after the installation."
		fi
		echo ""
		echo "A logfile for this run can be found at the following location:"
		echo "${SCRIPT_LOGFILE}"
		echo ""
		echo "*************************************************************************************"
		sleep 5

		# main routine
		print_logo
        	prepare_mn_interfaces
        	swaphack
        	install_packages
		build_mn_from_source
		create_mn_user
		create_mn_dirs
	
    		# private key initialize
    		if [ "$generate" -eq 1 ]; then
      			echo "Generating masternode private key" &>> ${SCRIPT_LOGFILE}
      			generate_privkey
		fi
	
		# sentinel setup
		if [ "$sentinel" -eq 1 ]; then
			echo "* Sentinel setup chosen" &>> ${SCRIPT_LOGFILE}
			create_sentinel_setup
		fi
	
		configure_firewall
		create_mn_configuration
		create_control_configuration
		create_systemd_configuration
		set_permissions
		cleanup_after
		showbanner
		final_call
	else
		echo "required file ${SETUP_CONF_FILE} does not exist, abort!"
		exit 1
	fi

}

function print_logo() {

	# print ascii banner if a logo exists
	echo -e "* Starting the compilation process for ${CODENAME}, stay tuned"
	if [ -f "${SCRIPTPATH}/assets/$CODENAME.jpg" ]; then
			jp2a -b --colors --width=56 ${SCRIPTPATH}/assets/${CODENAME}.jpg
	else
			jp2a -b --colors --width=56 ${SCRIPTPATH}/assets/default.jpg          
	fi  

}

#
# /* no parameters, builds the required masternode binary from sources. Exits if already exists and "update" not given  */
#
function build_mn_from_source() {
        # daemon not found compile it
        if [ ! -f ${MNODE_DAEMON} ]; then
                mkdir -p ${SCRIPTPATH}/${CODE_DIR} &>> ${SCRIPT_LOGFILE}
                # if code directory does not exists, we create it clone the src
                if [ ! -d ${SCRIPTPATH}/${CODE_DIR}/${CODENAME} ]; then
                        mkdir -p ${CODE_DIR} && cd ${SCRIPTPATH}/${CODE_DIR} &>> ${SCRIPT_LOGFILE}
                        git clone ${GIT_URL} ${CODENAME}          &>> ${SCRIPT_LOGFILE}
                        cd ${SCRIPTPATH}/${CODE_DIR}/${CODENAME}  &>> ${SCRIPT_LOGFILE}
                        echo "* Checking out desired GIT tag: ${release}"
                        git checkout ${release}                   &>> ${SCRIPT_LOGFILE}
                else
                        echo "* Updating the existing GIT repo"
                        cd ${SCRIPTPATH}/${CODE_DIR}/${CODENAME}  &>> ${SCRIPT_LOGFILE}
                        git pull                                  &>> ${SCRIPT_LOGFILE}
                        echo "* Checking out desired GIT tag: ${release}"
                        git checkout ${release}                   &>> ${SCRIPT_LOGFILE}
                fi

                # print ascii banner if a logo exists
                echo -e "* Starting the compilation process for ${CODENAME}, stay tuned"
                if [ -f "${SCRIPTPATH}/assets/$CODENAME.jpg" ]; then
                        jp2a -b --colors --width=56 ${SCRIPTPATH}/assets/${CODENAME}.jpg
                else
                        jp2a -b --colors --width=56 ${SCRIPTPATH}/assets/default.jpg
                fi
                # compilation starts here
                source ${SCRIPTPATH}/config/${CODENAME}/${CODENAME}.compile | pv -t -i0.1
        else
                echo "* Daemon already in place at ${MNODE_DAEMON}, not compiling"
        fi

		# if it's not available after compilation, theres something wrong
        if [ ! -f ${MNODE_DAEMON} ]; then
                echo "COMPILATION FAILED! Please open an issue at https://github.com/masternodes/vps/issues. Thank you!"
                exit 1
        fi
}

#
# /* no parameters, print some (hopefully) helpful advice  */
#
function final_call() {
	# note outstanding tasks that need manual work
    echo "************! ALMOST DONE !******************************"
	echo "There is still work to do in the configuration templates."
	echo "These are located at ${MNODE_CONF_BASE}, one per masternode."
	echo "Add your masternode private keys now."
	echo "eg in /etc/masternodes/${CODENAME}_n1.conf"
	echo ""
    echo "=> All configuration files are in: ${MNODE_CONF_BASE}"
    echo "=> All Data directories are in: ${MNODE_DATA_BASE}"
	echo ""
	echo "last but not least, run /usr/local/bin/activate_masternodes_${CODENAME} as root to activate your nodes."

    # place future helper script accordingly
    cp ${SCRIPTPATH}/scripts/activate_masternodes.sh ${MNODE_HELPER}_${CODENAME}
	echo "">> ${MNODE_HELPER}_${CODENAME}

	for NUM in $(seq 1 ${count}); do
		echo "systemctl enable ${CODENAME}_n${NUM}" >> ${MNODE_HELPER}_${CODENAME}
		echo "systemctl restart ${CODENAME}_n${NUM}" >> ${MNODE_HELPER}_${CODENAME}
	done

	chmod u+x ${MNODE_HELPER}_${CODENAME}
	if [ "$startnodes" -eq 1 ]; then
		echo ""
		echo "** Your nodes are starting up. If you haven't set masternode private key, Don't forget to change the masternodeprivkey later."
		${MNODE_HELPER}_${CODENAME}
	fi
	tput sgr0
}

#
# /* no parameters, create the required network configuration. IPv6 is auto.  */
#
function prepare_mn_interfaces() {

    # this allows for more flexibility since every provider uses another default interface
    # current default is:
    # * ens3 (vultr) w/ a fallback to "eth0" (Hetzner, DO & Linode w/ IPv4 only)
    #

    # check for the default interface status
    if [ ! -f /sys/class/net/${ETH_INTERFACE}/operstate ]; then
        echo "Default interface doesn't exist, switching to eth0"
        export ETH_INTERFACE="eth0"
    fi

    # get the current interface state
    ETH_STATUS=$(cat /sys/class/net/${ETH_INTERFACE}/operstate)

    # check interface status
    if [[ "${ETH_STATUS}" = "down" ]] || [[ "${ETH_STATUS}" = "" ]]; then
        echo "Default interface is down, fallback didn't work. Break here."
        exit 1
    fi

    # DO ipv6 fix, are we on DO?
    # check for DO network config file
    if [ -f ${DO_NET_CONF} ]; then
        # found the DO config
		if ! grep -q "::8888" ${DO_NET_CONF}; then
			echo "ipv6 fix not found, applying!"
			sed -i '/iface eth0 inet6 static/a dns-nameservers 2001:4860:4860::8844 2001:4860:4860::8888 8.8.8.8 127.0.0.1' ${DO_NET_CONF}
			ifdown ${ETH_INTERFACE}; ifup ${ETH_INTERFACE};
		fi
    fi

    IPV6_INT_BASE="$(ip -6 addr show dev ${ETH_INTERFACE} | grep inet6 | awk -F '[ \t]+|/' '{print $3}' | grep -v ^fe80 | grep -v ^::1 | cut -f1-4 -d':' | head -1)" &>> ${SCRIPT_LOGFILE}

	validate_netchoice
	echo "IPV6_INT_BASE AFTER : ${IPV6_INT_BASE}" &>> ${SCRIPT_LOGFILE}

    # user opted for ipv6 (default), so we have to check for ipv6 support
	# check for vultr ipv6 box active
	if [ -z "${IPV6_INT_BASE}" ] && [ ${net} -ne 4 ]; then
		echo "No IPv6 support on the VPS but IPv6 is the setup default. Please switch to ipv4 with flag \"-n 4\" if you want to continue."
		echo ""
		echo "See the following link for instructions how to add multiple ipv4 addresses on vultr:"
		echo "${IPV4_DOC_LINK}"
		exit 1
	fi

	# generate the required ipv6 config
	if [ "${net}" -eq 6 ]; then
        # vultr specific, needed to work
	    sed -ie '/iface ${ETH_INTERFACE} inet6 auto/s/^/#/' ${NETWORK_CONFIG}

		# move current config out of the way first
		cp ${NETWORK_CONFIG} ${NETWORK_CONFIG}.${DATE_STAMP}.bkp

		# create the additional ipv6 interfaces, rc.local because it's more generic
		for NUM in $(seq 1 ${count}); do

			# check if the interfaces exist
			ip -6 addr | grep -qi "${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${NUM}"
			if [ $? -eq 0 ]
			then
			  echo "IP for masternode already exists, skipping creation" &>> ${SCRIPT_LOGFILE}
			else
			  echo "Creating new IP address for ${CODENAME} masternode nr ${NUM}" &>> ${SCRIPT_LOGFILE}
			  if [ "${NETWORK_CONFIG}" = "/etc/rc.local" ]; then
			    # need to put network config in front of "exit 0" in rc.local
				sed -e '$i ip -6 addr add '"${IPV6_INT_BASE}"':'"${NETWORK_BASE_TAG}"'::'"${NUM}"'/64 dev '"${ETH_INTERFACE}"'\n' -i ${NETWORK_CONFIG}
			  else
			    # if not using rc.local, append normally
			  	echo "ip -6 addr add ${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${NUM}/64 dev ${ETH_INTERFACE}" >> ${NETWORK_CONFIG}
			  fi
			  sleep 2
			  ip -6 addr add ${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${NUM}/64 dev ${ETH_INTERFACE} &>> ${SCRIPT_LOGFILE}
			fi
		done # end forloop
	fi # end ifneteq6

}

##################------------Menu()---------#####################################

# Declare vars. Flags initalizing to 0.
wipe=0;
debug=0;
update=0;
sentinel=0;
generate=0;
startnodes=0;

# Execute getopt
ARGS=$(getopt -o "hp:n:c:r:wsudxgk:k2:k3:k4:k5:k6:k7:k8:k9:k10:" -l "help,project:,net:,count:,release:,wipe,sentinel,update,debug,startnodes,generate,key:,key2:,key3:,key4:,key5:,key6:,key7:,key8:,key9:,key10:" -n "install.sh" -- "$@");

#Bad arguments
if [ $? -ne 0 ];
then
    help;
fi

eval set -- "$ARGS";

while true; do
    case "$1" in
        -h |--help)
            shift;
            help;
            ;;
        -p |--project)
            shift;
                    if [ -n "$1" ];
                    then
                        project="$1";
                        shift;
                    fi
            ;;
        -n |--net)
            shift;
                    if [ -n "$1" ];
                    then
                        net="$1";
                        shift;
                    fi
            ;;
        -c |--count)
            shift;
                    if [ -n "$1" ];
                    then
                        count="$1";
                        shift;
                    fi
            ;;
        -r |--release)
            shift;
                    if [ -n "$1" ];
                    then
                        release="$1";
                        SCVERSION="$1"
                        shift;
                    fi
            ;;
        -w |--wipe)
            shift;
                    wipe="1";
            ;;
        -s |--sentinel)
            shift;
                    sentinel="1";
            ;;
        -u |--update)
            shift;
                    update="1";
            ;;
        -d |--debug)
            shift;
                    debug="1";
            ;;
        -x|--startnodes)
            shift;
                    startnodes="1";
            ;;

        -g | --generate)
            shift;
                    generate="1";
            ;;
        -k |--key)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[1]="$1";
                        shift;
                    fi
            ;;
        -k2 |--key2)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[2]="$1";
                        shift;
                    fi
            ;;
        -k3 |--key3)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[3]="$1";
                        shift;
                    fi
            ;;
        -k4 |--key4)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[4]="$1";
                        shift;
                    fi
            ;;
        -k5 |--key5)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[5]="$1";
                        shift;
                    fi
            ;;
        -k6 |--key6)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[6]="$1";
                        shift;
                    fi
            ;;
        -k7 |--key7)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[7]="$1";
                        shift;
                    fi
            ;;
	      -k8 |--key8)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[8]="$1";
                        shift;
                    fi
            ;;
        -k9 |--key9)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[9]="$1";
                        shift;
                    fi
            ;;
	     -k10 |--key10)
            shift;
                    if [ -n "$1" ];
                    then
                        PRIVKEY[10]="$1";
                        shift;
                    fi
            ;;
        --)
            shift;
            break;
            ;;
    esac
done

# Check required arguments
if [ -z "$project" ]
then
    show_help;
fi

# Check required arguments
if [ "$wipe" -eq 1 ]; then
	get_confirmation "Would you really like to WIPE ALL DATA!? YES/NO y/n" && wipe_all
	exit 0
fi

#################################################
# source default config before everything else
source ${SCRIPTPATH}/config/default.env
#################################################

main() {

    echo "starting" &> ${SCRIPT_LOGFILE}
    showbanner

	# debug
	if [ "$debug" -eq 1 ]; then
		echo "********************** VALUES AFTER CONFIG SOURCING: ************************"
		echo "START DEFAULTS => "
		echo "SCRIPT_VERSION:       $SCRIPT_VERSION"
		echo "SSH_INBOUND_PORT:     ${SSH_INBOUND_PORT}"
		echo "SYSTEMD_CONF:         ${SYSTEMD_CONF}"
		echo "NETWORK_CONFIG:       ${NETWORK_CONFIG}"
		echo "NETWORK_TYPE:         ${NETWORK_TYPE}"
		echo "ETH_INTERFACE:        ${ETH_INTERFACE}"
		echo "MNODE_CONF_BASE:      ${MNODE_CONF_BASE}"
		echo "MNODE_DATA_BASE:      ${MNODE_DATA_BASE}"
		echo "MNODE_USER:           ${MNODE_USER}"
		echo "MNODE_HELPER:         ${MNODE_HELPER}"
		echo "MNODE_SWAPSIZE:       ${MNODE_SWAPSIZE}"
		echo "CODE_DIR:             ${CODE_DIR}"
		echo "SCVERSION:            ${SCVERSION}"
		echo "RELEASE:              ${release}"
		echo "SETUP_MNODES_COUNT:   ${SETUP_MNODES_COUNT}"
		echo "END DEFAULTS => "
	fi

	# source project configuration
    source_config ${project}

	# debug
	if [ "$debug" -eq 1 ]; then
		echo "START PROJECT => "
		echo "CODENAME:             $CODENAME"
		echo "SETUP_MNODES_COUNT:   ${SETUP_MNODES_COUNT}"
		echo "MNODE_DAEMON:         ${MNODE_DAEMON}"
		echo "MNODE_INBOUND_PORT:   ${MNODE_INBOUND_PORT}"
		echo "GIT_URL:              ${GIT_URL}"
		echo "SCVERSION:            ${SCVERSION}"
		echo "RELEASE:              ${release}"
		echo "NETWORK_BASE_TAG:     ${NETWORK_BASE_TAG}"
		echo "END PROJECT => "

		echo "START OPTIONS => "
		echo "RELEASE: ${release}"
		echo "PROJECT: ${project}"
		echo "SETUP_MNODES_COUNT: ${count}"
		echo "NETWORK_TYPE: ${NETWORK_TYPE}"
		echo "NETWORK_TYPE: ${net}"

		echo "END OPTIONS => "
		echo "********************** VALUES AFTER CONFIG SOURCING: ************************"
	fi
}

main "$@"
