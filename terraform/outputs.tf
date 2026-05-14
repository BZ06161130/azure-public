output "public_ip_address" {
  description = "Static public IP assigned to the proxy VM."
  value       = azurerm_public_ip.this.ip_address
}

output "ssh_command" {
  description = "SSH command for the VM."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.this.ip_address}"
}

output "panel_url" {
  description = "3X-UI panel URL. Restrict this port to trusted admin IPs."
  value       = "http://${azurerm_public_ip.this.ip_address}:${var.panel_port}/"
}

output "raw_subscription_url_template" {
  description = "Raw subscription URL template. Replace <SUB_ID> with the 3X-UI client subId."
  value       = "http://${azurerm_public_ip.this.ip_address}:${var.subscription_port}/sub/<SUB_ID>"
}

output "clash_subscription_url_template" {
  description = "Clash/Mihomo subscription URL template. Replace <SUB_ID> with the 3X-UI client subId."
  value       = "http://${azurerm_public_ip.this.ip_address}:${var.subscription_port}/clash/<SUB_ID>"
}

output "hysteria2_certificate_file" {
  description = "Certificate path to paste into the 3X-UI Hysteria2 inbound."
  value       = "/root/cert/server.crt"
}

output "hysteria2_private_key_file" {
  description = "Private key path to paste into the 3X-UI Hysteria2 inbound."
  value       = "/root/cert/server.key"
}

output "opened_ports" {
  description = "Ports opened by the Network Security Group."
  value = {
    vless_reality_tcp = var.vless_port
    hysteria2_udp     = var.hysteria2_port
    panel_tcp         = var.panel_port
    subscription_tcp  = var.subscription_port
    ssh_tcp           = 22
  }
}
