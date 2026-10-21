# AWS Cloud and DevOps Projects

Three hands-on AWS projects built step by step with Terraform. Each project was deployed live, tested, documented with screenshots, and then destroyed to avoid cost.

| # | Project | Main services | Folder |
|---|---------|---------------|--------|
| 1 | High Availability Architecture | ALB, Auto Scaling, RDS Multi-AZ, Terraform, GitHub Actions | [project1-ha](project1-ha/) |
| 2 | Disaster Recovery and Cost Optimization | S3 CRR, RDS cross-region replica, pilot light, Cost Explorer | [project2-dr](project2-dr/) |
| 3 | Secure DevOps Platform on AWS | EKS, Docker, ECR, Terraform modules, CI/CD, Trivy, Checkov, CloudWatch | [project3-platform](project3-platform/) |

---

## Project 1: High Availability Architecture

A Flask app running on EC2 instances behind an Application Load Balancer, with a Multi-AZ RDS database in ap-south-1.

- Auto Scaling group spreads instances across Availability Zones
- Launch template uses the latest Amazon Linux 2023 AMI from SSM
- RDS uses a managed master password
- Health check path is `/health`
- Tested instance refresh and failover
- Infrastructure built with Terraform, with a GitHub Actions workflow

Details and screenshots: [project1-ha](project1-ha/)

## Project 2: Disaster Recovery and Cost Optimization

Disaster recovery from Mumbai (ap-south-1) to Singapore (ap-southeast-1), plus a cost review.

- S3 versioning and cross-region replication (status COMPLETED)
- RDS cross-region replica, promote test took about 10 minutes
- Pilot light in Singapore: VPC, Auto Scaling group with desired capacity 0, and ALB
- Failover test: servers started 2:20 pm, DR page opened 2:35 pm (about 15 minutes application RTO)
- Route 53 failover is written as Terraform code and a diagram only, because I do not have a domain. I tested manual failover by scaling up the Auto Scaling group instead
- Cost review with Cost Explorer. Actual usage for Oct 1-10 was $14.96 (RDS $11.81, EC2 $1.15, ELB $0.98, VPC $0.90), covered by AWS credits

Details and screenshots: [project2-dr](project2-dr/)

## Project 3: Secure DevOps Platform on AWS

A containerized Flask app on Amazon EKS, with the whole platform defined as Terraform modules and checked by a CI pipeline.

- Terraform modules: vpc, ecr, iam, eks, monitoring
- Docker image runs as a non-root user with gunicorn
- Kubernetes manifests with a NetworkPolicy
- GitHub Actions: Terraform validate, Docker build, security scan (Trivy for the image, Checkov for Terraform)
- CloudWatch dashboard, EKS control plane logs and Container Insights
- Live run: 2 pods running with 0 restarts after a probe fix, `/health` returned ok through a load balancer, CI run green
- `terraform destroy` removed 44 resources

Details, screenshots and cost table: [project3-platform](project3-platform/)

---

## Tools used

Terraform, AWS (EC2, ALB, Auto Scaling, RDS, S3, EKS, ECR, IAM, VPC, CloudWatch, Route 53), Docker, Kubernetes, GitHub Actions, Trivy, Checkov, Python Flask, Linux

## How I worked

- Built each project in phases and tested every phase before moving on
- Saved screenshots as proof of each live run
- Destroyed all resources after testing and checked for leftovers in both regions

## Author

Samir Pathan

- GitHub: [SamirPathan8124](https://github.com/SamirPathan8124)
- LinkedIn: [Samir Pathan](https://www.linkedin.com/in/samir-pathan-218b84239)