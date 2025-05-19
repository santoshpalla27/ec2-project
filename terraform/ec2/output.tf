output "ec2_instance_id" {
  value = aws_instance.aws_instance.id
}

output "ec2_instance_public_ip" {
  value = aws_instance.aws_instance.public_ip
}

output "ec2_instance_private_ip" {
  value = aws_instance.aws_instance.private_ip
}

output "ec2_instance_public_dns" {
  value = aws_instance.aws_instance.public_dns
}
