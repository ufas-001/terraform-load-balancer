terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }
  backend "s3" {
    key    = "aws/terraformone/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# Provision the ec2 instance for NGINX
resource "aws_instance" "nginx-server" {
  ami                    = "ami-064087b8d355e9051"
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.general-sg.id]
  user_data              = <<-EOF
                #!/bin/bash
                sudo apt-get update
                sudo apt-get install apache2 -y
                sudo systemctl start nginx
                sudo systemctl enable nginx
                EOF

  tags = {
    "Name" = "nginx-server"
  }
}

# Provision the ec2 instance for APACHE
resource "aws_instance" "apache-server" {
  ami                    = "ami-064087b8d355e9051"
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.general-sg.id]
  user_data              = <<-EOF
                #!/bin/bash
                sudo apt-get update
                sudo apt-get install nginx -y
                sudo systemctl start apache2
                sudo systemctl enable apache2
                EOF

  tags = {
    "Name" = "apache-server"
  }
}

# Provision a load balancer
resource "aws_lb" "terraform-one" {
  name               = "terraform-one"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.general-sg.id]
  subnets            = ["subnet-0b7093fd341ea9132", "subnet-022b34ff2256dc4d0", "subnet-04753fdd10dd8e1b3"]
}

# Provision a target group
resource "aws_lb_target_group" "terraform-one" {
  name        = "terraform-one-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = "vpc-0958e011f386713ce"

  health_check {
    path = "/"
  }
}

# Provision a listener 
resource "aws_lb_listener" "terraform-one" {
  load_balancer_arn = aws_lb.terraform-one.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform-one.arn
  }
}

# Provision the target group attachments
resource "aws_lb_target_group_attachment" "nginx-server" {
  target_group_arn = aws_lb_target_group.terraform-one.arn
  target_id        = aws_instance.nginx-server.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "apache-server" {
  target_group_arn = aws_lb_target_group.terraform-one.arn
  target_id        = aws_instance.apache-server.id
  port             = 80
}

# Provision the security group
resource "aws_security_group" "general-sg" {
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]

  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "allow ssh"
    from_port        = 22
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 22
    },
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "allow http"
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 80
  }]
}