<?php


//http://192.168.2.1/RequestAuthorization.php?wlan0=00:90:A9:13:58:B1&wlan1=00:90:A9:13:58:B3

ini_set('display_startup_errors',1);
ini_set('display_errors',1);
error_reporting(-1);

header("Content-Type: text/plain");

//If we are the caller then return blank response.
if(trim($_SERVER['SERVER_ADDR']) == "192.168.2.254"){
  exit("");
  exit("Can't get Authorization from yourself.");
}


// A. Ping 192.168.2.254.  Wait up to 10 seconds for a response.  
//    If no response comes in 10 seconds simply return a blank response.

  $pingout = shell_exec('ping -4 -c 1 -w 10 192.168.2.254 2>&1');

  if (strpos($pingout, '0 packets received') !== false) {
      exit("");
      exit("192.168.2.254 didn't respond to ping.");
  }

// B. Check the arp table for the wlan0 mac on the 192.168.2.254 ip address. 

  $wlan0Mac = trim(shell_exec('grep "192.168.2.254" /proc/net/arp | grep -v "00:00:00:00:00:00" | awk \'{print $4}\''));
  $wlan0QS = trim($_GET["wlan0"]);

  if (strtolower($wlan0QS) != strtolower($wlan0Mac)) {
      exit("");
      exit("wlan0 doesn't match arp table.");
  }

// C. The output of this command will either be blank or a number (the $wlan1 is from the querystring):
//    iw dev wlan1 station get $wlan1 2>&1 | grep "signal:" | awk '{print$2}'
//    If the output is blank then return blank.  
//    If it is a number then if the number is greater than or equal to -30 then proceed to "d" below.  
//    If it is less than -30 return blank.

  $wlan1QS = strtolower(trim($_GET["wlan1"]));

  $signalout = shell_exec("iw dev wlan1 station get $wlan1QS 2>&1 | grep \"signal:\" | awk '{print$2}'");

  if( $signalout < -30){
       exit("");
       exit("Signal not strong enough.  It must not be close enough.");
  }

// D. Return the secret.

  $secretout = trim(shell_exec("uci get FreeMesh.config.secret"));

  if(strlen($secretout) != 32){
        exit("");
       	exit("No secret found.");
  }else{
	exit($secretout);
  }
	
?>