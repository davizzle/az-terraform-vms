output "resource_group_name" {
  value = azurerm_resource_group.web_stack.name
}

output "public_ip" {
  value = azurerm_public_ip.webstack_public_ip.ip_address
}

output "priv_ip_address" {
  description = "The IP Address assigned to the main VM NIC"
  value       = azurerm_network_interface.web_tier_nic[0].private_ip_address
}

output "nic_id" {
  description = "The Network Interface ID of Web Tier VM"
  value       = azurerm_network_interface.web_tier_nic[0].id
}

output "vm_id" {
  value = azurerm_windows_virtual_machine.web_tier[0].id
}
