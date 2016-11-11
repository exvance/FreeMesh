<?php
if( isset($_GET["service"]) && $_GET["service"] != "" ){
	switch($_GET["service"]){
		case 'statusload':
				if( exec("/bin/ping -c1 -W1 8.8.8.8 || echo 'no internet'") == 'no internet' ){
					echo json_encode(array("inet_status" => false));
				} else {
					echo json_encode(array("inet_status" => true));
				}
				break;
		case 'networksettings':
				$proto = exec("uci get network.wan.proto");
				$wan_ip = exec("ubus call network.interface.wan status | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'");
				$lan_ip = exec("uci get network.lan.ipaddr");
				$lan_mask = exec("uci get network.lan.netmask");
				$lan_ip_start = exec("uci get dhcp.lan.start");
				$lan_ip_limit = exec("uci get dhcp.lan.limit");
				$lan_lease_time = exec("uci get dhcp.lan.leasetime");
				
				echo json_encode(array("proto" => $proto, "wan_ip" => $wan_ip, "lan_ip" => $lan_ip, "lan_mask" => $lan_mask,
										"lan_ip_start" => $lan_ip_start, "lan_ip_limit" => $lan_ip_limit, "lan_lease_time" => $lan_lease_time));
				break;
		case 'saveSettings':
				if( isset($_GET["page"]) && $_GET["page"] != "" ){
				
				} else {
					echo json_encode(array("status" => "error"));
				}
				break;
	}
}