# Azure 3X-UI Terraform

This directory replaces the original monolithic `Terraform Script.txt` draft with a reusable Terraform layout.

For an end-to-end VM plus 3X-UI recovery flow, see `../AGENT_QUICKSTART.md`.

## What It Builds

- Resource group, VNet, subnet, Standard static public IP, NIC, NSG, and Ubuntu VM.
- NSG rules for:
  - TCP `443` for VLESS + REALITY.
  - UDP `4443` for Hysteria2.
  - TCP `2096` for subscriptions.
  - TCP `2053` for the 3X-UI panel, restricted by `allowed_admin_cidrs`.
  - TCP `22` for SSH, restricted by `allowed_admin_cidrs`.
- Linux network tuning for BBR and UDP buffers.
- A 10-year self-signed Hysteria2 certificate:
  - `/root/cert/server.crt`
  - `/root/cert/server.key`
- Optional 3X-UI bootstrap through cloud-init.

## Why The Draft Was Changed

The first script was useful for a single VM, but it had portability and recovery problems:

- It was a `.txt` file instead of Terraform-native `.tf` files.
- It hardcoded names, region, and Spot settings.
- The NSG was not associated with the NIC.
- UDP `4443` and TCP `2096` were missing from the allowed proxy ports.
- SSH and panel access were open to the internet.
- Spot VM was enabled by default, which is not ideal for a stable proxy.
- It installed unrelated workspace tooling by default.
- It did not create the Hysteria2 certificate paths we now know are required.

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
subscription_id = "YOUR-AZURE-SUBSCRIPTION-ID"
allowed_admin_cidrs = ["YOUR.PUBLIC.IP.ADDRESS/32"]
location = "westus2"
```

Then run:

```bash
terraform init
terraform plan
terraform apply
```

## After Apply

Terraform provisions the Azure VM and bootstrap basics. 3X-UI inbound definitions still need to be created or restored from backup in the panel.

For Hysteria2, paste these certificate paths into the inbound:

```text
/root/cert/server.crt
/root/cert/server.key
```

Recommended Hysteria2 settings:

```text
Port: 4443 UDP
SNI: bing.com
ALPN: h3
Allow insecure / skip cert verify on clients using the self-signed certificate
```

Recommended VLESS + REALITY settings:

```text
Port: 443 TCP
SNI/Dest: www.microsoft.com:443
Fingerprint: chrome
Flow: xtls-rprx-vision
```

## Notes

- Keep `use_spot = false` for production-like proxy stability. Enable Spot only when eviction is acceptable.
- Keep `allowed_admin_cidrs` narrow. Avoid exposing SSH and the panel to `*` unless this is a short-lived test VM.
- The generated static public IP is the value to use in client links and subscriptions.
- If reusing an existing 3X-UI database, restore `/etc/x-ui/x-ui.db` and any certificate files before restarting `x-ui`.
- Terraform does not store VPN passwords, UUIDs, REALITY keys, or subscription IDs. Those remain panel-level secrets.
