variable "ami" {
    description = "The AMI to use for the instance"
    type        = string
}

variable "instance_type" {
    description = "The type of instance to launch"
    type        = string
}


variable "key_name" {
    description = "The key pair to use for the instance"
    type        = string
}


variable "security_group_id" {
    description = "The security group to use for the instance"
    type        = string
}

variable "subnet_id" {
    description = "The subnet to use for the instance"
    type        = string
}

variable "name" {
    description = "The name of the instance"
    type        = string
}

variable "user_data" {
    description = "The user data to provide when launching the instance"
    type        = string
}

variable "instance_profile_name" {
    description = "The name of the instance profile to use for the instance"
    type        = string 
    default = ""
}