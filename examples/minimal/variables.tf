variable "mimir" {
  description = "Mimir configuration passed through to the module. Overrides the defaults set in main.tf."
  type        = any
  default     = {}
}
