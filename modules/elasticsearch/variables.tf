variable "name" {
  type        = string
  description = "Application name"
}

variable "kibana-readonly" {
  type        = bool
  description = "Should Kibana access default to read-only?"
  default     = true
}
