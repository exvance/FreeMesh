<?php


//http://192.168.2.1/GetNodeInfo.php?wlan0=00:90:A9:13:58:B1&wlan1=00:90:A9:13:58:B3&secret=8a7fcc966ed0691ff2809e1f38c16996&nasid=000000000001&ip=192.168.2.1

ini_set('display_startup_errors',1);
ini_set('display_errors',1);
error_reporting(-1);

header("Content-Type: text/plain");

$topfile = "/etc/topology";

// A. Make sure the secret querystring parameter matches the output of the command in 1.d above.

  $secretout = trim(shell_exec("uci get FreeMesh.config.secret"));
  $secretQS = trim($_GET["secret"]);

  if("$secretout" != "$secretQS"){
	exit("wrong secret!");
  }

// B. Open the MeshTopology file (If it doesn't exist then create it).

  if(!file_exists($topfile)){
      touch($topfile);
  }
  
// The first column is wlan0 mac addresses.  
// Search this file for the wlan0 querystring parameter.  
// If the wlan0 mac is found then update that line.  

  $contents = file($topfile);
  $newContents = "";
  $nodeFound = false;
  $wlan0QS = trim($_GET["wlan0"]);
  $nasidQS = trim($_GET["nasid"]);
  $ipQS = trim($_GET["ip"]);

  foreach($contents as $line) {
     if (strpos(trim($line), ',') !== false) {
     	$nodeData = explode(",", $line);
	$currentMac = strtolower(trim($nodeData[0]));
     	$currentIP = ip2long(trim($nodeData[2]));
	if(strtolower("$wlan0QS") == strtolower("$currentMac")){
	    $nodeFound = true;
	    //update
	    $newContents .= trim("$nodeData[0],$nasidQS,$ipQS")."\n";
     	}else{
	    $newContents .= trim("$nodeData[0],$nodeData[1],$nodeData[2]")."\n";
	}
     }
  }

// If it is not found then add a row.  It is in this format:
// <<wlan0>>,<<nasid>>,<<ip>>

   if(!$nodeFound){
      $newContents .= trim("$wlan0QS,$nasidQS,$ipQS")."\n";
   }

   file_put_contents($topfile, $newContents);

//Save the file back to disk with any updates or additions to lines.

// C. Return the full contents of the Topology file (including updates from b above).

   exit($newContents);

?>