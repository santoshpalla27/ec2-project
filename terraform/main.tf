provider "aws" {
  region = "us-east-1"
}
# VPC
module "vpc" {
  source = "./vpc"
  vpc_name = "4-tier-project"
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "4-tier-project"
    Environment = "dev"
    Project = "4-tier-project"
  }
  region = "us-east-1"
  public_subnets = [ "10.0.1.0/24" , "10.0.2.0/24","10.0.3.0/24" , "10.0.4.0/24" ]
  private_subnets = [ "10.0.5.0/24" , "10.0.6.0/24","10.0.7.0/24" , "10.0.8.0/24" ]
  create_nat_gateway = true
  single_nat_gateway = true
}
# Security Groups
# Security group for frontend EC2 instance
module "frontend-sg" {
  source = "./sg"
  sg_name = "frontend-sg"
  vpc_id = module.vpc.vpc_id
  sg_description = "Security group for frontend EC2 instance"
  ingress = [
    {
      description = "Allow HTTP access from anywhere"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Allow HTTPS access from anywhere"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Allow SSH access from anywhere"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  egress = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1" # All protocols
      cidr_blocks = ["0.0.0.0/0"]
  }
  ]
  tags = {
    name = "frontend-sg"
    environment = "dev"
    project = "4-tier-project"
  }
}
# Security group for backend EC2 instance
module "backend-sg" {
  source = "./sg"
  sg_name = "backend-sg"
  vpc_id = module.vpc.vpc_id
  sg_description = "Security group for backend EC2 instance"
  ingress = [
    {
      description = "Allow HTTP access from frontend security group"
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Allow SSH access from anywhere"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  egress = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1" # All protocols
      cidr_blocks = ["0.0.0.0/0"]
    }]
  tags = {
    name = "backend-sg"
    environment = "dev"
    project = "4-tier-project"
  }
}
# Security group for database
module "db_sg" {
  source = "./sg"
  sg_name = "db-sg"
  vpc_id = module.vpc.vpc_id
  sg_description = "Security group for database"
  ingress = [
    {
      description = "Allow MySQL access from backend security group"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  egress = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1" # All protocols
      cidr_blocks = ["0.0.0.0/0"]
    }]
  tags = {
    name = "rds-sg"
    environment = "dev"
    project = "4-tier-project"
  }
}
# Security group for cache EC2 instance
module "cache-sg" {
  source = "./sg"
  sg_name = "cache-sg"
  vpc_id = module.vpc.vpc_id
  sg_description = "Security group for cache EC2 instances"
  ingress = [
    {
      description = "Allow Redis access from backend security group"
      from_port   = 6379
      to_port     = 6382
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Allow SSH access from anywhere"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Allow HTTP access from frontend security group"
      from_port   = 16379
      to_port     = 16382
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  egress = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1" # All protocols
      cidr_blocks = ["0.0.0.0/0"]
    }]
  tags = {
    name = "cache-sg"
    environment = "dev"
    project = "4-tier-project"
  }
}
# IAM Role for EC2 to describe EC2 instances
resource "aws_iam_role" "ec2_describe_role" {
  name = "ec2-describe-instances-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "EC2-Describe-Instances-Role"
  }
}

# Policy allowing EC2 instances to describe other EC2 instances
resource "aws_iam_policy" "ec2_describe_policy" {
  name        = "ec2-describe-instances-policy"
  description = "Allow EC2 instances to describe other EC2 instances"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "ec2_describe_policy_attach" {
  role       = aws_iam_role.ec2_describe_role.name
  policy_arn = aws_iam_policy.ec2_describe_policy.arn
}

# Create the instance profile
resource "aws_iam_instance_profile" "ec2_describe_profile" {
  name = "ec2-describe-instances-profile"
  role = aws_iam_role.ec2_describe_role.name
}

# Output the instance profile name (to use when launching instances)
output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_describe_profile.name
}


# frontend load balancer
resource "aws_lb" "frontend" {
  name               = "frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.frontend-sg.sg_id]
  subnets            = module.vpc.public_subnet_ids
}

resource "aws_lb_target_group" "frontend" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "instance"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# frontend autoscaling group
module "frontend-asg"{
  source  = "terraform-aws-modules/autoscaling/aws"
  name = "frontend-asg"
  vpc_zone_identifier = module.vpc.public_subnet_ids

  key_name = "santosh"
  launch_template_name = "frontend-launch-template"
  launch_template_version = "$Latest"
  launch_template_description = "frontend Launch Template"
  image_id = "ami-08b5b3a93ed654d19"
  
  security_groups = [ module.frontend-sg.sg_id ]
  instance_type = "t2.micro"
  min_size = 2
  max_size = 4
  desired_capacity = 3
  health_check_type = "EC2"

  scaling_policies = {
    cpu_auto = {
      policy_type = "TargetTrackingScaling"
      target_tracking_configuration = {
        target_value = 60
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
      }
    }
  }


  
  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo yum install ansible git -y
              git clone https://github.com/santoshpalla27/4-tier-project.git
              cd 4-tier-project/ansible
              /usr/bin/ansible-playbook frontend.yaml
              EOF
              )
  iam_instance_profile_name = aws_iam_instance_profile.ec2_describe_profile.name
  tags = {
      key                 = "Name"
      value               = "frontend-asg-instance"
      propagate_at_launch = true
    }
  

}

# backend load balancer
resource "aws_lb" "backend" {
  name               = "backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.backend-sg.sg_id]
  subnets            = module.vpc.public_subnet_ids
}

resource "aws_lb_target_group" "backend" {
  name     = "back-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "instance"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# backend autoscaling group

module "backend-asg"{
  source  = "terraform-aws-modules/autoscaling/aws"
  name = "backend-asg"
  vpc_zone_identifier = module.vpc.private_subnet_ids
  key_name = "santosh"
  launch_template_name = "backend-launch-template"
  launch_template_version = "$Latest"
  launch_template_description = "Backend Launch Template"
  image_id = "ami-08b5b3a93ed654d19"
  instance_type = "t2.micro"
  min_size = 2
  max_size = 4
  desired_capacity = 3
  health_check_type = "EC2"
  security_groups = [ module.backend-sg.sg_id ]
  scaling_policies = {
  cpu_auto = {
    policy_type = "TargetTrackingScaling"
    target_tracking_configuration = {
      target_value = 60
      predefined_metric_specification = {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
    }
  }
}

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo yum install ansible git -y
              git clone https://github.com/santoshpalla27/4-tier-project.git
              cd 4-tier-project/ansible
              /usr/bin/ansible-playbook backend.yaml 
              EOF
  )

  
  iam_instance_profile_name = aws_iam_instance_profile.ec2_describe_profile.name
  tags ={
      key                 = "Name"
      value               = "backend-asg-instance"
      propagate_at_launch = true
    }

}

# asg to target group attachment
resource "aws_autoscaling_attachment" "backend_attachment" {
  autoscaling_group_name = module.backend-asg.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.backend.arn
}
resource "aws_autoscaling_attachment" "frontend_attachment" {
  autoscaling_group_name = module.frontend-asg.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.frontend.arn
}


# Cache EC2 instances
module "cache-ec2" {
  source = "./ec2"
  count = 4
  ami = "ami-08b5b3a93ed654d19"
  instance_type = "t2.micro"
  key_name = "santosh"
  security_group_id = module.cache-sg.sg_id
  subnet_id = module.vpc.private_subnet_ids[count.index % 2]
  name = "cache${count.index}"
  instance_profile_name = aws_iam_instance_profile.ec2_describe_profile.name
  user_data = <<-EOF
              #!/bin/bash
              sudo yum install ansible git -y
              git clone https://github.com/santoshpalla27/4-tier-project.git
              cd 4-tier-project/ansible
              /usr/bin/ansible-playbook redis.yaml
              EOF
}


# subnet group for database
resource "aws_db_subnet_group" "database_subnet_group" {
  name        = "database-subnet-group"
  description = "DB subnet group for database"
  subnet_ids  = module.vpc.private_subnet_ids
  
  tags = {
    Name = "database-subnet-group"
  }
}


resource "aws_db_instance" "database" {
  identifier = "database"
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  username = "admin"
  password = "admin123"
  multi_az = false
  publicly_accessible = false
  skip_final_snapshot = true
  vpc_security_group_ids = [module.db_sg.sg_id]
  db_subnet_group_name = aws_db_subnet_group.database_subnet_group.name
  tags = {
    Name = "database"
  }
}

