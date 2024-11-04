#!/bin/bash

# Check if the script is being run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Check for required parameters or prompt for input
if [ $# -ne 2 ]; then
    read -p "Enter username: " NEW_USER
    read -sp "Enter password: " NEW_PASSWORD
    echo
else
    NEW_USER=$1
    NEW_PASSWORD=$2
fi

# Update the package list and upgrade all packages to their latest versions
echo "Updating package list and upgrading packages..."
apt update && apt upgrade -y

# Install all necessary packages
echo "Installing necessary packages..."
apt install -y xfce4 xfce4-goodies xrdp net-tools wget ethtool flatpak

# User Creation
# Add the user with the specified username and password
echo "Creating new user..."
useradd -m -s /bin/bash "$NEW_USER"
echo "$NEW_USER:$NEW_PASSWORD" | chpasswd
# Add the user to the sudo group for administrative rights
usermod -aG sudo "$NEW_USER"

# XRDP Configuration
# Configure xrdp to use XFCE desktop
echo "startxfce4" > /home/"$NEW_USER"/.xsession
chown "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.xsession

# Restart xrdp service to apply new configuration
echo "Configuring xrdp..."
systemctl restart xrdp
# Enable xrdp at startup
systemctl enable xrdp

# Install Firefox with Flatpak
echo "Installing Firefox..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.mozilla.firefox

# Set Firefox as default browser
update-alternatives --install /usr/bin/x-www-browser x-www-browser /var/lib/flatpak/exports/bin/org.mozilla.firefox 200
update-alternatives --set x-www-browser /var/lib/flatpak/exports/bin/org.mozilla.firefox

# Create the systemd service file for network configuration
echo "Creating systemd service for network configuration..."
tee /etc/systemd/system/eth0-config.service > /dev/null <<EOL
[Unit]
Description=Configure eth0 network interface
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s eth0 speed 1000 duplex full autoneg off
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd to recognize the new service
systemctl daemon-reload
# Enable the service to start on boot
systemctl enable eth0-config.service
# Start the service immediately
systemctl start eth0-config.service

# Clear command history
history -w
history -c

# Print installation completion message
echo -e "
#################################################
# Installation completed.
#################################################
Components installed and started:
- XFCE Desktop
- xrdp
- Firefox
- Network configuration service
"
