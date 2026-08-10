terraform {
  required_version = ">= 1.10.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~> 1.1"
    }
  }
}

# With no explicit remote, the provider uses the local Incus Unix socket.
provider "incus" {}
