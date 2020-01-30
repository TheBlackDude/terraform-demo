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

output "alb_dns_name" {
  value       = aws_lb.lb_sample.dns_name
  description = "The domain name of the load balancer"
}

resource "aws_autoscaling_group" "first_sample" {
  launch_configuration = aws_launch_configuration.first_sample.name
  vpc_zone_identifier  = data.aws_subnet_ids.subnet_source_sample.ids

  target_group_arns = [aws_lb_target_group.target_sample.arn]
  health_check_type = "ELB"

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
  security_groups    = [aws_security_group.lb_security_group_sample.id]
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

resource "aws_security_group" "lb_security_group_sample" {
  name = "terraform-example-lb-security-group"

  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "target_sample" {
  name     = "terraform-example-target-group"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.vpc_source_sample.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "listener_rule_sample" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    field = "path-pattern"
    values = ["*"]
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_sample.arn
  }
}



