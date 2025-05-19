variable "region" {
  description = "The provider to use for the module. Default is 'aws'."
  type        = string  
}

variable "cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the VPC."
  type        = map(string)
  default     = {}           
}

variable "vpc_name" {
  description = "The name of the VPC."
  type        = string
  default = ""
}

variable "public_subnets" {
  description = "A list of CIDR blocks for the public subnets."
  type        = list(string)
}


variable "private_subnets" {
  description = "A list of CIDR blocks for the private subnets."
  type        = list(string)
}

variable "create_nat_gateway" {
  description = "Whether to create a NAT gateway."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Whether to create a single NAT gateway or multiple."
  type = bool
  default = true
}

variable "private_subnets_tags" {
  description = "A map of tags to assign to the private subnets."
  type        = map(string)
  default     = {}
}

variable "public_subnets_tags" {
  description = "A map of tags to assign to the public subnets."
  type        = map(string)
  default     = {}
}