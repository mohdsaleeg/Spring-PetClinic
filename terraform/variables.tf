variable "subscription_id" {
  description = "Azure subscription ID (az account show --query id -o tsv)"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form, for example 203.0.113.7/32. Only this address can reach the VM."
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "centralindia"
}

variable "prefix" {
  description = "Name prefix for all resources"
  type        = string
  default     = "petclinic"
}

variable "vm_size" {
  description = "VM size. B2ms = 2 vCPU, 8 GB RAM, enough for Jenkins and SonarQube together"
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Public key installed on the VM (path on the machine running Terraform)"
  type        = string
  default     = "~/.ssh/azure_devops.pub"
}

variable "ansible_private_key_path" {
  description = "Private key path as seen from where Ansible runs (WSL)"
  type        = string
  default     = "~/.ssh/azure_devops"
}

variable "auto_shutdown_time" {
  description = "Daily shutdown time in HHmm, India Standard Time"
  type        = string
  default     = "2200"
}
