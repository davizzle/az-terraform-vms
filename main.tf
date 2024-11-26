provider "azurerm" {  

   features {}

}

resource "azurerm_resource_group" "web_stack" {
  name     = "WebInfraResourceGroup"
  location = "East US"
}

# Create virtual network

resource "azurerm_virtual_network" "vnet" {
  name                = "WebInfraVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.web_stack.location
  resource_group_name = azurerm_resource_group.web_stack.name
}

# Create subnets

resource "azurerm_subnet" "web_tier" {
  name                 = "WebTierSubnet"
  resource_group_name  = azurerm_resource_group.web_stack.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "db_tier" {
  name                 = "DBTierSubnet"
  resource_group_name  = azurerm_resource_group.web_stack.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "webstack_public_ip" {
  name                = "webstack_public_ip"
  location            = azurerm_resource_group.web_stack.location
  resource_group_name = azurerm_resource_group.web_stack.name
  allocation_method   = "Dynamic"
}


#Create NSG and NSG rule

resource "azurerm_network_security_group" "web_tier_nsg" {
  name                = "WebTierNSG"
  location            = azurerm_resource_group.web_stack.location
  resource_group_name = azurerm_resource_group.web_stack.name
}

resource "azurerm_network_security_rule" "allow_http_https" {
  name                       = "AllowHTTPHTTPS"
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_ranges    = ["80", "443"]
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.web_tier_nsg.name
}


# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "myNIC"
  location            = azurerm_resource_group.web_stack.location
  resource_group_name = azurerm_resource_group.web_stack.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.web_tier.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webstack_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "web_tier_nsg_association" {
  count = length(azurerm_network_interface.web_tier_nic)
  network_interface_id      = azurerm_network_interface.web_tier_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.web_tier_nsg.id
}

resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.storage.hex}" # Ensure globally unique name
  location                 = azurerm_resource_group.web_stack.location
  resource_group_name      = azurerm_resource_group.web_stack.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_id" "storage" {
  byte_length = 4
}

# Create Availability Set
resource "azurerm_availability_set" "web_tier_availability_set" {
  name                = "WebTierAvailabilitySet"
  location            = azurerm_resource_group.web_stack.location
  resource_group_name = azurerm_resource_group.web_stack.name
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
}

# Create Web Tier VMs
resource "azurerm_windows_virtual_machine" "web_tier" {
  count                = 2
  name                 = "WebTierVM-${count.index}"
  location             = azurerm_resource_group.web_stack.location
  resource_group_name  = azurerm_resource_group.web_stack.name
  size                 = "Standard_D2s_v3"
  availability_set_id  = azurerm_availability_set.web_tier_availability_set.id
  network_interface_ids = [azurerm_network_interface.web_tier_nic[count.index].id]
  admin_username       = var.admin_username
  admin_password       = var.admin_password
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

# NIC for Web Tier VMs
resource "azurerm_network_interface" "web_tier_nic" {
  count                = 2
  name                 = "WebTierNIC-${count.index}"
  location             = azurerm_resource_group.web_stack.location
  resource_group_name  = azurerm_resource_group.web_stack.name

  ip_configuration {
    name                          = "WebNICConfig-${count.index}"
    subnet_id                     = azurerm_subnet.web_tier.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create Database Tier VM
resource "azurerm_windows_virtual_machine" "db_tier" {
  name                 = "DBServer"
  location             = azurerm_resource_group.web_stack.location
  resource_group_name  = azurerm_resource_group.web_stack.name
  size                 = "Standard_D4s_v3"
  network_interface_ids = [azurerm_network_interface.db_tier_nic.id]
  admin_username       = var.admin_username
  admin_password       = var.admin_password
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  ## future enhancement - allow this to be switched on/off
  identity {
    type = "SystemAssigned"
  }
}

# NIC for Database Tier VM
resource "azurerm_network_interface" "db_tier_nic" {
  name                 = "DBTierNIC"
  location             = azurerm_resource_group.web_stack.location
  resource_group_name  = azurerm_resource_group.web_stack.name

  ip_configuration {
    name                          = "DBNICConfig"
    subnet_id                     = azurerm_subnet.db_tier.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Load Balancer for Web Tier
resource "azurerm_lb" "web_lb" {
  name                = "WebLoadBalancer"
  location            = azurerm_resource_group.web_stack.location
  resource_group_name = azurerm_resource_group.web_stack.name
  sku                 = "Standard"
}

# Frontend IP
resource "azurerm_lb_frontend_ip_configuration" "web_lb_frontend" {
  name                 = "WebLBFrontend"
  loadbalancer_id      = azurerm_lb.web_lb.id
  public_ip_address_id = azurerm_public_ip.webstack_public_ip.id
}

# Backend Pool
resource "azurerm_lb_backend_address_pool" "web_lb_backend" {
  name                = "WebLBBackendPool"
  loadbalancer_id     = azurerm_lb.web_lb.id
}

# Health Probe
resource "azurerm_lb_probe" "web_lb_probe" {
  name                = "WebLBHealthProbe"
  loadbalancer_id     = azurerm_lb.web_lb.id
  protocol            = "Http"
  request_path        = "/"
  port                = 80
  interval_in_seconds = 15
  number_of_probes    = 2
}

# Load Balancer Rule
resource "azurerm_lb_rule" "web_lb_rule" {
  name                           = "WebLBRule"
  loadbalancer_id                = azurerm_lb.web_lb.id
  frontend_ip_configuration_name = azurerm_lb_frontend_ip_configuration.web_lb_frontend.name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.web_lb_backend.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  probe_id                       = azurerm_lb_probe.web_lb_probe.id
}

resource "azurerm_network_interface_backend_address_pool_association" "web_lb_backend_association" {
  count = 2
  network_interface_id    = azurerm_network_interface.web_tier_nic[count.index].id
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_lb_backend.id
}

  ## Future Enhancement - allow for multiple NICs to be added.
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id
  ]

# Application Gateway
resource "azurerm_application_gateway" "web_app_gateway" {
  name                = "WebAppGateway"
  location            = azurerm_resource_group.web_stack.location
  resource_group_name = azurerm_resource_group.web_stack.name
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }
  gateway_ip_configuration {
    name      = "AppGatewayIPConfig"
    subnet_id = azurerm_subnet.web_tier.id
  }
  frontend_ip_configuration {
    name                 = "AppGatewayFrontend"
    public_ip_address_id = azurerm_public_ip.webstack_public_ip.id
  }
  frontend_port {
    name = "AppGatewayFrontendPort"
    port = 80
  }
  backend_address_pool {
    name = "AppGatewayBackendPool"
  }
  http_listener {
    name                           = "AppGatewayHTTPListener"
    frontend_ip_configuration_name = "AppGatewayFrontend"
    frontend_port_name             = "AppGatewayFrontendPort"
    protocol                       = "Http"
  }
  request_routing_rule {
    name                       = "AppGatewayRoutingRule"
    rule_type                  = "Basic"
    http_listener_name         = "AppGatewayHTTPListener"
    backend_address_pool_name  = "AppGatewayBackendPool"
    backend_http_settings_name = "AppGatewayHTTPSettings"
  }
  backend_http_settings {
    name                  = "AppGatewayHTTPSettings"
    protocol              = "Http"
    port                  = 80
    request_timeout       = 20
    cookie_based_affinity = "Disabled"
  }
  tags = {
    Environment = "Production"
  }
}

# Azure Backup for VMs
resource "azurerm_backup_policy_vm" "web_vm_backup_policy" {
  name                = "WebVMBackupPolicy"
  resource_group_name = azurerm_resource_group.web_stack.name
  recovery_vault_name = azurerm_backup_vault.backup_vault.name

  backup {
    frequency         = "Daily"
    time              = "23:00"
    time_zone         = "UTC"
    retention_daily   = 7
    retention_weekly  = 4
    retention_monthly = 12
  }
}

resource "azurerm_backup_protected_vm" "web_vms" {
  for_each            = azurerm_windows_virtual_machine.web_tier
  resource_group_name = azurerm_resource_group.web_stack.name
  recovery_vault_name = azurerm_backup_vault.backup_vault.name
  source_vm_id        = each.value.id
  backup_policy_id    = azurerm_backup_policy_vm.web_vm_backup_policy.id
}

# Recovery Vault
resource "azurerm_backup_vault" "backup_vault" {
  name                = "WebInfraBackupVault"
  location            = azurerm_resource_group.web_stack.location
  resource_group_name = azurerm_resource_group.web_stack.name

  soft_delete_enabled  = true
  storage_type         = "LocallyRedundant"
}

