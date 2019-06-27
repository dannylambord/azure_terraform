provider "azurerm"{
	version ="=1.30.1"
}

variable "prefix"{
	default = "tfvmex"
}


resource "azurerm_resource_group" "main"{
	name = "${var.prefix}-resources"
	location = "uksouth"
}

resource "azurerm_virtual_network" "main"{
	name = "${var.prefix}-network"
	address_space = ["10.0.0.0/16"]
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "internal"{
	name = "internal"
	resource_group_name = "${azurerm_resource_group.main.name}"
	virtual_network_name = "${azurerm_virtual_network.main.name}"
	address_prefix = "10.0.2.0/24"
}

resource "azurerm_public_ip" "main"{
	name =  "PublicIP"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	allocation_method = "Dynamic"
	domain_name_label = "dlam-unique123123"

	tags = {	
		environment = "staging"
	}
}

resource "azurerm_network_security_group" "main"{
	name = "MyNetworkSecurityGroup"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	
	security_rule{
		name = "SSH"
		priority = 1001
		direction = "Inbound"
		access = "Allow"
		protocol = "Tcp"
		source_port_range = "*"
		destination_port_range = "22"
		source_address_prefix = "*"
		destination_address_prefix = "*"
	}

	security_rule{
		name = "HTML"
		priority = 500
		direction = "Inbound"
		access = "Allow"
		protocol = "Tcp"
		source_port_range = "*"
		destination_port_range = "8080"
		source_address_prefix = "*"
		destination_address_prefix = "*"
	}
	
	tags = {
		environment = "staging"
	}
}

resource "azurerm_network_interface" "main"{
	name = "${var.prefix}-nic"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_security_group_id = "${azurerm_network_security_group.main.id}"

	ip_configuration{
		name = "testconfiguration1"
		subnet_id = "${azurerm_subnet.internal.id}"
		private_ip_address_allocation = "Dynamic"
		public_ip_address_id = "${azurerm_public_ip.main.id}"
	}
	

}

resource "azurerm_virtual_machine" "main"{
	name = "${var.prefix}"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_interface_ids = ["${azurerm_network_interface.main.id}"]
	vm_size = "Standard_DS1_v2"


storage_image_reference{
	publisher = "Canonical"
	offer = "UbuntuServer"
	sku = "16.04-LTS"
	version = "latest"
}

storage_os_disk{
	name = "myosdisk1"
	caching = "ReadWrite"
	create_option = "FromImage"
	managed_disk_type = "Standard_LRS"
}

os_profile{
	computer_name = "hostname"
	admin_username = "dlam"
	
}

os_profile_linux_config{
	disable_password_authentication = true
	ssh_keys {
	path = "/home/dlam/.ssh/authorized_keys"
	key_data = "${file("/home/dlam/.ssh/id_rsa.pub")}"
	}
}

tags = {
	environment = "staging"
}

provisioner "remote-exec"{
	inline = ["sudo apt install git", "git clone https://github.com/dannylambord/install_jenkins.git", "cd install_jenkins", "bash install_jenkins.sh"]

	connection {
		type = "ssh"
		user ="dlam"
		private_key = "${file("/home/dlam/.ssh/id_rsa")}"
		host = "${azurerm_public_ip.main.fqdn}"
}
} 
}
