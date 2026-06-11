# Troubleshooting — Lỗi hay gặp

## 1. Terraform Init — provider download fail

```
Error: Failed to install provider bpg/proxmox
```
**Fix:**
```bash
# Kiểm tra kết nối internet
curl -I https://registry.terraform.io

# Nếu dùng proxy
export HTTPS_PROXY=http://proxy:3128
terraform init -upgrade
```

---

## 2. Terraform Apply — 401 Unauthorized

```
Error: 401 Unauthorized
```
**Fix:**
- Kiểm tra lại token format: `terraform@pve!tf-token=xxxxxxxx`
- Vào Proxmox UI → Datacenter → API Tokens → verify token còn active
- Kiểm tra user có đúng role:
```bash
pveum user list
pveum acl list
```

---

## 3. Terraform Apply — 500 clone failed

```
Error: POST https://...clone: 500 (internal server error)
```
**Fix:**
```bash
# Kiểm tra template tồn tại
qm list | grep 9000

# Kiểm tra storage đủ dung lượng
pvesm status

# Kiểm tra lock (do VM đang bị lock)
qm unlock 9000
```

---

## 4. VM tạo xong nhưng không lấy được IP

**Nguyên nhân:** cloud-init chưa chạy xong, hoặc qemu-guest-agent chưa báo IP

**Fix:**
```bash
# SSH vào PVE node, xem console VM
qm terminal 101

# Hoặc check cloud-init log bên trong VM
sudo cat /var/log/cloud-init-output.log

# Force re-run cloud-init
sudo cloud-init clean && sudo cloud-init init
```

---

## 5. Ansible — dynamic inventory trả về rỗng

```bash
ansible-inventory -i inventory/proxmox.yml --list
# Trả về {}
```
**Fix:**
```bash
# 1. Kiểm tra biến môi trường
echo $PROXMOX_TOKEN_SECRET

# 2. Test kết nối API thủ công
curl -k "https://192.168.1.10:8006/api2/json/nodes" \
  -H "Authorization: PVEAPIToken=ansible@pve!ansible-token=YOUR_SECRET"

# 3. Kiểm tra VM có tag không (inventory dùng tags để group)
qm config 101 | grep tags
```

---

## 6. Ansible — SSH connection refused

```
UNREACHABLE! => {"msg": "Failed to connect to the host via ssh"}
```
**Fix:**
```bash
# Kiểm tra VM đang chạy và có IP
qm guest cmd 101 network-get-interfaces

# Thử SSH thủ công
ssh -i ~/.ssh/id_ed25519 ubuntu@192.168.1.101 -v

# Kiểm tra cloud-init đã inject key chưa
qm guest exec 101 -- cat /home/ubuntu/.ssh/authorized_keys
```

---

## 7. Ceph — OSD down sau reboot

```bash
# Xem status
ceph -s
ceph osd tree

# Restart OSD service
systemctl restart ceph-osd@*

# Nếu OSD bị out
ceph osd in osd.0
ceph osd reweight osd.0 1.0
```

---

## 8. terraform destroy không xóa được VM

```
Error: timeout waiting for VM to stop
```
**Fix:**
```bash
# Force stop VM từ PVE
qm stop 101 --skiplock 1

# Rồi chạy lại
terraform destroy -target='module.vms["k8s-master-01"]'
```

---

## 9. Useful commands

```bash
# Xem terraform state
terraform state list
terraform state show 'module.vms["k8s-master-01"].proxmox_virtual_environment_vm.this'

# Refresh state (sync lại với Proxmox thực tế)
terraform refresh

# Chạy ansible cho 1 host cụ thể
ansible-playbook playbooks/provision.yml --limit k8s-master-01

# Chạy với tag cụ thể
ansible-playbook playbooks/configure.yml --tags k8s

# Xem inventory thực tế
ansible-inventory -i inventory/proxmox.yml --graph

# Ping tất cả hosts
ansible all -m ping
```
