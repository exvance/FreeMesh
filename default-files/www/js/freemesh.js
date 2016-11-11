var href = document.location.href;
var currentPage = href.substr(href.lastIndexOf('/') + 1);

$(document).ready(function () {		
	switch(currentPage){
		case 'index.html':
			status_load();
			break;
		case 'network.html':
			network_settings();
			break;
		case 'mesh.html':
			wireless_settings();
			break;
	}
});
function save_settings(){
	switch(currentPage){
		case 'index.html':
			$.get("svc/service.php?service=save&page=index", function(data){
				if( data.status == 'success' ){
					//good
				} else {
					//error
				}
			}, "json");
			break;
		case 'network.html':
			$.get("svc/service.php?service=save&page=network", function(data){
				if( data.status == 'success' ){
					//good
				} else {
					//error
				}
			}, "json");
			break;
		case 'mesh.html':
			$.get("svc/service.php?service=save&page=mesh", function(data){
				if( data.status == 'success' ){
					//good
				} else {
					//error
				}
			}, "json");
			break;
	}
}
function status_load(){
	$.get("svc/service.php?service=statusload", function(data){
		if( data.inet_status == true ){
			$("#internet_status").html("Online");
		} else {
			$("#internet_status").html("Offline");
			$("#internet_status").css("color", "red");
		}
	}, "json");
}
function network_settings(){
	$.get("svc/service.php?service=networksettings", function(data){
		if(data.proto == 'dhcp'){
			$('#dhcp_wan').prop('checked', true);
		} else {
			$('#dhcp_wan').prop('checked', false);
		}
		$("#ip_address_wan").val(data.wan_ip);
		$("#subnet_mask_wan").val(data.lan_mask);
		$("#ip_address_lan").val(data.lan_ip);
		$("#subnet_mask_lan").val(data.lan_mask);
		$("#ip_address_start_dhcp").val(data.lan_ip_start);
		$("#ip_address_end_dhcp").val(parseInt(data.lan_ip_start) + parseInt(data.lan_ip_limit));
		$("#lease_time_lan").val(data.lan_lease_time);
	}, "json");
}
function wireless_settings(){}