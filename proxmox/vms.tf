resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.vms

  name      = each.key
  node_name = each.value.node
  vm_id     = each.value.vm_id

  stop_on_destroy = true

  agent {
    enabled = true # qemu-guest-agent는 vendor-data에서 설치
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.ubuntu_2404[each.value.node].id
    interface    = "scsi0"
    size         = each.value.disk
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = true
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id        = "local-lvm"
    vendor_data_file_id = proxmox_virtual_environment_file.vendor_data[each.value.node].id

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.gateway
      }
    }

    user_account {
      username = var.vm_username
      password = var.vm_password
    }
  }
}
