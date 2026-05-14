# Future Agent Quickstart: Azure VM + 3X-UI Proxy Recovery

This is the operational path to recreate the Azure VM and get both proxy inbounds working with minimal rediscovery.

## Goal

Provision a new Azure Ubuntu VM, bootstrap the host, install or restore 3X-UI, then verify:

- VLESS + REALITY on TCP `443`.
- Hysteria2 on UDP `4443`.
- 3X-UI panel on TCP `2053`.
- Subscription service on TCP `2096`.

## Repository Map

- `terraform/`: maintained Terraform implementation.
- `terraform/README.md`: Terraform usage and design notes.
- `terraform/terraform.tfvars.example`: copy this to `terraform.tfvars` and edit.
- `Terraform Script.txt`: legacy pointer only; do not apply it.
- `index.html`: private handoff with live connection details.

## Inputs Needed

- Azure subscription ID.
- Target Azure region near users, such as `westus2`.
- Admin public IP/CIDR for SSH and panel access.
- SSH public key path, usually `~/.ssh/id_rsa.pub`.
- Optional backup of `/etc/x-ui/x-ui.db` if exact users, UUIDs, passwords, REALITY keys, and subscription IDs must survive rebuilds.

## 1. Provision The VM

```bash
cd /home/azureuser/public_html/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
subscription_id = "YOUR-SUBSCRIPTION-ID"
location = "westus2"
allowed_admin_cidrs = ["YOUR.PUBLIC.IP/32"]
ssh_public_key_path = "~/.ssh/id_rsa.pub"
use_spot = false
install_3x_ui = true
```

Apply:

```bash
terraform init
terraform plan
terraform apply
```

Keep the `public_ip_address` output. It becomes the server address in client links and subscriptions.

## 2. What Cloud-Init Handles

The VM first boot does the baseline host setup:

- Installs required tools.
- Enables BBR with `fq`.
- Sets UDP/socket buffers to `16777216`.
- Creates Hysteria2 certificate files:
  - `/root/cert/server.crt`
  - `/root/cert/server.key`
- Installs 3X-UI if `install_3x_ui = true`.

Check first boot:

```bash
sudo cloud-init status --long
sudo systemctl status x-ui --no-pager
sysctl net.ipv4.tcp_congestion_control net.core.rmem_max net.core.wmem_max
```

## 3. Restore Or Create 3X-UI Inbounds

Preferred if preserving existing identities:

```bash
sudo systemctl stop x-ui
sudo cp x-ui.db /etc/x-ui/x-ui.db
sudo chown root:root /etc/x-ui/x-ui.db
sudo chmod 644 /etc/x-ui/x-ui.db
sudo systemctl start x-ui
```

If creating fresh inbounds manually:

### VLESS + REALITY

```text
Protocol: VLESS
Port: 443 TCP
Security: REALITY
Dest/SNI: www.microsoft.com:443
Fingerprint: chrome
Flow: xtls-rprx-vision
```

### Hysteria2

```text
Protocol: Hysteria2
Port: 4443 UDP
SNI: bing.com
ALPN: h3
Certificate file: /root/cert/server.crt
Private key file: /root/cert/server.key
Client setting: insecure / skip certificate verification
```

Use `bing.com` with the generated self-signed certificate unless a real certificate/domain is added.

## 4. Azure Firewall / NSG Checklist

Terraform opens these ports:

```text
TCP 22    SSH, admin CIDRs only
TCP 2053  3X-UI panel, admin CIDRs only
TCP 443   VLESS + REALITY
UDP 4443  Hysteria2
TCP 2096  subscriptions
```

If Hysteria2 fails while VLESS works, check UDP `4443` first.

## 5. Verification Commands

```bash
curl -4 ifconfig.me
sudo /usr/local/x-ui/bin/xray-linux-amd64 -test -config /usr/local/x-ui/bin/config.json
sudo ss -ltnup | grep -E ':(443|4443|2053|2096)\b'
sudo journalctl -u x-ui --no-pager -n 80
sudo /usr/local/x-ui/bin/xray-linux-amd64 api statsquery --server=127.0.0.1:62789 -pattern 'inbound>>>'
```

Expected listeners:

```text
TCP 443   xray
UDP 4443  xray
TCP 2053  x-ui
TCP 2096  x-ui
```

## 6. Subscription URL Formats

Replace `<PUBLIC_IP>` and `<SUB_ID>`:

```text
Raw:   http://<PUBLIC_IP>:2096/sub/<SUB_ID>
Clash: http://<PUBLIC_IP>:2096/clash/<SUB_ID>
```

The current 3X-UI version uses `/clash/<SUB_ID>`, not older `/clash-.../<SUB_ID>` paths.

## 7. Agent Notes

- Do not rely on the panel's Hysteria2 "online" indicator alone. Verify with Xray stats and a real client request.
- If Xray logs mention missing certs, point Hysteria2 to `/root/cert/server.crt` and `/root/cert/server.key`.
- If Hysteria2 receives UDP but does not authenticate, compare SNI, ALPN, password, and `insecure` client setting.
- Keep Terraform state and `terraform.tfvars` out of git.
- Keep the public Pages repo redacted. Live VPN links and secrets belong only in the private repo.
