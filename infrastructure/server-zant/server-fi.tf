# Opt in after building the image. Fi uses its default address, 10.100.0.30.
resource "incus_image" "server_fi" {
  count = var.enable_server_fi ? 1 : 0

  source_file = {
    data_path     = "${abspath(var.server_fi_image_directory)}/disk.qcow2"
    metadata_path = "${abspath(var.server_fi_image_directory)}/metadata.tar.xz"
  }

  alias {
    name = "server-fi-nixos"
  }
}

resource "incus_profile" "server_fi_vm" {
  count = var.enable_server_fi ? 1 : 0

  name        = "server-fi-vm"
  description = "SSH-first AI agent VM policy for server-fi"

  config = {
    "boot.autostart"      = "true"
    "limits.cpu"          = tostring(var.server_fi_cpu_count)
    "limits.memory"       = var.server_fi_memory
    "security.secureboot" = "false"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "incus_instance" "server_fi" {
  count = var.enable_server_fi ? 1 : 0

  name     = "server-fi"
  type     = "virtual-machine"
  image    = incus_image.server_fi[0].fingerprint
  profiles = [incus_profile.default.name, incus_profile.server_fi_vm[0].name]
  running  = true

  device {
    name = "eth0"
    type = "nic"

    properties = {
      name           = "eth0"
      network        = incus_network.incusbr0.name
      "ipv4.address" = var.server_fi_ipv4_address
    }
  }

  device {
    name = "root"
    type = "disk"

    properties = {
      path = "/"
      pool = local.truenas_pool_name
      size = "256GiB"
    }
  }

  depends_on = [incus_storage_pool.truenas]

  lifecycle {
    prevent_destroy = true
    # OS updates happen inside the guest, not by replacing its stateful disk.
    ignore_changes = [image]

    precondition {
      condition     = var.enable_truenas_pool
      error_message = "server-fi requires the validated TrueNAS storage pool."
    }

    precondition {
      condition     = var.server_fi_ipv4_address != var.server_gohdan_ipv4_address
      error_message = "server-fi must not use server-gohdan's address."
    }
  }
}
