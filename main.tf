provider "aws" {
  region = "eu-central-1"
}

variable "default-port" {
  description = "The port of which the server is running"
  type = string
  default = "8080"
}

resource "aws_launch_template" "example" {
  name_prefix = "example_ec2_launch_template"
  image_id = "ami-09042b2f6d07d164a"
  instance_type = "t2.micro"
  key_name = "key-example"
  user_data = filebase64("${path.module}/example-script.sh")
  vpc_security_group_ids = [aws_security_group.instance.id]

  tags = {
    Name = "terraform-example"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example-auto-scaling-group" {
  max_size = 10
  min_size = 2
  availability_zones = data.aws_availability_zones.all.names
  load_balancers = [aws_elb.example.name]
  health_check_type = "ELB"
  launch_template {
    id = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "example-asg-scaling-group"
  }
}

data "aws_availability_zones" "all" {}

resource "aws_instance" "example" {
  ami                    = "ami-09042b2f6d07d164a"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name = "key-example"

  user_data = <<-EOF
                #!/bin/bash
                echo "Hello World!!!" > index.html
                nohup busybox httpd -f -p ${var.default-port} &
                EOF
  tags = {
    Name = "terraform-example-working"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = var.default-port
    to_port     = var.default-port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    protocol  = "tcp"
    to_port   = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "example" {
  name = "terraform-example-elb"
  availability_zones = data.aws_availability_zones.all.names
  security_groups = [aws_security_group.elb.id]

  listener {
    instance_port     = var.default-port
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    interval            = 30
    target              = "HTTP:${var.default-port}/"
    timeout             = 3
    unhealthy_threshold = 2
  }
}
#
resource "aws_security_group" "elb" {
  name = "terraform-example-elb"

  ingress {
    from_port = 80
    protocol  = "tcp"
    to_port   = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol  = -1
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "elb_dns_name" {
  value = aws_elb.example.dns_name
}

resource "aws_key_pair" "example" {
  key_name = "key-example"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8AQdvoQGtQf4Fyd0M8KCeCpt2tO6aqQfZ3o0do0oj7LZYiZHeZHqGCW9dJ+mMNwcM/35m29XhON1ADNWBU0TDJ6hnr7yppIrZcNatxougI28KukGtHmemh+xDtCxizROOmY6frdPUBYmWPR8Ly+BmX1O7Gfn2rmVPwJQnbkKaXeowCMbDyO/SkaPIlFapePTNJWC/xfS4AzV9FBY1gtIGqxrSdaNnQZ+f7SNHhJP62j1bRYW+CIQUswK1eACk6utwJPF8y1CYhGDMHOqV6+2KbtCx0ixxIYyr6fGLvHNsEV9y6hiAmtuiO4TFNNPMj4DR8yRTs6MrlYXRRguQ283n user@DESKTOP-C4JGSRR"
}