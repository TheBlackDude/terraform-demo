provider "aws" {
  region = "eu-west-3"
}

resource "aws_launch_configuration" "first_sample" {
  image_id        = "ami-0c229bfed6d47178b"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.security_group.id]
  
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "security_group" {
  name = "terraform-ingress-exmaple"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "server_port" {
  description = "The port the server will be listning on for HTTP requests."
  type        = number
  default     = 8080
}

/* output "public_ip" {
  value       = aws_launch_configuration.first_sample.public_ip
  description = "The public IP of the web server"
  sensitive   = true
} */

resource "aws_autoscaling_group" "first_sample" {
  launch_configuration = aws_launch_configuration.first_sample.name
  vpc_zone_identifier  = data.aws_subnet_ids.subnet_source_sample.ids

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

data "aws_vpc" "vpc_source_sample" {
  default = true
}

data "aws_subnet_ids" "subnet_source_sample" {
  vpc_id = data.aws_vpc.vpc_source_sample.id
}

resource "aws_lb" "lb_sample" {
  name               = "terraform-lb-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.subnet_source_sample.ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb_sample.arn
  port              = 80
  protocol          = "HTTP"

  # By Default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}


