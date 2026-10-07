# AWS High Availability Architecture

A highly available web tier on AWS, first built in the console (Phase 1), then rebuilt with Terraform (Phase 2) and deployed through a GitHub Actions pipeline (Phase 3). Tested by terminating a server while the site stayed up.

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
Auto Scaling Group: 2-4 x EC2 t3.micro (public subnets, 2 AZs)       <- web-sg
   |
   v
RDS MySQL (private subnets)                          <- db-sg
```

## What I built

| Layer | Service | Details |
|---|---|---|
| Network | VPC | `10.0.0.0/16` |
| Load balancing | ALB + Target Groups | Public subnets |
| Compute        | Launch Template + ASG | Public subnets (web-sg accepts traffic only from alb-sg) |
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

1. Opened the ALB URL and refreshed several times. The page alternated between the servers in ap-south-1a and ap-south-1b (different private IPs), so traffic was being spread across both AZs.
2. Terminated the instance in ap-south-1a from the EC2 console and kept refreshing the ALB URL.
3. The target group marked the terminated instance as unhealthy/draining, and the site kept responding from the 1b instance without going down.
4. The Auto Scaling Group launched a replacement instance on its own, and the target group showed both targets healthy again after about 1 minutes.
   

| Event                        | Time (IST) | Action                         |
| ---------------------------- | ---------- | ------------------------------ |
| Instance terminated          | 18:07      | Manual termination for testing |
| Replacement instance Running | 18:10      | Launched by the ASG            |
| Both targets healthy again   | 18:11      | Checked in the ALB target group |


Screenshots :

* ![Targets healthy]
  https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20181112.png
* ![Response from 1a]
  https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20180751.png
* ![Response from 1b]
  https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20174720.png
* ![ASG activity after termination]
  https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20181013.png
* ![Security group rules]
  https://github.com/SamirPathan8124/aws-ha-architecture-project/blob/main/screenshots/Screenshot%202026-10-04%20192123.png

## Problems I hit and how I fixed them

**502 Bad Gateway from the ALB**

- Problem: opening the ALB URL gave 502 Bad Gateway, and the targets in the target group showed as unhealthy.
- Cause: the instances were launched without a public IP, and this setup has no NAT Gateway. So they could not reach the internet, user-data could not install the web server, and the health checks failed.
- Fix: enabled auto-assign public IP in the launch template and replaced the instances. The targets turned healthy and the site loaded.
- Learning: the ALB talks to the instances over their private IPs, but the instances still need outbound internet access (public IP or NAT Gateway) to install packages. A 502 usually means the targets are unhealthy.

**Hard-coded database password in user data**

- Problem: while writing the user-data script I left a placeholder database password in plain text.
- Fix: removed it from the script and [moved it to AWS Secrets Manager / passed it as a sensitive Terraform variable]. Kept `*.tfstate` out of the repo with `.gitignore`.
- Learning: secrets do not belong in scripts or in the repo.

## Phase 2: Infrastructure as Code (Terraform)

   The same architecture is deployed via code.

   terraform init,

   terraform plan,

   terraform apply, # needs approval
   terraform destroy    # cleanup when done

 ![Terraform apply output]

   <img width="955" height="467" alt="Screenshot 2026-10-06 000454" src="https://github.com/user-attachments/assets/d8fb0e60-  a1e7-4196-8ba6-def3945749fa" />
<img width="958" height="467" alt="Screenshot 2026-10-06 000536" src="https://github.com/user-attachments/assets/5b050ef5-b3c6-432e-8d17-3cbd6c8fa411" />

---

# Phase 3: CI/CD Pipeline & Automation

Automated deployment workflow using GitHub Actions.

- **Trigger:** Push to 'main' branch automatically runs 'terraform plan'.
- **Approval:** Manual review and approval required before running 'terraform apply'.
- **State Management:** Remote backend configured with AWS S3 and DynamoDB table for state locking.

## Design decisions and trade-offs

- [ ] Enable Multi-AZ on RDS and test failover
- [ ] Add an HTTPS listener (ACM certificate) on the ALB
- [ ] Add CloudWatch alarms and an Auto Scaling policy
- [ ] Connect a small app to the database

## What this project covers

​   VPC design and routing, security group chaining, load balancing, Auto Scaling and health checks, private database  placement, CloudWatch alarms, Terraform basics, cost awareness, troubleshooting.

## What I learned

- How chained security groups work: the web servers only accept traffic from the load balancer, and the database only from the web servers.
- How the ALB health checks decide which instances get traffic, and why a failing health check shows up as a 502.
- How the Auto Scaling Group replaces a terminated instance without any manual step.
- How to rebuild the console setup in Terraform and run it through a GitHub Actions pipeline.

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
