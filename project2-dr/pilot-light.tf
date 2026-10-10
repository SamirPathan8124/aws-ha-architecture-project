data "aws_availability_zones" "dr" {
  provider = aws.dr
  state    = "available"
}

data "aws_ssm_parameter" "al2023_dr" {
  provider = aws.dr
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "dr" {
  provider             = aws.dr
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "dr-vpc" }
}

resource "aws_internet_gateway" "dr" {
  provider = aws.dr
  vpc_id   = aws_vpc.dr.id
  tags     = { Name = "dr-igw" }
}

resource "aws_subnet" "dr_public" {
  provider                = aws.dr
  count                   = 2
  vpc_id                  = aws_vpc.dr.id
  cidr_block              = "10.1.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.dr.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "dr-public-${count.index + 1}" }
}

resource "aws_route_table" "dr_public" {
  provider = aws.dr
  vpc_id   = aws_vpc.dr.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr.id
  }
  tags = { Name = "dr-public-rt" }
}

resource "aws_route_table_association" "dr_public" {
  provider       = aws.dr
  count          = 2
  subnet_id      = aws_subnet.dr_public[count.index].id
  route_table_id = aws_route_table.dr_public.id
}

resource "aws_security_group" "dr_alb" {
  provider = aws.dr
  name     = "dr-alb-sg"
  vpc_id   = aws_vpc.dr.id

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
}

resource "aws_security_group" "dr_web" {
  provider = aws.dr
  name     = "dr-web-sg"
  vpc_id   = aws_vpc.dr.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.dr_alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "dr" {
  provider      = aws.dr
  name_prefix   = "dr-web-"
  image_id      = data.aws_ssm_parameter.al2023_dr.value
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.dr_web.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y httpd
    echo "<h1>DR Region: Singapore (ap-southeast-1)</h1>" > /var/www/html/index.html
    systemctl enable --now httpd
  EOF
  )
}

resource "aws_autoscaling_group" "dr" {
  provider            = aws.dr
  name                = "dr-asg"
  min_size            = 0
  max_size            = 2
  desired_capacity    = 0
  vpc_zone_identifier = aws_subnet.dr_public[*].id

  launch_template {
    id      = aws_launch_template.dr.id
    version = "$Latest"
  }
}