variable "name" {
  type        = string
  description = "Flowlogs name"
}

variable "vpc-ids" {
  type        = list(string)
  description = "List of VPC IDs to have flowlogs enabled"
}
