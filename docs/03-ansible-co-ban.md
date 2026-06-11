# 03 — Ansible cơ bản: cấu hình & cài dịch vụ

> VM đã được Terraform tạo (chạy + có IP). Giờ Ansible vào trong OS để cấu hình.

## 1. Dynamic inventory — Ansible tự tìm VM

Ta **không** viết danh sách IP bằng tay. File `ansible/inventory/proxmox.yml` gọi API Proxmox lấy danh sách VM đang chạy, rồi **gom nhóm theo tags**.

Token đọc API truyền qua biến môi trường:

```bash
cd ansible
export PROXMOX_TOKEN_SECRET="<secret-của-ansible-token>"

# Xem Ansible "nhìn thấy" gì:
ansible-inventory -i inventory/proxmox.yml --graph
```

Kết quả mong đợi (nhóm sinh ra từ tags):

```
@all:
  |--@k8s_masters:
  |  |--k8s-master-01
  |--@k8s_workers:
  |  |--k8s-worker-01
  |--@monitoring:
  |  |--monitoring-01
```

> Nhóm `k8s_masters`, `k8s_workers`, `monitoring`… đến từ phần `groups:` trong `inventory/proxmox.yml`, dựa trên tag bạn đặt ở Terraform. Đây là lý do **tag rất quan trọng**.

Nếu trả về rỗng → xem [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) mục 5.

## 2. Hai playbook

| Playbook | Chạy khi nào | Làm gì |
|---|---|---|
| `provision.yml` | Ngay sau `terraform apply` | OS chung **mọi** VM: hostname, timezone, package, hardening, prereq k8s (modules + sysctl + tắt swap), firewall |
| `configure.yml` | Sau provision | App theo nhóm: **k3s** cho `k8s_*`, **Prometheus+Grafana** cho `monitoring`, **node_exporter** mọi nơi |

```bash
# 1) Chuẩn bị OS
ansible-playbook playbooks/provision.yml

# 2) Cài ứng dụng
ansible-playbook playbooks/configure.yml
```

> `ansible.cfg` đã trỏ sẵn inventory, user `ubuntu`, key `~/.ssh/id_ed25519`, và vault password file `~/.vault_pass`. Chạy lệnh **từ trong thư mục `ansible/`**.

## 3. Vì sao thứ tự master → worker quan trọng

`configure.yml` cài k3s theo 2 play:

1. **Masters trước**: cài k3s server, sinh **node-token**, lưu kubeconfig về máy bạn (`ansible/kubeconfig.yaml`).
2. **Workers sau**: đọc token + IP master (qua facts) rồi `join`.

Nếu worker chạy trước master sẽ không có token để join — nên 2 play **phải tách** và đúng thứ tự (repo đã làm sẵn).

Sau khi xong, dùng cluster từ máy bạn:

```bash
export KUBECONFIG=$PWD/kubeconfig.yaml
kubectl get nodes        # thấy master + workers Ready
```

## 4. Chạy có chọn lọc (rất hay dùng)

```bash
# Chỉ 1 host
ansible-playbook playbooks/provision.yml --limit k8s-worker-01

# Chỉ 1 nhóm
ansible-playbook playbooks/configure.yml --limit monitoring

# Chỉ các task gắn tag 'monitoring'
ansible-playbook playbooks/configure.yml --tags monitoring

# Thử trước, không đổi gì (dry-run)
ansible-playbook playbooks/provision.yml --check --diff

# Ping tất cả
ansible all -m ping
```

## 5. Firewall (UFW) & Kubernetes — điều dễ vấp

`base` role bật UFW chặn incoming, nhưng **cho phép toàn bộ traffic từ `trusted_network`** (khai trong `group_vars/all.yml`). Đây là điều bắt buộc để k3s hoạt động: pod ở khác node nói chuyện qua **flannel VXLAN (UDP 8472)**.

- ĐỔI `trusted_network` cho khớp subnet của bạn.
- Không muốn dùng firewall? Đặt `enable_ufw: false` trong `all.yml`.

## 6. Monitoring

Play `monitoring` cài Docker + chạy Prometheus & Grafana bằng docker compose tại `/opt/monitoring`:

- Grafana: `http://<IP-monitoring>:3000` (user `admin`, mật khẩu = `vault_grafana_admin_password` trong vault).
- Prometheus: `http://<IP-monitoring>:9090` — đã tự scrape `node_exporter` (cổng 9100) của **mọi** VM.

> Muốn giám sát *bên trong* Kubernetes (pod/deployment) → xem [05-nang-cao.md](05-nang-cao.md) mục "Giám sát Kubernetes".

## 7. Vault (bí mật)

Các giá trị nhạy cảm (token, mật khẩu Grafana) nằm trong `group_vars/vault.yml` đã mã hóa:

```bash
ansible-vault view group_vars/vault.yml      # xem
ansible-vault edit group_vars/vault.yml      # sửa
```

➡️ Muốn storage dùng chung & chịu lỗi cho VM? Tiếp theo: [04-ceph-pveceph.md](04-ceph-pveceph.md).
