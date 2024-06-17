provider "aws" {
  region = "eu-west-1"
}
 
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "muyis-vpc-2t-deploy"
  }
}
 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
 
  tags = {
    Name = "muyis-igw"
  }
}
 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
 
  tags = {
    Name = "muyis-public-rt"
  }
}
 
resource "aws_route_table_association" "public_rt_association1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public_rt.id
}
 
resource "aws_route_table_association" "public_rt_association2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_rt.id
}
 
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1a"
  tags = {
    Name = "muyis-public-subnet-1"
  }
}
 
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1b"
  tags = {
    Name = "muyis-public-subnet-2"
  }
}
 
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "muyis-private-subnet"
  }
}
 
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id
 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = {
    Name = "app-sg"
  }
}
 
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id
 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = {
    Name = "db-sg"
  }
}
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale_out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.app.name
}
 
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale_in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.app.name
}
 
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name                = "high_cpu"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Average"
  threshold                 = 7
  alarm_description         = "This metric monitors the CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions             = [aws_autoscaling_policy.scale_out.arn]
  ok_actions                = []
  insufficient_data_actions = []
}
 
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name                = "low_cpu"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 10
  alarm_description         = "This metric monitors the CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions             = [aws_autoscaling_policy.scale_in.arn]
  ok_actions                = []
  insufficient_data_actions = []
} 
resource "aws_launch_configuration" "app" {
  name          = "app-launch-configuration"
  image_id      = "ami-012673b275923ce27"  # App AMI ID
  instance_type = "t2.micro"
  key_name      = "tech258muyis"
  security_groups = [aws_security_group.app_sg.id]
 
  user_data = <<-EOF
    #!/bin/bash
    cd /home/ubuntu/tech258-sparta-test-app/app
    export DB_HOST="mongodb://${aws_instance.db.private_ip}:27017/posts"
    cd seeds
    node seed.js &
    cd ..
    node app.js &
  EOF
 
  lifecycle {
    create_before_destroy = true
  }
}
 
resource "aws_autoscaling_group" "app" {
  launch_configuration = aws_launch_configuration.app.id
  min_size             = 2
  max_size             = 3
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.public1.id, aws_subnet.public2.id]
 
  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
 
  target_group_arns = [
    aws_lb_target_group.app_http.arn,
    aws_lb_target_group.app_ssh.arn
  ]
}
 
resource "aws_lb" "app" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]
 
  enable_deletion_protection = false
 
  tags = {
    Name = "app-load-balancer"
  }
}
 
resource "aws_lb_target_group" "app_http" {
  name     = "app-http-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
 
  health_check {
    interval            = 30
    protocol            = "HTTP"
    path                = "/"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
 
  tags = {
    Name = "app-http-target-group"
  }
}
 
resource "aws_lb_target_group" "app_ssh" {
  name     = "app-ssh-target-group"
  port     = 22
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
 
  health_check {
    interval            = 30
    protocol            = "TCP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
 
  tags = {
    Name = "app-ssh-target-group"
  }
}
 
resource "aws_lb_listener" "app_http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_http.arn
  }
 
  tags = {
    Name = "app-http-listener"
  }
}
 
resource "aws_lb_listener" "app_ssh" {
  load_balancer_arn = aws_lb.app.arn
  port              = 22
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_ssh.arn
  }
 
  tags = {
    Name = "app-ssh-listener"
  }
}
 
resource "aws_instance" "db" {
  ami                         = "ami-04c467e4d4b577a37"  # Database AMI ID
  instance_type               = "t2.micro"
  key_name                    = "tech258muyis"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.db_sg.id]
  associate_public_ip_address = false
 
  #user_data = file("database-provision.sh")
 
  tags = {
    Name = "db-instance"
  }
}
 
terraform {
  backend "s3" {
    bucket = "tech258-muyis-bucket"
    key    = "dev/terraform.tfstate"
    region = "eu-west-1"
  }
}
