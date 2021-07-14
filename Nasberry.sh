#!/bin/sh
# Set current Time
sudo date -s "$(curl -s --head http://google.com.au | grep ^Date: | sed 's/Date: //g')"

# Install necessary Packages and ZFS
sudo apt update
sudo apt install -y samba zfs-dkms cockpit

# Start ZFS Module before reboot
sudo /sbin/modprobe zfs 

# Set first Samba Password
sudo smbpasswd -x pi
(echo NasBerry2021; echo NasBerry2021) |sudo smbpasswd -a pi

# Get ZFS Addon for Cockpit
git clone https://github.com/optimans/cockpit-zfs-manager.git
sudo cp -r cockpit-zfs-manager/zfs /usr/share/cockpit

# Install zfs-auto-snapshot and change Retention from 24 to 48h and 12 to 3 Month for more sense of usage
sudo apt install -y zfs-auto-snapshot
sudo sed -i 's/24/48/g' /etc/cron.hourly/zfs-auto-snapshot
sudo sed -i 's/12/3/g' /etc/cron.monthly/zfs-auto-snapshot

# change hostname
sudo sed -i 's/debian/nasberry/g' /etc/hostname

# ask for deletion of existing data and create Mirror 
whiptail --title "Possible data loss!" \
--backtitle "NASBEERY SETUP" \
--yes-button "PRESERVE DATA" \
--no-button  "FORMAT DISKS!" \
--yesno "Would you like to preserve you existing ZFS data from a previous installation?" 10 75

# Get exit status
# 0 means user hit [yes] button.
# 1 means user hit [no] button.
# 255 means user hit [Esc] key.
response=$?
case $response in
   0) echo "Your ZFS Data will be preserved";;
   1) echo "Existing data on the drives will be deleted..."
      sudo zpool create -f -o autoexpand=on -o ashift=12 tank sdb;;
   255) echo "[ESC] key pressed >> EXIT" &&  exit;;
esac

# create Share with Compression, Samba share has to be in smb.conf to work with Snapshots later
sudo zfs create -o compression=lz4 tank/share
sudo chmod -R 770 /tank
sudo chown -R pi:root /tank

# Add to smb.conf how ZFS Snapshots

echo "[share]\ncomment = Main Share\npath = /tank/share\nread only = No\nvfs objects = shadow_copy2\nshadow: snapdir = .zfs/snapshot\nshadow: sort = desc\nshadow: format = -%Y-%m-%d-%H%M\nshadow: snapprefix = ^zfs-auto-snap_\(frequent\)\{0,1\}\(hourly\)\{0,1\}\(daily\)\{0,1\}\(monthly\)\{0,1\}\nshadow: delimiter = -20\n" | sudo tee -a "/etc/samba/smb.conf"


# Change password for Samba and Terminal
while [[ "$PASSWORD" != "$PASSWORD_REPEAT" || ${#PASSWORD} -lt 8 ]]; do
  PASSWORD=$(whiptail --backtitle "NASBEERY SETUP" --title "Set password!" --passwordbox "${PASSWORD_invalid_message}Please set a password for Terminal, Samba and Backupwireless\n(At least 8 characters!):" 10 75 3>&1 1>&2 2>&3)
  PASSWORD_REPEAT=$(whiptail --backtitle "NASBEERY SETUP" --title "Set password!" --passwordbox "Please repeat the Password:" 10 70 3>&1 1>&2 2>&3)
  PASSWORD_invalid_message="ERROR: Password is too short, or not matching! \n\n"
done

echo "pi:$PASSWORD" | sudo chpasswd
(echo "$PASSWORD"; echo "$PASSWORD") | sudo smbpasswd -a pi


sudo reboot
