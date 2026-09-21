variable "enable_truenas_pool" {
  description = "Manage the validated Incus TrueNAS storage pool; set false only as a temporary safety gate on a fresh replacement host."
  type        = bool
  default     = true
}

variable "default_root_disk_size" {
  description = "Default Incus root disk size once the TrueNAS pool is enabled."
  type        = string
  default     = "256GiB"
}

variable "enable_server_gohdan" {
  description = "Manage the server-gohdan identity VM and its bootstrap image."
  type        = bool
  default     = true
}

variable "server_gohdan_image_directory" {
  description = "Directory containing disk.qcow2 and metadata.tar.xz from the server-gohdan-incus-image flake output."
  type        = string
  default     = "../../result"
}

variable "server_gohdan_ipv4_address" {
  description = "Static IPv4 address for server-gohdan on incusbr0."
  type        = string
  default     = "10.100.0.10"
}

variable "server_gohdan_cpu_count" {
  description = "Virtual CPU count for server-gohdan."
  type        = number
  default     = 4
}

variable "server_gohdan_memory" {
  description = "Memory limit for server-gohdan."
  type        = string
  default     = "8GiB"
}
