#!/bin/sh

DEBUG=0

INT0="wlan0"
MAC0=$(ifconfig "$INT0" | grep HWaddr | awk '{print $5}')

INT1="wlan1"
MAC1=$(ifconfig "$INT1" | grep HWaddr | awk '{print $5}')

NET="192.168.2." # subnet without last number

INIT=$(uci get FreeMesh.config.IsIntialized)

TOPOLOGY_FILE="/etc/topology"
TOPOLOGY_TMP_FILE="/tmp/topology.tmp"
CONFIG='/etc/config/wireless'

FIRST_NODE_IP="192.168.2.1"

GET="/usr/bin/wget -q -t1 -T3 -O - "
#GET="curl -s --retry 0 --connect-timeout 3 -m 3"

ACTIVEWAN=0

# Generates 128-bit hex string
randomHash(){
    cat /dev/urandom | tr -dc 'a-f0-9' | head -c 32
}

# Generates 12 digit number
randomNum(){
    cat /dev/urandom | tr -dc '0-9' | head -c 12
}

# Returns ips from arp table
arpTable(){
  grep "$NET" /proc/net/arp | grep -v "00:00:00:00:00:00" | awk '{print $1}'
}

ip2int(){
  if [[ ! -z $1 ]]; then
    A=$(echo $1 | cut -d '.' -f1)
    B=$(echo $1 | cut -d '.' -f2)
    C=$(echo $1 | cut -d '.' -f3)
    D=$(echo $1 | cut -d '.' -f4)
    echo $(($A<<24|$B<<16|$C<<8|$D))
  else
    echo "ip2int(): no param"
    exit
  fi
}

int2ip(){
  if [[ ! -z $1 ]]; then
    A=$((($1 & 0xff000000)>>24))
    B=$((($1 & 0x00ff0000)>>16))
    C=$((($1 & 0x0000ff00)>>8))
    D=$(($1 & 0x000000ff))
    echo $A.$B.$C.$D
  else
    echo "int2ip(): no param"
    exit
  fi
}

# Get MAC from line
macOf(){
  if [[ ! -z $1 ]]; then
    echo $1 | cut -d ',' -f1
  else
    echo "macOf(): no param"
    exit
  fi
}

# 000000000001 -> 00:00:00:00:00:01
nassid2mac(){
  if [[ ! -z $1 ]]; then
    echo $1 | sed "s/.\{2\}/&:/g" | sed s'/.$//'
  else
    echo "nassid2mac(): no param"
    exit
  fi
}

# Write Node to /etc/config/wireless r0kh and r1kh entries
WriteNodes(){
  while read fline; do
    if [[ ! -z "$fline" ]]; then
      local mac=$(echo $fline | cut -d ',' -f1)
      local nasid=$(echo $fline | cut -d ',' -f2)
      sed -i "/r1_key_holder/a\\$(echo -e '\t')option r1kh $mac,$(nassid2mac $nasid),$mySecret" $CONFIG
      sed -i "/r1_key_holder/a\\$(echo -e '\t')option r0kh $mac,$nasid,$mySecret" $CONFIG
    fi
  done < $TOPOLOGY_FILE
}

# Alternative version
# WriteNodes(){
#     local TMP='/tmp/sed.tmp'
#     sed '/r1_key_holder/q' $CONFIG > $TMP # 1st part
#     while read fline; do
#         if [[ ! -z "$fline" ]]; then
#             local mac=$(echo $fline | cut -d ',' -f1)
#             local nasid=$(echo $fline | cut -d ',' -f2)
#             printf "\toption r0kh $mac,$nasid,$mySecret\n" >> $TMP
#             printf "\toption r1kh $mac,$(nassid2mac $nasid),$mySecret\n" >> $TMP
#         fi
#     done < $TOPOLOGY_FILE
#     # add new line
#     printf "\n" >> $TMP
#     sed '/r1_key_holder/,$d' $CONFIG >> $TMP # 2nd part
#     cat $TMP > $CONFIG
# }

lightWDBlue(){
  for i in $(seq 1 27); do 
    echo "$echoVar" > /sys/class/leds/wd\:blue\:internet/brightness
    echo "$echoVar" > /sys/class/leds/wd\:blue\:power/brightness
    echo "$echoVar" > /sys/class/leds/wd\:blue\:wireless/brightness
    echo "$echoVar" > /sys/class/leds/wd\:blue\:wps/brightness

    echo "$echoVar"

    sleep 1

    if [ "$echoVar" == "0" ]; then
      echoVar="1";
    else
      echoVar="0";
    fi
  done
}


#
# this is just to fill the arp table.
# Works in parallel mode, split on two parts to decrease resource usage (Extreamly fast)
#
for i in $(seq 1 128); do (ping -c 1 -w 3 "$NET$i" &> /dev/null &); done
sleep 4
for i in $(seq 129 254); do (ping -c 1 -w 3 "$NET$i" &> /dev/null &); done
sleep 4

if [[ "$DEBUG" == 1 ]]; then echo "INIT = $INIT"; fi

if [[ "$INIT" == 0 ]]; then
#   Do the following:
#
# 1. Authenticate on the Network
  if [[ "$DEBUG" == 1 ]]; then echo "#1"; fi
  mySecret=""
  myNasid=$(randomNum)

  for ip in $(arpTable); do
    if [[ "$ip" != "$NET\254" ]]; then
      mySecret=$($GET "http://$ip/RequestAuthorization.php?wlan0=$MAC0&wlan1=$MAC1")

      if [[ "$DEBUG" == 1 ]]; then echo "wget http://$ip/RequestAuthorization.php?wlan0=$MAC0&wlan1=$MAC1"; fi

      if [[ "$mySecret" != "" ]]; then
        if [[ "$DEBUG" == 1 ]]; then echo "[FOUND] mySecret = $mySecret on $ip -> BREAK"; fi
        break # break out of loop
      fi
    fi
  done

  if [[ "$mySecret" == "" ]]; then
    # this must be the first node.
    mySecret=$(randomHash)
    if [[ "$DEBUG" == 1 ]]; then echo "[NEW] mySecret = $mySecret"; fi
  fi

  if [[ "$DEBUG" == 1 ]]; then echo "[*] SET secret=$mySecret, nasid=$myNasid, r1_key_holder=$myNasid"; fi

  uci set FreeMesh.config.secret="$mySecret"
  uci commit FreeMesh

  uci set wireless.@wifi-iface[0].nasid="$myNasid"
  uci set wireless.@wifi-iface[0].r1_key_holder="$myNasid"
  uci commit wireless
#
# 2. Find next available IP and set it:
#    Doing it this way accounts for nodes that have been added to the network but may not be online at the moment. 
  if [[ "$DEBUG" == 1 ]]; then echo "#2"; fi

  HighestIP=$FIRST_NODE_IP # this will get set for the first node

  for ip in $(arpTable); do
    thisIP=$($GET "http://$ip/GetHighestIP.php?wlan0=$MAC0&secret=$mySecret")
    if [[ "$DEBUG" == 1 ]]; then echo "wget http://$ip/GetHighestIP.php?wlan0=$MAC0&secret=$mySecret"; fi

    if [[ $thisIP ]] && [[ $(ip2int $thisIP) -gt $(ip2int $HighestIP) ]]; then
      if [[ "$DEBUG" == 1 ]]; then echo "[UPDATE] HighestIP: $HighestIP -> $thisIP"; fi

      HighestIP=$thisIP
    fi
  done

  myIP=$(int2ip $(($(ip2int $HighestIP) + 1)))
  if [[ "$DEBUG" == 1 ]]; then echo "[*] SET network.lan.ipaddr = $myIP"; fi

  uci set network.lan.ipaddr="$myIP"
  uci commit network
  /etc/init.d/network restart &> /dev/null

  sleep 2

  lightWDBlue
fi

#
# 3. Populate local mesh topology file (and /etc/config/wireless):
myIP=$(uci get network.lan.ipaddr)
mySecret=$(uci get FreeMesh.config.secret)
if [[ "$DEBUG" == 1 ]]; then echo -e "#3\nmyIP = $myIP and mySecret = $mySecret"; fi

# Make sure file topology exists and clear tmp file
if [[ ! -f $TOPOLOGY_FILE ]]; then
  touch $TOPOLOGY_FILE
fi
: > $TOPOLOGY_TMP_FILE

for ip in $(arpTable); do
    ThisTopology=$($GET "http://$ip/GetNodeInfo.php?wlan0=$MAC0&wlan1=$MAC1&secret=$mySecret&ip=$myIP&nasid=$myNasid")
    if [[ "$DEBUG" == 1 ]]; then echo "wget http://$ip/GetNodeInfo.php?wlan0=$MAC0&wlan1=$MAC1&secret=$mySecret&ip=$myIP&nasid=$myNasid"; fi

    if [[ "$ThisTopology" ]]; then
      if [[ "$DEBUG" == 1 ]]; then echo "GOT ThisTopology from $ip"; fi
    # update nodes
      while read fline; do
        if [[ ! -z "$fline" ]]; then
          for wline in $ThisTopology; do
            if macOf $fline | grep -i $(macOf $wline) &> /dev/null; then
              echo "$wline" >> $TOPOLOGY_TMP_FILE
              if [[ "$DEBUG" == 1 ]]; then echo "$wline [UPDATE]"; fi
              continue 2
            fi
          done
          echo $fline >> $TOPOLOGY_TMP_FILE
          if [[ "$DEBUG" == 1 ]]; then echo "$fline"; fi
        fi
      done < $TOPOLOGY_FILE
    # add new nodes
      for wline in $ThisTopology; do
        while read fline; do
          if [[ ! -z "$fline" ]]; then
            if macOf $fline | grep -i $(macOf $wline) &> /dev/null; then
              continue 2
            fi
          fi
        done < $TOPOLOGY_TMP_FILE
        echo "$wline" >> $TOPOLOGY_TMP_FILE
        if [[ "$DEBUG" == 1 ]]; then echo "$wline [NEW]"; fi
      done
    fi
done

cat $TOPOLOGY_TMP_FILE > $TOPOLOGY_FILE

if [[ "$DEBUG" == 1 ]]; then echo "[*] Clear entries and write new $CONFIG, set IsIntialized=1"; fi

# Clear all option r0kh and r1kh entries in /etc/config/wireless
sed -i -E '/option r[0-1]{1}kh/d' $CONFIG

# Write nodes from topology file to /etc/config/wireless
WriteNodes

# Restart Wifi
wifi

uci set FreeMesh.config.IsIntialized="1"
uci commit FreeMesh

if [[ "$DEBUG" == 1 ]]; then echo "Start ping google ..."; fi

while true; do
  # Check if we have access to the Internet
  if ping -c 1 google.com &> /dev/null; then
    echo "ACTIVE" > /www/WAN
    ACTIVEWAN=1
    /etc/init.d/dnsmasq enable &> /dev/null
    /etc/init.d/dnsmasq start &> /dev/null
    /etc/init.d/odhcpd enable &> /dev/null
    /etc/init.d/odhcpd start &> /dev/null
    sleep 15
  # If not
  else
    echo "OFFLINE" > /www/WAN

    # We should only do this if this node has had an Active WAN connection in the past.
    # This is a passive search for a new active WAN connection on the network.
    # If we find one then we should disable stuff.  Until then we will assume that
    # we are just having a temporary interuption in Internet.

    if [[ "$ACTIVEWAN" == 1 ]]; then 
  
      # This ensures that an device that was recently added to the network will be in the arp table.
      for i in $(seq 1 128); do (ping -c 1 -w 3 "$NET$i" &> /dev/null &); done
      sleep 4
      for i in $(seq 129 254); do (ping -c 1 -w 3 "$NET$i" &> /dev/null &); done
      sleep 4

      for ip in $(arpTable); do
        if [[ "$myIP" != "$ip" ]]; then
          STATUS=$($GET "http://$ip/WAN")
          if [[ "$STATUS" == "ACTIVE" ]]; then
            # Looks like we found another active WAN on the network so let's disable stuff
            /etc/init.d/dnsmasq stop &> /dev/null
            /etc/init.d/dnsmasq disable &> /dev/null
            /etc/init.d/odhcpd stop &> /dev/null
            /etc/init.d/odhcpd disable &> /dev/null

            # Don't search anymore.  Let's assume this node is no longer the WAN.
            ACTIVEWAN=0
          fi
        fi
      done
      sleep 15
    fi
  fi
done
