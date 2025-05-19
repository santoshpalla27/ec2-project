resource "aws_instance" "aws_instance" {
    ami = var.ami
    instance_type = var.instance_type
    key_name = var.key_name
    vpc_security_group_ids = [var.security_group_id]
    subnet_id = var.subnet_id
    tags = {
        Name = "${var.name} Instance"
    }
    user_data = var.user_data
    iam_instance_profile = var.instance_profile_name
}