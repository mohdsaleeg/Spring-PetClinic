output "public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/azure_devops ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "jenkins_url" {
  value = "http://${azurerm_public_ip.pip.ip_address}:8080"
}

output "sonarqube_url" {
  value = "http://${azurerm_public_ip.pip.ip_address}:9000"
}
