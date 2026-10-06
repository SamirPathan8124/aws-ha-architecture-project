# 1. Provider Configuration (Mumbai Region)
provider "aws" {
  region = "ap-south-1"
}

# 2. VPC (10.0.0.0/16)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ha-web-vpc"
  }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ha-web-igw"
  }
}

# 4. Availability Zones Data Source
data "aws_availability_zones" "available" {
  state = "available"
}

# 5. Public Subnets (2 AZs) with auto-assign public IP enabled (fixing the 502 error issue)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "ha-web-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "ha-web-public-subnet-2"
  }
}

# 6. Private Subnets for RDS (2 AZs)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "ha-db-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "ha-db-private-subnet-2"
  }
}

# 7. Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "ha-web-public-rt"
  }
}

resource "aws_route_table_association" "rta_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "rta_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 8. Security Groups (Chained Security Design)
# ALB Security Group: Allow HTTP from anywhere
resource "aws_security_group" "alb_sg" {
  name        = "ha-alb-sg"
  description = "Allow HTTP inbound traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
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
    Name = "ha-alb-sg"
  }
}

# Web Server Security Group: Allow HTTP ONLY from ALB SG (No SSH port opened)
resource "aws_security_group" "web_sg" {
  name        = "ha-web-sg"
  description = "Allow HTTP from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ha-web-sg"
  }
}

# DB Security Group: Allow MySQL ONLY from Web SG
resource "aws_security_group" "db_sg" {
  name        = "ha-db-sg"
  description = "Allow MySQL from web servers only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from web servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ha-db-sg"
  }
}

# 9. Application Load Balancer (Internet-facing)
resource "aws_lb" "web_alb" {
  name               = "ha-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "ha-web-alb"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "ha-web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# 10. Launch Template for Auto Scaling Group (with Apache User Data showing Instance ID & AZ)
resource "aws_launch_template" "web_lt" {
  name_prefix   = "ha-web-lt-"
  image_id      = "ami-0f58b397bc5c1f2e8"
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    echo "<h1>Hello from High Availability Web Server</h1><p>Instance ID: $INSTANCE_ID</p><p>Availability Zone: $AZ</p>" > /var/www/html/index.html
  EOF
  )

  tags = {
    Name = "ha-web-template"
  }
}

# 11. Auto Scaling Group (Desired: 2, Min: 2, Max: 4)
resource "aws_autoscaling_group" "web_asg" {
  name                      = "ha-web-asg"
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 4
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns         = [aws_lb_target_group.web_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
  }
}

# 12. RDS MySQL Subnet Group & Database (Single-AZ, Free Tier friendly)
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "ha-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "ha-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql_db" {
  identifier             = "ha-rds-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "mydb"
  username               = "adminuser"
  password               = "SecurePassword123!" # Production mein ise variables ya secrets manager se lein
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  multi_az               = false # Single-AZ as per project decision
  skip_final_snapshot    = true

  tags = {
    Name = "ha-rds-mysql"
  }
}