#!/bin/bash
echo "VpnHood Installation for linux";

# Default arguments
packageUrl="$packageUrlParam";
versionTag="$versionTagParam";
destinationPath="/opt/VpnHoodServer";
packageFile="";

# Read arguments
for i; 
do
if [ "$i" = "-autostart" ]; then
	autostart="y";
	lastArg=""; continue;

elif [ "$i" = "-q" ]; then
	setDotNet="y";
	quiet="y";
	lastArg=""; continue;

elif [ "$lastArg" = "-restBaseUrl" ]; then
	restBaseUrl=$i;
	lastArg=""; continue;

elif [ "$lastArg" = "-restAuthorization" ]; then
	restAuthorization=$i;
	lastArg=""; continue;

elif [ "$lastArg" = "-packageFile" ]; then
	packageFile=$i;
	lastArg=""; continue;

elif [ "$lastArg" = "-versionTag" ]; then
	versionTag=$i;
	lastArg=""; continue;


elif [ "$lastArg" != "" ]; then
	echo "Unknown argument! argument: $lastArg";
	exit 1;
fi;
lastArg=$i;
done;

# validate $versionTag
if [ "$versionTag" == "" ]; then
	echo "Could not find versionTag!";
	exit 1;
fi
binDir="$destinationPath/$versionTag";

# User interaction
if [ "$quiet" != "y" ]; then
	read -p "Auto Start (y/n)?" autostart;
fi;

# point to latest version if $packageUrl is not set
if [ "$packageUrl" = "" ]; then
	packageUrl="https://github.com/vpnhood/VpnHood/releases/latest/download/VpnHoodServer-linux.tar.gz";
fi

# download & install VpnHoodServer
if [ "$packageFile" = "" ]; then
	echo "Downloading VpnHoodServer...";
	packageFile="VpnHoodServer-linux.tar.gz";
	wget -O $packageFile $packageUrl;
fi

# extract
echo "Extracting to $destinationPath";
mkdir -p $destinationPath;
tar -xzf "$packageFile" -C "$destinationPath"

# override publish info
echo "Updating shared files...";
infoDir="$binDir/publish_info";
cp "$infoDir/update" "$destinationPath/" -f;
cp "$infoDir/vhserver" "$destinationPath/" -f;
cp "$infoDir/publish.json" "$destinationPath/" -f;
chmod +x "$binDir/VpnHoodServer";
chmod +x "$destinationPath/vhserver";
chmod +x "$destinationPath/update";

# Write AppSettingss
if [ "$restBaseUrl" != "" ]; then
	appSettings="{
  \"HttpAccessServer\": {
    \"BaseUrl\": \"$restBaseUrl\",
    \"Authorization\": \"$restAuthorization\"
  }
}
";
	echo "$appSettings" > "$destinationPath/appsettings.json"
fi

# init service
if [ "$autostart" = "y" ]; then
	echo "creating autostart service. Name: VpnHoodService...";
	service="
[Unit]
Description=VpnHood Server
After=network.target

[Service]
Type=simple
ExecStart="$binDir/VpnHoodServer"
ExecStop="$binDir/VpnHoodServer" stop
TimeoutStartSec=0
Restart=always
RestartSec=10
StandardOutput=null

[Install]
WantedBy=default.target
";

	echo "$service" > "/etc/systemd/system/VpnHoodUpdater.service";

	echo "creating VpnHood Updater service. Name: VpnHoodUpdater...";
	service="
[Unit]
Description=VpnHood Server Updater
After=network.target

[Service]
Type=simple
ExecStart="$destinationPath/update"
TimeoutStartSec=0
Restart=always
RestartSec=720min

[Install]
WantedBy=default.target
";
	echo "$service" > "/etc/systemd/system/VpnHoodUpdater.service";

	# Executing services
	echo "Executinh VpnHoodServer services...";
	systemctl daemon-reload;
	
	systemctl enable VpnHoodServer.service;
	systemctl restart VpnHoodServer.service;
	
	systemctl enable VpnHoodUpdater.service;
	systemctl restart VpnHoodUpdater.service;
fi
