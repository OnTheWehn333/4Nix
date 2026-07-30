variable "enable_truenas_pool" {
  description = "Create the Incus TrueNAS storage pool after API and iSCSI validation succeeds."
  type        = bool
  default     = false
}

variable "default_root_disk_size" {
  description = "Default Incus root disk size once the TrueNAS pool is enabled."
  type        = string
  default     = "256GiB"
}
