provider "aws" {

    # which region eu-west-1
    region = eu-west-1
}
resource "aws_instance" "app_instance" {

    # pick the ami
    ami = ami-0776c814353b4814d

    # size of instance/ type of instance - t2micro
    instance_type = t2micro
    

    # associate pub ip
    associate_public_ip_address = true
    
    # ssh key pair
    key_name = tech258muyis
    
    # name instance
    tags = {
        Name = fun_deployment_app
    }
}
resource "aws_instance" "db_instance" {

    # pick the ami
    ami = ami-0776c814353b4814d

    # size of instance/ type of instance - t2micro
    instance_type = t2micro
    

    # associate pub ip
    associate_public_ip_address = true
    
    # ssh key pair
    key_name = tech258muyis
    
    # name instance
    tags = {
        Name = fun_deployment_db
    }
}
resource "aws_vpc" "deployment vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = tech258_muyis_vpc
  }
}

resource "aws_subnet" "pub" {
  vpc_id     = aws_vpc.tech258_muyis_vpc.id
  cidr_block = "10.0.11.0/24"
  availability_zone = eu-west-1a

  tags = {
    Name = "tech258_muyis_pub_subnet"
  }
}

resource "aws_subnet" "priv" {
  vpc_id     = aws_vpc.tech258_muyis_vpc.id
  cidr_block = "10.0.21.0/24"
  availability_zone = eu-west-1a

  tags = {
    Name = "tech258_muyis_priv_subnet"
  }
}

resource "aws_security_group" "app sg" {
  name        = "tech258_muyis_allow_22_80_3000"
  description = "Allow inbound 22 80 3000"
  vpc_id      = aws_vpc.tech258_muyis_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
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
    Name = "tech258_muyis_allow_22_80_3000"
  }
}

resource "aws_security_group" "db sg" {
  name        = "tech258_muyis_allow_22_27017"
  description = "Allow inbound 22 27017"
  vpc_id      = aws_vpc.tech258_muyis_vpc.id

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
    Name = "tech258_muyis_allow_22_27017"
  }
}
resource "aws_launch_template" "autoscaler group" {
  name_prefix   = "db_autoscaler"
  image_id      = ami-0776c814353b4814d
  instance_type = "t2micro"
}

# Declaring the Launch Template for the Auto Scaling Group
resource "aws_launch_template" "app-launch-template" {
  name_prefix   = "app-launch-template"
  # image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  # key_name      = "terraform_two_tiered"
  # security_group_names = [aws_security_group.app_sg.name]
  # vpc_security_group_ids = [aws_security_group.app_sg.id]
 
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp2"
    }
  }
}
 
# Declaring the Auto Scaling Group
resource "aws_autoscaling_group" "app-asg" {
  launch_template {
    id      = aws_launch_template.app-launch-template.id
    version = "$Latest"
  }
 
  vpc_zone_identifier  = [
    # aws_subnet.app_subnet_a.id
  ]
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  health_check_type    = "EC2"
  health_check_grace_period = 300
  protect_from_scale_in = false
 
  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
}