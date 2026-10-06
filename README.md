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
| Network | VPC | `10.0.0.0/16` |
| Load balancing | ALB + Target Groups | Public subnets |
| Compute | Launch Template + ASG | Private subnets |
| Database | RDS MySQL | Private subnet |
| Monitoring | CloudWatch | System metrics |
| Access | IAM | MFA on the root account |

Each web server shows its private IP address.

## Security design

Traffic is allowed in a chained security group model:

1. `alb-sg`: HTTP 80 from anywhere (`0.0.0.0/0`)
2. `web-sg`: HTTP 80 **only** from `alb-sg`
3. `db-sg`: MySQL 3306 **only** from `web-sg`

Also:
- No SSH port is open on any server (used Systems Manager Session Manager)
- The database sits in private subnets with no internet gateway route
- The database password is securely managed

## Phase 1: Console build

1. Opened the ALB URL and refreshed to verify traffic distribution.
2. Terminated one EC2 instance to test resilience.
3. [Write what you saw: the instance stopped, and traffic automatically routed to the healthy one].
4. The Auto Scaling Group launched a replacement instance automatically.

| Event | Time | Action |
|---|---|---|
| Instance terminated | [06:02] | Manual termination for testing |
| Replacement instance Running | [06:04] | ASG health check response |
| Both targets Healthy again | [06:07] | Verified via ALB target group |

Screenshots (replace FILE with your actual file names):

* ![Targets healthy]
* https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20181112.png
* ![Response from 1a]
* https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20180751.png
* ![Response from 1b]
* https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20174720.png
* ![ASG activity after termination]
* https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20181013.png
* ![Security group rules]
* https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20192123.png

## Problems I hit and how I fixed them

**502 Bad Gateway from the ALB**
- Cause: the instances were placed in private subnets without assigning public IPs, so they couldn't fetch updates.
- Fix: enabled auto-assign public IP on the launch template during troubleshooting.
- Learning: ELB health checks depend entirely on proper routing and target group response codes.

**Hard-coded database password in user data script**
- Cause: a placeholder password was left in plain text.
- Fix: moved it to a sensitive environment variable using AWS Secrets Manager.
- Learning: secrets never belong in code or user-data scripts.

## Phase 2: Infrastructure as Code (Terraform)

   The same architecture is deployed via code.

   terraform init,

   terraform plan,

   terraform apply, # needs approval
   terraform destroy    # cleanup when done

---

# Phase 3: CI/CD Pipeline & Automation

Automated deployment workflow using GitHub Actions.

- **Trigger:** Push to 'main' branch automatically runs 'terraform plan'.
- **Approval:** Manual review and approval required before running 'terraform apply'.
- **State Management:** Remote backend configured with AWS S3 and DynamoDB table for state locking.

## Design decisions and trade-offs

- **No NAT Gateway.** It costs money per hour and is not covered by free credits. Instances are in public subnets, but their security group only accepts traffic from the load balancer. In production I would use private subnets with a NAT Gateway per AZ.
- **RDS is Single-AZ.** The free plan did not allow Multi-AZ. In production I would enable Multi-AZ for automatic failover.
- **The database is not connected to an application yet.** This project focuses on the infrastructure and its protection. A small app using the database is a possible next step.
- **Resources deleted after testing** to keep costs near zero.

## What this project covers

​   VPC design and routing, security group chaining, load balancing, Auto Scaling and health checks, private database  placement, CloudWatch alarms, Terraform basics, cost awareness, troubleshooting.

## Roadmap

- [ ] Phase 1: build and test in the AWS console
- [ ] Phase 2: rebuild everything with Terraform (`terraform/`)
- [ ] Phase 3: GitHub Actions pipeline for `terraform plan` /validate/ `apply`
- [ ] Record a demo from the Terraform-built stack

## Repo structure

```
.
├── README.md
├── main.tf
├── .gitignore
├── .terraform.lock.hcl
├── .github/workflows/
├── scripts/user-data.sh
└── Project 1 screenshots/
```

## About

Built by Samir Pathan as a hands-on portfolio project to practice cloud infrastructure and high availability on AWS.
Certifications: Google Cloud Cybersecurity Professional, AWS Generative AI and AI Agents with Amazon Bedrock, Designing Hybrid and Multicloud Architectures, Cloud Native, Microservices, Containers, DevOps and Agile.

LinkedIn: [www.linkedin.com/in/samir-pathan-218b84239]
