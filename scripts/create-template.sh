#!/usr/bin/env bash
# =============================================
#  scripts/create-template.sh
#  Chạy TRÊN PVE NODE (SSH vào hoặc dùng Shell trong web UI)
#  Tạo Ubuntu 24.04 cloud-init template ID 9000
# =============================================
set -euo pipefail

TEMPLATE_ID=9000
TEMPLATE_NAME="ubuntu-2404-template"
STORAGE="local-lvm"    # Đổi nếu dùng storage khác
BRIDGE="vmbr0"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMAGE_FILE="noble-server-cloudimg-amd64.img"

echo "==> Downloading Ubuntu 24.04 cloud image..."
wget -q --show-progress -O /tmp/${IMAGE_FILE} ${IMAGE_URL}

echo "==> Removing old template if exists..."
qm destroy ${TEMPLATE_ID} --purge 2>/dev/null || true

echo "==> Creating VM ${TEMPLATE_ID}..."
qm create ${TEMPLATE_ID} \
  --name ${TEMPLATE_NAME} \
  --memory 2048 \
  --cores 2 \
  --cpu x86-64-v2-AES \
  --net0 virtio,bridge=${BRIDGE} \
  --scsihw virtio-scsi-single \
  --ostype l26

echo "==> Importing disk..."
qm importdisk ${TEMPLATE_ID} /tmp/${IMAGE_FILE} ${STORAGE}

echo "==> Configuring VM..."
qm set ${TEMPLATE_ID} \
  --scsi0 ${STORAGE}:vm-${TEMPLATE_ID}-disk-0,iothread=1,ssd=1,discard=on \
  --ide2 ${STORAGE}:cloudinit \
  --boot order=scsi0 \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=1,fstrim_cloned_disks=1 \
  --ipconfig0 ip=dhcp \
  --ciuser ubuntu

echo "==> Converting to template..."
qm template ${TEMPLATE_ID}

echo "==> Cleanup..."
rm -f /tmp/${IMAGE_FILE}

echo ""
echo "✓ Template ${TEMPLATE_ID} (${TEMPLATE_NAME}) created on storage: ${STORAGE}"
echo "  Now run: terraform apply"
