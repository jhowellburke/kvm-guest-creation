#!/bin/bash
#This script is designed to create KVM guests taking input from users to create virtual machines with parameters set by the user.
#Created by Joseph Howell-Burke July 10, 2017
clear

#Declare Variables
error_log='/root/kvm-guest-creation/error-log'
status_log='/root/kvm-guest-creation/status-log'
distro=$(cat /etc/*-release | grep '^NAME' | awk -F "=" '{print $2}'| tail -c +2 | sed 's/.$//' | awk '{print $1}')
networks=$(ip addr | grep -E "br|pub" | grep -v enp | grep -v gns3tap | grep -v em | grep -vE "eno|eth" | grep -vE "vir|vn" | awk '{print $2" "$14}' | cut -d . -f 3 | grep -v '^00' | grep -v "serverteam-dr")
host=$(hostname -f)
kvm_def_loc='/var/lib/libvirt/images'
dir='/var/lib/libvirt/images/iso-images'
user=$(ls /home/ | grep psp)

#Clear log files for current logs only
cat /dev/null > $error_log
cat /dev/null > $status_log

#Remove any spare ISO's
rm -f /var/lib/libvirt/images/iso-images/temp/new-distro.iso 2>> $error_log > $status_log

#Check if OpenVswitch is installed.
which ovs-vsctl &> /dev/null
if [ "$?" = "0" ]; then
  echo "OpenVswitch is Installed."
  echo "Setting Correct Parameters"
  ovs_status="True"
  ovs_vlans=$(ovs-vsctl show | grep tag | awk '{print $2}' | while read line; do echo "vlan $line"; done | sort | uniq -c | sort -n | awk '{print $2" "$3}')
  ovs_bridge=$(ovs-vsctl show | grep Bridge | awk '{print $2}' | sed 's/.$//' | sed 's/.//' | while read bridge; do echo "$bridge"; done)
  cp default-xml/ovs-addon.config .
else
  echo "OpenVswitch not installed"
  echo "Using Standard Settings"
  ovs_status="False"
fi

#Clear screen
sleep 6
clear

#Check for needed directory and files. If they do not exist retrieve them
if [[ -d "/var/lib/libvirt/images/iso-images" && -f "$dir/CentOS-7-x86_64-Everything-1611.iso" && -f "$dir/debian-9.0.0-amd64-DVD-1.iso" && -f "$dir/ubuntu-16.04.2-server-amd64.iso" ]]; then
  menu_check="True"
else
  echo "Missing ISO's from iso-images directory. Retrieving ISO's from fileserver(192.168.1.2) Please wait.."
  echo "You will be prompted for fileserver password. Its the one that starts with vft#####"
  echo "Copying ISO's might take a few minutes. Please wait until '"All Parameters Met Message"' appears"
  sleep 7
  cd $kvm_def_loc 2>> $error_log >> $status_log
  current_dir=$(pwd)
  if [ "$current_dir" = "$kvm_def_loc" ]; then
    scp root@192.168.1.2:/data/ISO/kvm-guest-creation-isos/iso-images.tar.gz .
    tar -zxvf iso-images.tar.gz
    if [ "$?" = "0" ]; then
      menu_check="True"
      mkdir $kvm_def_loc/backups 2>> $error_log >> $status_log
      mv $kvm_def_loc/iso-images.tar.gz $kvm_def_loc/backups 2>> $error_log >> $status_log
    else
      menu_check="False"
      echo "Unable to retrieve needed ISO's. Exiting Script"
      exit
    fi
  else
    echo "Unable to create iso-images directory in /var/lib/libvirt/images directory. Check error log. Exiting script"
    exit
  fi
fi

#Continue if parameters meet requirments. Exit if they do not
if [ "$menu_check" = "True" ]; then
  echo "All PARAMETERS MET - Starting Script"
else
  clear
  echo "Unable to meet required parameters exiting script. Could not verify one of the following: "
  echo "If /var/lib/libvirt/images/iso-images exists"
  echo "If the ISO images are located in the /var/lib/libvirt/images/iso-images/ directory."
  exit
fi

#Declare Functions
#Guest creation function
guest_creation () {
os_1=$1
name=$2
ram_MB=$(($3*1024))
disk_GB=$4
vcpus=$5
g_network=$6

#Determine if disk will be static or dynamic
if [ "$t_space" = "False" ]; then
  path="path=/var/lib/libvirt/images/$name.qcow2,size=$disk_GB,bus=virtio,format=qcow2"
elif [ "$t_space" = "True" ]; then
  path="path=/var/lib/libvirt/images/$name.qcow2,format=qcow2,bus=virtio,cache=none"
fi

virt-install \
--virt-type=kvm \
--name $name \
--ram $ram_MB \
--vcpus=$vcpus \
--os-variant=$os_variant \
--hvm \
--cdrom=$iso_loc \
--network=bridge=$g_network,model=virtio \
--graphics vnc \
--disk $path 2>> $error_log >> $status_log
}

#Import an existing guest to any host running Debian,Ubuntu, or CentOS
import_guest () {
clear
u_host=$1
xml_loc=$2
#Set OpenVswitch settings if OVS is detected.
if [ "$ovs_status" = "True" ]; then
  switch_inter=$(ovs-vsctl show | head -1)
  sed '/<interface/,/interface>/d' $1.xml > ovs-config-remove
  sed -i '/set-here/r ovs-addon.config' ovs-config-remove
  sed  -i '/set-here/d' ./ovs-config-remove
  sed -i 's#switch_id#'"$switch_inter"'#g' ovs-config-remove
  \cp -rf ovs-config-remove $1.xml
  echo "This host has OpenVswitch installed. Please select which VLAN guest will be on: Example: 123 or 321"
  echo "$ovs_vlans"
  read vlan
  sed -i 's#new_vlan#'"$vlan"'#g' $2 2>> $error_log >> $status_log
  echo "Guest will be placed on $vlan VLAN"
  sleep 3
  clear
else
  sed  -i '/set-here/d' $2
fi
#Select emulator depending on host OS
if [ "$1" = "CentOS" ]; then
  cent_emulator="/usr/libexec/qemu-kvm"
  sed -i 's#n_emulator#'"$cent_emulator"'#g' $2 2>> $error_log >> $status_log
elif [ "$1" = "Ubuntu" ]; then
  ubtu_emulator="/usr/bin/kvm"
  sed -i 's#n_emulator#'"$ubtu_emulator"'#g' $2 2>> $error_log >> $status_log
elif [ "$1" = "Debian" ]; then
  debi_emulator="/usr/bin/kvm"
  sed -i 's#n_emulator#'"$debi_emulator"'#g' $2 2>> $error_log >> $status_log
else
  echo "Unable to verify host name matchup. Host OS needs to be:"
  echo "CentOS, Debian, or Ubuntu for script to work. Exiting"
  exit
fi
# Collect guest information from user
echo "Selected $1 Custum XML"
echo "Name of imported guest?"
read n_name
sed -i 's#new_guest#'"$n_name"'#g' $2 2>> $error_log >> $status_log
echo "How many vcpu's (Virtual CPU's) for imported guest? Example: 1=1vcpu"
read n_vcpu
sed -i 's#new_vcpu#'"$n_vcpu"'#g' $2 2>> $error_log >> $status_log
echo "How much RAM in kiB for imported guest? Example: 1000000kiB = 1GB"
read n_ram
sed -i 's#new_ram#'"$n_ram"'#g' $2 2>> $error_log >> $status_log
# Set network settings for OVS or standard bridging.
if [ "$ovs_status" = "True" ]; then
  echo "Please select the OpenVswitch bridge to use: Example: br0 (If only one bridge shown then only one bridge is available)"
  echo "$ovs_bridge"
  read ov_bridge
  sed -i 's#n_network#'"$ov_bridge"'#g' $2 2>> $error_log >> $status_log
elif [ "$ovs_status" = "False" ]; then
  echo "Which network will this guest be on? Examples: br0, br1, pub123"
  echo "$networks"
  read ntwork
  sed -i 's#n_network#'"$ntwork"'#g' $2 2>> $error_log >> $status_log
else
  echo "Unable to determine network configuration. Exiting Script."
  exit
fi
# Finish collecting user input and verify settings
echo "What is the name of the imported guest image? Example: guest.qcow2"
read image_name
sed -i 's#imported_image#'"$image_name"'#g' $2 2>> $error_log >> $status_log
check=$(ls /var/lib/libvirt/images/ | grep -oh $image_name | grep -m 1 "")
check2=$(grep images $2 | awk -F "/" '{print $6}' | sed 's/.$//')
 if [[ "$check" = "$image_name" && "$image_name" = "$check2" ]]; then
   clear
   echo "Imported guest image location verified"
   echo "Creating $n_name guest"
   cp /root/kvm-guest-creation/$1.xml /etc/libvirt/qemu/$n_name.xml 2>> $error_log >> $status_log
   if [ "$?" = "0" ]; then
     rm -f /root/kvm-guest-creation/$1.xml
     rm -f /root/kvm-guest-creation/ovs-addon.config
     rm -f /root/kvm-guest-creation/ovs-config-remove
     virsh define /etc/libvirt/qemu/$n_name.xml | sed '/^$/d'
     if [ "$?" = "0" ]; then
       echo "$n_name guest import successful."
       echo "Starting $n_name guest...."
       sleep 5
       virsh start $n_name
       virsh list --all
     fi
   fi
 else
   clear
   echo "Unable to verify if the imported guest has a image is in the correct directory"
   echo "Double check that guest being imported's image file is in /var/lib/libvirt/images directory"
   echo "Then re-run script Double-Check: Did you add .qcow2 extension?"
   echo "The image (.qcow2) filename has to match guest image (.qcow2) filename in the /var/lib/libvirt/images directory"
   rm -f /root/kvm-guest-creation/$1.xml 2>> $error_log >> $status_log
 fi
}

#Clear terminal before starting
clear

#Check for virt-install and set menu options
echo "Checking for virt-install..."
which virt-install &> /dev/null
if [ "$?" = "0" ]; then
  echo "virt-install is installed. All menu options are available. Please wait..."
  sleep 8
  clear
  echo "Please Select An Option 1-5:"
  echo "===================================================="
  echo "1. Create a CentOS-7 Guest (64-bit)"
  echo "2. Create a Ubuntu-Server 16.04.2 LTS Guest (64-bit)"
  echo "3. Create a Debian-9.0.0 Guest (64-bit)"
  echo "4. Import Existing Guest from another Host"
  echo "5. Download a Different Distro Version"
  echo "6. Exit Script"
  read os
 else
  echo "virt-install not installed. Only menu option:\"4. Import Existing Guest\" is available"
  echo "With Option 4 all you need is the image of the guest placed in the /var/lib/libvirt/images directory."
  sleep 11
  clear
  echo "Since virt-install is not installed only option 4 is available."
  echo "Please Select An Option:"
  echo "==============================================================="
  echo "4. Import Existing Guest from another Host"
  read os
fi

#Set hardcoded variables
if [ "$os" = "1" ]; then
  os_variant="rhel7"
  iso_loc='/var/lib/libvirt/images/iso-images/CentOS-7-x86_64-Everything-1611.iso'
elif [ "$os" = "2" ]; then
  os_variant="ubuntu16.04"
  iso_loc='/var/lib/libvirt/images/iso-images/ubuntu-16.04.2-server-amd64.iso'
elif [ "$os" = "3" ]; then
  os_variant="debian8"
  iso_loc='/var/lib/libvirt/images/iso-images/debian-9.0.0-amd64-DVD-1.iso'
else
  echo "Options 4 & 5 set" 2>> $error_log >> $status_log
fi

#Start Main Program Here
sleep 1
clear
if [ "$os" = "1" ] || [ "$os" = "2" ] || [ "$os" = "3" ] ; then
  echo "Name of New Guest?:"
  read g_name
  echo "How much RAM? (Example: 1=1GB)"
  read g_ram
  echo "How many VCPUS? (Example: 1=1vcpu)"
  read g_vcpu
  echo "Size of Disk Image?: (Example: 10=10GB)"
  read g_disk
  echo "Do you want to reserve the full $g_disk GB's on the disk now? Or do you want the disk to grow as data is added to it?"
  echo "y = Reserve full $g_disk GB's on disk."
  echo "n = Create image that grows up $g_disk GB as data is added to it."
  read disk_type
  if [ "$disk_type" = "y" ]; then
    t_space="False"
  elif [ "$disk_type" = "n" ]; then
    t_space="True"
	  g_disk=$(echo "${g_disk}G")
	  qemu-img create -f qcow2 /var/lib/libvirt/images/$g_name.qcow2 $g_disk 2>> $error_log >> $status_log
  else
	  echo "Invalid Disk Parameters Detected! Exiting Script"
    exit
  fi
  echo "Which network will this guest be on? Examples: br0, br1, pub243"
  echo "$networks"
  read ng_network
  clear
  echo "Verify settings: Create $g_name with $g_ram GB RAM, $g_vcpu VCPU, and $g_disk GB disk image using $ng_network bridge. Is this correct? y/n"
  read answer
  if [ "$answer" = "y" ]; then
    clear
    echo "Creating Guest Now.... This should take about 10 seconds"

#Here we are sending the creation process to the background temporarily so that we can grab the vnc port number
    guest_creation $os $g_name $g_ram $g_disk $g_vcpu $ng_network 2>> $error_log >> $status_log &

    sleep 10 # Causing the process to sleep allows us to grab the variable

#The port number will now be uniq for each guest created. Example guest1=5900, guest2=5901 and so on
    port=$(virsh dumpxml $g_name | grep vnc | awk '{print $3}' | awk -F "=" '{print $2}' | tail -c +2 | sed 's/.$//')
    echo "Once guest creation has started you will need to use VNC to finish installation"
    echo "Example: On your LOCAL MACHINE type the command: ssh $user@$host -f -N -L $port:127.0.0.1:$port"
    echo "If sshing to $host fails then you will need to use the IP of $host instead of the hostname"
    echo "This will create a connection to this server on port $port"
    echo "Then connect your LOCAL VNC viewer to 127.0.0.1:$port to complete install."
    exit
  elif [ "$answer" = "n" ]; then
    echo "Exiting script"
    rm -rf /var/lib/libvirt/images/$g_name.qcow2
    exit
  else
    echo "Invalid Option"
    exit
  fi
elif [ "$os" = "4" ]; then
  clear
  echo "Before importing guest make sure to copy the guest image file to /var/lib/libvirt/images directory"
  echo "Is guest image already at this location? y/n"
  read response
  if [ "$response" = "n" ]; then
    clear
    echo "Guest image needs to be moved to /var/lib/libvirt/images/ directory for import to successfully complete."
    echo "Once images is placed in correct directory re-run script and select import option. Exiting script"
    exit
  elif [ "$response" = "y" ]; then
    clear
#Check host OS to determine XML format
    if [ "$distro" = "Ubuntu" ]; then
      cp /root/kvm-guest-creation/default-xml/Ubuntu.xml /root/kvm-guest-creation/ 2>> $error_log >> $status_log
      xml='/root/kvm-guest-creation/Ubuntu.xml'
      import_guest $distro $xml
    elif [ "$distro" = "Debian" ]; then
      cp /root/kvm-guest-creation/default-xml/Debian.xml /root/kvm-guest-creation/ 2>> $error_log >> $status_log
      xml='/root/kvm-guest-creation/Debian.xml'
      import_guest $distro $xml
    elif [ "$distro" = "CentOS" ]; then
      cp /root/kvm-guest-creation/default-xml/CentOS.xml /root/kvm-guest-creation/ 2>> $error_log >> $status_log
      xml='/root/kvm-guest-creation/CentOS.xml'
      import_guest $distro $xml
    else
      echo "Unable to verify host OS" 2>> $error_log >> $status_log
      exit
    fi
  fi
elif [ "$os" = "5" ]; then
  clear
  echo "Paste the full URL to the distro you are downloading: Example: http://mirror.pnl.gov/releases/16.04.2/ubuntu-16.04.2-server-amd64.iso"
  read url
  image_dir='/var/lib/libvirt/images/iso-images/temp/'
  cd $image_dir
  wget -O new-distro.iso $url
  iso_loc='/var/lib/libvirt/images/iso-images/temp/new-distro.iso'
  echo "Please Wait.."
  sleep 3
  clear
  echo "Images has been downloaded would you start installation? y/n"
  read os2
  if [ "$os2" = "y" ]; then
    echo "Name of New Guest?:"
    read g_name
    echo "How much RAM? (Example: 1=1GB)"
    read g_ram
    echo "How many VCPUS? (Example: 1=1vcpu)"
    read g_vcpu
    echo "Size of Disk Image?: (Example: 10=10GB)"
    read g_disk
    echo "Do you want to reserve the full $g_disk GB's on the disk now? Or do you want the disk to grow as data is added to it?"
  echo "y = Reserve full $g_disk GB's on disk."
  echo "n = Create image that grows up $g_disk GB as data is added to it."
  read disk_type_2
  if [ "$disk_type_2" = "y" ]; then
    t_space="False"
  elif [ "$disk_type_2" = "n" ]; then
	  t_space="True"
	  g_disk=$(echo "${g_disk}G")
	  qemu-img create -f qcow2 /var/lib/libvirt/images/$g_name.qcow2 $g_disk 2>> $error_log >> $status_log
  else
	  echo "Invalid Disk Parameters Detected! Exiting Script"
	  exit
  fi
    echo "Which network will this guest be on? Examples: br0, br1, pub123"
    echo "$networks"
    read ng_network
    clear
    echo "Creating Guest Now.... This should take about 10 seconds"
    guest_creation $os $g_name $g_ram $g_disk $g_vcpu $ng_network 2>> $error_log >> $status_log &

    sleep 10 # Causing the process to sleep allows us to grab the variable

#The port number will now be uniq for each guest created. Example guest1=5900, guest2=5901 and so on
    port=$(virsh dumpxml $g_name | grep vnc | awk '{print $3}' | awk -F "=" '{print $2}' | tail -c +2 | sed 's/.$//')
    echo "Once guest creation has started you will need to use VNC to finish installation"
    echo "Example: On your LOCAL MACHINE type the command: ssh $user@$host -N -f -L $port:127.0.0.1:$port"
    echo "If sshing to $host fails then you will need to use the IP of $host instead of the hostname"
    echo "This will create connection to this server on port $port"
    echo "Then connect your LOCAL VNC viewer to 127.0.0.1:$port to complete install."
    exit
  elif [ "$os2" = "n" ]; then
    echo "Install aborted by user"
    exit
  else
    echo "Invalid Option. Exiting"
    exit
  fi
elif [ "$os" = "6" ]; then
  echo "Exiting Script"
  exit
else
  echo "Exiting script. No valid option selected"
  exit
fi
