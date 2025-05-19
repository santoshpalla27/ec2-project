sg_name = "santosh-sg"
sg_description = "Security group for Santoshs EC2 instance"
vpc_id = "vpc-07690952b6b0b5a79" # Replace with your actual VPC ID
ingress = [ {
    description = "Allow SSH access from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
} ]

egress = [ {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
} ]

tags = {
    Name        = "santosh-sg"
    Environment = "dev"
}