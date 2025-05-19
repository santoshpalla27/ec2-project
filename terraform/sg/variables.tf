variable "sg_name" {
  description = "The name of the security group."
  type        = string
  default     = "security_group"
}

variable "sg_description" {
  description = "The description of the security group."
  type        = string
  default     = "Security group for the VPC."
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "ingress" {
  description = "values for ingress rules."
  type        = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
    default     = []  
}

variable "egress" {
  description = "values for egress rules."
  type        = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default     = []
  
}

variable "tags" {
  description = "A map of tags to assign to the security group."
  type        = map(string)
  default     = {}
}