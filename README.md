# **KVM-GUEST-CREATION SCRIPT**

*If viewing this file on a linux machine using vim you might want to view it from the following URL. It will make the reading easier on the eyes*

http://gitlab/jhowellburke/kvm-guest-creation

This script is designed to automate KVM guest creation. It's designed to run on Linux host's running CentOS, Debian or Ubuntu. The script needs to be run as root from the
/root/kvm-guest-creation directory.

In order for all options to be enabled the host will need to have virt-install installed. If not then only option "4. Import Existing Guest from another Host" will be enabled. This scenario is okay for most of our older hosts since they won't have virt-install installed. For the older hosts we just need to copy the guest .qcow2 image file from the host it's being migrated from to the new host's /var/lib/libvirt/images directory and select option "4. Import Existing Guest from another Host"


**NOTE:**

If for any reason you make any changes to any of the guest_creation.sh scripts that have already been placed on host's please make sure to back up the existing script and once done remove the newly modified one and leave the original. Doing this will help us keep the correct script across all host's. If you would like to add additional functionality to the script and or remove options or a function then please do so by going to:
http://gitlab/jhowellburke/kvm-guest-creation/branches and click on the green "New branch" button. Then give your new branch a name. Once tested and verified we can add it to the master copy. This is because any changes to the master copy of the guest_creation.sh script needs to be added to the kvm-guest-creation.tar.gz package on the fileserver in order to have the latest updated version available when the script is run on newly created host's. I figured doing it this way makes this project more scalable going forward. Thanks everyone for your help.

**Option to import guest's to host's running OpenVswitch has been added. This only applies to guest's being imported to a host with OpenVswitch. (Menu Option 4) This _DOES NOT_ apply to Menu Options 1,2,3, and 5. I am still working on adding this feature to these options.**

**This script is only designed to import a guest with ONE image file. If the guest being imported has 2 images files then this script will not be able to import it. I plan on adding this functionality in the future.**

## **Installation and Setup**

The script along with the needed files are stored on the fileserver(192.168.1.2) in the /data/ISO/kvm-guest-creation-isos directory. It is the kvm-guest-creation.tar.gz file.

first you will need to be in the /root directory of the host you will be creating/importing guest's to.

	cd /root

Next we will need to grab the needed files from the fileserver(192.168.1.2). We should be in the /root directory at this point. To retrieve the needed files type:
(Don't forget the "." at the end of the command)

	scp root@192.168.1.2:/data/ISO/kvm-guest-creation-isos/kvm-guest-creation.tar.gz .

This will copy over the tar file to the /root directory of the host. You will need to decompress the file using the following command:

	tar -zxvf kvm-guest-creation.tar.gz

This will create the needed directory with the needed files. At this point you will need to type:

	cd kvm-guest-creation

This will put you in the kvm-guest-creation directory and to run the script using the following command:

	./guest-creation.sh

The first time you run the script it'll take some time to complete since it needs to go and grab the needed ISO's and put them in their respective places. After it's been run once it won't need to retrieve the ISO's again since they are now stored locally, so the script will run much faster from then on. If for some reason one of the needed ISO's is missing from the specified directory then it will attempt to retrieve all the files again. Either way the script has be run at least once in order to create the required directories and files.

The script will create a status-log and error-log to track progress. As for the status-log file it's just for stdout (Standard Output). The error-log is where you will want to check if the script fails for any reason. All errors generated from stderr (Standard Error) are redirected to this file. I believe I captured most of the stout's and stderr's in these files. There is a chance some of these outputs will be redirected to stdout if you run into an error that I have not accounted for. If you do run into any errors that are not being accounted for please create a "New Issue" at http://gitlab/jhowellburke/kvm-guest-creation/issues.


## **Menu Options Breakdown**


## **CREATING NEW GUEST'S FROM SCRATCH (OPTIONS 1,2,3,)**

For these options just select the menu number associated with the distro you need. Give it a name, determine how much RAM it will have (1=1GB), determine how many vcpu's it will have (1=1vcpu), next determine how big the image file will be (10=10GB). You will be asked if you want to create a static disk or a dynamic disk:

		Do you want to reserve the full 10 GB's on the disk now? Or do you want the disk to grow as data is added to it?
		y = Reserve full 10 GB's on disk.
		n = Create image that grows up 10 GB as data is added to it.

A static disk will automatically take up all the space you specify for the image size. Whereas a dynamic disk will grow as data is added to it until it reaches the full capacity you specified. There are benifits to both types. Just select the option that fits your needs best. Lastly select which bridge the new guest will use. Depending on how many bridges the host has will determine how many are available at this stage. If only 1 bridge then it will only give you 1 option. If 2 bridges exist it will list those also. Example:

		Which network will this guest be on? Example: br0 or br1
		br0:
		123
		br4:
		321
		The bridge name will be listed above the network it belongs to. So in this case br0 belongs to the 243 network, and br4 belongs to the 99 network.

It will then prompt you to verify if the settings all look correct. Select "y" for yes if it all looks correct. It will then create the new guest. It should only take 10 seconds to complete.
At this point the guest has been created and has been started booting off of the CD of the distro you selected. At his point you will need to finish installation by doing the following:

Once guest installation has started you will need to use VNC to connect to the guest. The instructions will be shown to you when your at that point. You will **NOT** have console access to the guest from the host during installation. You will need to use VNC to completely finish the installation process. Once installation is finished and guest is rebooted it may or may not have an IP address depending on how you configured the networking on the guest. Regardless if networking is configured or not you will ALWAYS have access to the guest using the VNC command "ssh user@host_server_ip -f -N -L port:127.0.0.1:port" on your LOCAL machine. Then use whatever VNC application you use on your LOCAL machine to connect to 127.0.0.1:port. This will give you access to the guest regardless if SSH or Console access is available. I am still working on a way to enable console access during guest creation and installation process, but have not added that functionality as of yet.

Due to the way the script interacts with the guest installation for options 1-3 & 5 you may need to issue the "virsh destroy guest-name" twice in order to completely shutdown the guest. This is because of how the script grabs the unique VNC port number for each guest that is created. This only applies the first time you need to shutdown the guest. After the first time it will shutdown the first time the command is issued.


## **IMPORTING EXISTING GUEST'S FROM ANOTHER HOST (OPTION 4)**

When selecting option "4. Import Existing Guest from another Host" **YOU DO NOT NEED TO MIGRATE THE GUEST'S XML FILE**. Depending on what OS the host is running attempting to define the guest with the old XML file will **FAIL**. Also make sure that you **DO NOT** place any of the XML files in the /var/lib/libvirt/images directory. Only place the images (qcow2) files in this directory.

All you need to do is place the image file (Example: guest.qcow2) in the /var/lib/libvirt/images directory. Then run the script and select option 4. It will ask you if the guest image file has been placed in the /var/lib/libvirt/images directory. If the image is not there then hit "n" and the script will inform you where you need to place the image and exit the script. Place the image in correct directory and re-run the script. Run script and select option "4. Import Existing Guest from another Host" again and now when prompted hit "y".

At this point it will ask you for the name of the guest that is being imported. The name can be the same as the existing guest name or you can make a new name. It will then ask you how many vcpu's you will want. Next it will ask you how much RAM you would like. The RAM has to be in kiB since this is how it's defined in the guest's xml files. A helpful converter can be found at: http://www.dr-lex.be/info-stuff/bytecalc.html.

Next it will prompt you for the network information.
Depending on how many bridges the host has will determine how many are available at this stage. If only 1 bridge then it will only give you 1 option. If 2 bridges exist it will list those also
It will list the different bridges in the following format:

		Which network will this guest be on? Example: br0 or br1
		br0:
		123
		br4:
		321
		The bridge name will be listed above the network it belongs to. So in this case br0 belongs to the 243 network, and br4 belongs to the 99 network.

Now this next part is **IMPORTANT**. It will prompt you "What is the name of the imported guest image? Example: guest.qcow2" The name you type here has to match **EXACTLY** with the name of the guest image you placed in the /var/lib/libvirt/images directory. (For example if the guest being imported has a image file named fileserver.qcow2 then you will need to make sure you type fileserver.qcow2) At this point the script will verify if the name you typed matches the image file you placed in the /var/lib/libvirt/images directory. If you accidentally typed the name wrong then it will fail with the following output:

				Unable to verify if the imported guest has a image is in the correct directory
				Double check that guest being imported's image file is in /var/lib/libvirt/images directory
				Then re-run script Double-Check: Did you add .qcow2 extension?
				The image (.qcow2) filename has to match guest image (.qcow2) filename in the /var/lib/libvirt/images directory

If you see this error then it means the name you typed and the image file you placed in the /var/lib/libvirt/images directory do not match. Double check the name and re-run the script. It might be better to just copy the guest image name and paste it your at this step to make sure you get the name correct. If all goes well and the names match it'll output "Imported guest image location verified". Then it will finish up the importing the guest, and start the guest for you. You shouldn't have to configure console access to the imported guest if it had console access on the host it was being imported from.


## **DOWNLOADING A DIFFERENT DISTRO (OPERATING SYSTEM) (OPTION 5)**

This option is if you need to use a distro that is not listed in options 1-3 or if you need a different version then those listed. You will need to get the full URL for the ISO file you need. For example if you needed a different Debian version then the one available you would find the URL and paste it when prompted:

		Example: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-8.0.0-amd64-netinst.iso

Press enter to start downloading the ISO file. It will then begin the retrieval process. Once it's done downloading it will prompt you if you want to start the installation, select "y" and it'll go through the installation steps. At this point in the installation you can scroll up this file and follow the steps provided in the "Creating New Guest's From Scratch (Options 1,2,3,)".
