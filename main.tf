terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.61.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {

  }
}

#Resource gorup
resource "azurerm_resource_group" "mtc_rg" {
  name     = "mtc-resources"
  location = "Canada Central"

  tags = {
    Environment = "dev"
  }
}

#vnet
resource "azurerm_virtual_network" "mtc_vnet" {
  name                = "mtc-network"
  location            = azurerm_resource_group.mtc_rg.location
  resource_group_name = azurerm_resource_group.mtc_rg.name
  address_space       = ["10.123.0.0/16"] #list

  tags = {
    environment = "Production"
  }

  depends_on = [
    azurerm_resource_group.mtc_rg
  ]
}

#subnet
resource "azurerm_subnet" "mtc_subnet" {
  name                 = "mtc-subnet"
  resource_group_name  = azurerm_resource_group.mtc_rg.name
  virtual_network_name = azurerm_virtual_network.mtc_vnet.name
  address_prefixes     = ["10.123.1.0/24"]

  depends_on = [
    azurerm_virtual_network.mtc_vnet
  ]
}

#nsg
resource "azurerm_network_security_group" "mtc_nsg" {
  name                = "mtc-nsg"
  location            = azurerm_resource_group.mtc_rg.location
  resource_group_name = azurerm_resource_group.mtc_rg.name

  tags = {
    environment = "dev"
  }
}

#network security rule 
resource "azurerm_network_security_rule" "mtc_dev_rule" {
  name                        = "mtc-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "27.147.155.186"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc_rg.name
  network_security_group_name = azurerm_network_security_group.mtc_nsg.name

  depends_on = [
    azurerm_network_security_group.mtc_nsg
  ]
}

resource "azurerm_subnet_network_security_group_association" "mtc_sga" {
  subnet_id                 = azurerm_subnet.mtc_subnet.id
  network_security_group_id = azurerm_network_security_group.mtc_nsg.id

  depends_on = [
    azurerm_network_security_group.mtc_nsg,
    azurerm_subnet.mtc_subnet
  ]
}

#public ip
resource "azurerm_public_ip" "mtc_ip" {
  name                = "mtc-ip"
  resource_group_name = azurerm_resource_group.mtc_rg.name
  location            = azurerm_resource_group.mtc_rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Dev"
  }
}

#nic
resource "azurerm_network_interface" "mtc_nic" {
  name                = "mtc-nic"
  location            = azurerm_resource_group.mtc_rg.location
  resource_group_name = azurerm_resource_group.mtc_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc_ip.id
  }

  tags = {
    environment = "dev"
  }

  depends_on = [
    azurerm_subnet.mtc_subnet,
    azurerm_public_ip.mtc_ip
  ]
}

#linux vm
resource "azurerm_linux_virtual_machine" "mtc_vm" {
  name                = "mtc-vm"
  resource_group_name = azurerm_resource_group.mtc_rg.name
  location            = azurerm_resource_group.mtc_rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mtc_nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub") #reads a file & substritute it's content for value. 
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.mtc_nic
  ]
}