# AWS High Availability Architecture

A highly available web tier on AWS, built in the console (Phase 1) and tested by terminating a server while the site stayed up. Terraform version (Phase 2) is in progress.

> Built as a learning project in `ap-south-1` (Mumbai). Resources were torn down after testing to avoid cost.

## Architecture

![Architecture diagram]

```
Internet
   |
   v
Application Load Balancer (public subnets, 2 AZs)   <- alb-sg
   |
   v
Auto Scaling Group: 2-4 x EC2 t3.micro (2 AZs)       <- web-sg
   |
   v
RDS MySQL (private subnets)                          <- db-sg
```

## What I built

| Layer | Service | Details |
|---|---|---|
| Network | VPC | `10.0.0.0/16`, 2 AZs, 2 public + 2 private subnets, Internet Gateway, no NAT Gateway |
| Load balancing | ALB + Target Group | Internet-facing, HTTP:80, health check path `/` |
| Compute | Launch Template + ASG | Amazon Linux 2023, `t3.micro`, desired 2 / min 2 / max 4, target tracking on CPU 50%, ELB health checks ON |
| Database | RDS MySQL | Private subnets only, public access OFF, Single-AZ (see decisions below) |
| Monitoring | CloudWatch | Alarms: `ha-web-cpu-high` (CPU > 70%), `ha-alb-5xx-errors`. Add dashboard / RDS alarm here if you created them |
| Access | IAM | Root secured with MFA, work done with a separate admin IAM user |

The web servers run Apache, installed through EC2 user data ([scripts/user-data.sh](scripts/user-data.sh)). Each server shows its own instance ID and AZ, so load balancing is visible when refreshing the page.

## Security design

Traffic is allowed in a chain, so nothing behind the load balancer is reachable directly from the internet:

1. `alb-sg`: HTTP 80 from anywhere
2. `web-sg`: HTTP 80 **only from `alb-sg`**
3. `db-sg`: MySQL 3306 **only from `web-sg`**

Other points:
- No SSH port is open on any security group.
- Database is in private subnets with public access turned off.
- MFA enabled on the root account; day-to-day work uses an IAM user.

## Failover test

1. Opened the ALB URL and refreshed: responses alternated between instances in `ap-south-1a` and `ap-south-1b`.
2. Terminated one EC2 instance manually.
3. The site kept responding from the remaining instance. [Write what you actually saw: any error or none.]
4. The Auto Scaling Group launched a replacement instance and it became Healthy in the target group.

| Event | Time |
|---|---|
| Instance terminated | [06:02] |
| Replacement instance Running | [06:04] |
| Both targets Healthy again | [06:07] |

Screenshots: see the [screenshots](Project%201%20screenshots/) folder.


## Problems I hit and how I fixed them

**502 Bad Gateway from the load balancer**
- Cause: the instances were in public subnets, but the subnets did not auto-assign public IPs. With no NAT Gateway, the servers had no internet access, so Apache never installed and the health checks failed.
- Fix: enabled auto-assign public IPv4 on both public subnets, terminated the unhealthy instances, and let the Auto Scaling Group replace them.
- Learning: the ELB health check in the ASG did its job by marking the broken servers unhealthy and replacing them.

## Design decisions and trade-offs

- **No NAT Gateway.** It costs money per hour and is not covered by free credits. Instances are in public subnets, but their security group only accepts traffic from the load balancer. In production I would use private subnets with a NAT Gateway per AZ.
- **RDS is Single-AZ.** The free plan did not allow Multi-AZ. In production I would enable Multi-AZ for automatic failover.
- **The database is not connected to an application yet.** This project focuses on the infrastructure and its protection. A small app using the database is a possible next step.
- **Resources deleted after testing** to keep costs near zero.

## Roadmap

- [x] Phase 1: build and test in the AWS console
- [ ] Phase 2: rebuild everything with Terraform (`terraform/`)
- [ ] Phase 3: GitHub Actions pipeline for `terraform plan` / `apply`
- [ ] Record a demo from the Terraform-built stack

## Repo structure

```
.
├── README.md
├── docs/architecture-diagram.png
├── scripts/user-data.sh
├── screenshots/
└── terraform/        (coming in Phase 2)
```

## About

Built by Samir Pathan as a hands-on portfolio project to practice cloud infrastructure and high availability on AWS.
Certifications: Google Cloud Cybersecurity Professional, AWS Generative AI and AI Agents with Amazon Bedrock, Designing Hybrid and Multicloud Architectures, Cloud Native, Microservices, Containers, DevOps and Agile.
LinkedIn: [www.linkedin.com/in/samir-pathan-218b84239]
