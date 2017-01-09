<?php


//http://192.168.2.1/GetHighestIP.php?wlan0=00:90:A9:13:58:B1&wlan1=00:90:A9:13:58:B3&secret=8a7fcc966ed0691ff2809e1f38c16996

ini_set('display_startup_errors',1);
ini_set('display_errors',1);
error_reporting(-1);

header("Content-Type: text/plain");

$topfile = "/etc/topology";

$wlan0QS = strtolower(trim($_GET["wlan0"]));

// A. Make sure the secret querystring parameter matches the output of the command in 1.d above.

  $secretout = trim(shell_exec("uci get FreeMesh.config.secret"));
  $secretQS = trim($_GET["secret"]);

  if("$secretout" != "$secretQS"){
	exit("wrong secret!");
  }

// B. Make sure the /etc/topology file exists.  If it doesn't then create it and return 192.168.2.0.

  if(!file_exists($topfile)){
      touch($topfile);
      exit("192.168.2.0");
  }


// C. Read the attached MeshTopology file and return the highest ip address. 

  $highestIPAsLong = ip2long("192.168.2.0");

  $contents = file($topfile);

  foreach($contents as $line) {
     if (strpos(trim($line), ',') !== false) {
     	$nodeData = explode(",", $line);
	$currentMac = strtolower(trim($nodeData[0]));
     	$currentIP = ip2long(trim($nodeData[2]));
	if("$wlan0QS" == "$currentMac"){
	    // We are subtracting one because the calling script is going to add one.
	    // Essentially, this makes it so that if a node has been setup on the network
            // before and is calling this again (which means it was reset) it will get the
	    // same ip it had before.
	    exit(long2ip($currentIP - 1));
     	}
	else if($currentIP > $highestIPAsLong){
	    $highestIPAsLong = $currentIP;
     	}
     }
  } 

  exit(long2ip($highestIPAsLong));

?>