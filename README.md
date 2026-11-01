# DevOps Assessment — Terraform + PostgreSQL

![Terraform](https://img.shields.io/badge/Terraform-Infrastructure_as_Code-844FBA)
![AWS](https://img.shields.io/badge/AWS-ECS_Fargate_%7C_RDS-FF9900)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED)
![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF)

## 1. Project Overview

This repository implements a DevOps assessment focused on AWS infrastructure design using Terraform and PostgreSQL database reliability.

The project demonstrates:

- Modular Terraform infrastructure for AWS.
- Public Application Load Balancer (ALB), private ECS/Fargate and isolated RDS PostgreSQL.
- Separate development and production environments.
- Environment-specific infrastructure sizing and database protection.
- Local PostgreSQL deployment using Docker Compose.
- Database schema migrations and deterministic seed data.
- Query optimization using PostgreSQL indexes.
- Automated database backup and restore.
- GitHub Actions CI/CD validation.

**Important:** Actual AWS deployment is not required. Terraform configuration can be formatted and validated without AWS credentials. A real Terraform plan requires valid AWS credentials and appropriate AWS permissions.

## 2. Technology Stack

| Component | Technology |
|---|---|
| Infrastructure as Code | Terraform >= 1.6 |
| Cloud Platform | AWS |
| Networking | VPC, Subnets, Internet Gateway, NAT Gateway |
| Load Balancing | Application Load Balancer |
| Container Orchestration | ECS with AWS Fargate |
| Cloud Database | Amazon RDS PostgreSQL |
| Local Database | PostgreSQL 16 |
| Container Runtime | Docker Compose v2 |
| Database Migration | PostgreSQL SQL scripts |
| Backup and Restore | Bash, pg_dump and pg_restore |
| CI/CD | GitHub Actions |
| Version Control | Git and GitHub |

PostgreSQL is the only database engine used in this assessment.

## 3. AWS Infrastructure Architecture

```text
                      Internet
                         |
                         v
              Application Load Balancer
                   (Public Subnets)
                         |
                         | HTTP :80
                         v
                  ECS / Fargate
              (Private App Subnets)
                         |
                         | PostgreSQL :5432
                         v
                 Amazon RDS
                  PostgreSQL
            (Isolated DB Subnets)
```

The architecture uses a custom VPC across two AWS Availability Zones.

### Network Design

- **Public subnets:** Host the internet-facing ALB and NAT Gateways.
- **Private application subnets:** Host ECS/Fargate workloads without public IP addresses.
- **Isolated database subnets:** Host RDS without a default internet route.
- **Internet Gateway:** Provides public internet connectivity for the ALB.
- **NAT Gateways:** Provide outbound connectivity for private ECS workloads.
- **Security Groups:** Restrict traffic between ALB, ECS and RDS.

### Security Group Rules

| Security Group | Inbound Access |
|---|---|
| ALB | TCP 80 from `0.0.0.0/0` |
| ECS/Fargate | TCP 80 from ALB security group only |
| RDS PostgreSQL | TCP 5432 from ECS security group only |

RDS is configured with:

- `publicly_accessible = false`
- Encrypted database storage.
- AWS-managed master password.
- Private database subnet group.
- Environment-specific backup retention.
- Environment-specific deletion protection.
- Optional Multi-AZ deployment.

The ECS task uses an Nginx placeholder image. It demonstrates the infrastructure and networking architecture but does not establish an actual database connection.

A production backend would need a PostgreSQL client and securely retrieved credentials, for example through AWS Secrets Manager.

## 4. Repository Structure

```text
devops-terraform-db-assessment/
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── infra/
│   ├── modules/
│   │   ├── network/
│   │   │   └── main.tf
│   │   ├── ecs/
│   │   │   └── main.tf
│   │   └── rds/
│   │       └── main.tf
│   │
│   └── envs/
│       ├── dev/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── versions.tf
│       │   ├── terraform.tfvars
│       │   └── backend.hcl.example
│       │
│       └── prod/
│           ├── main.tf
│           ├── variables.tf
│           ├── versions.tf
│           ├── terraform.tfvars
│           └── backend.hcl.example
│
├── db/
│   ├── migrations/
│   │   ├── 001_schema.sql
│   │   └── 002_seed.sql
│   └── query.sql
│
├── scripts/
│   ├── backup.sh
│   ├── restore.sh
│   └── verify.sh
│
├── compose.yaml
├── .gitignore
└── README.md
```

Terraform provider lock files may also be present in the environment directories after initialization.

The `backups/` directory is created during database backup and should not be committed to Git.

## 5. Prerequisites

Install the following tools:

- Git
- Docker Desktop or Docker Engine with Compose v2
- Terraform >= 1.6
- Bash or Git Bash
- GitHub account

For Windows users, ensure Docker Desktop is running with the Linux container engine.

Verify the installations:

```bash
git --version
docker --version
docker compose version
terraform version
```

AWS credentials are not required for local database testing or Terraform formatting and validation.

## 6. Clone the Repository

```bash
git clone https://github.com/vinit992/devops-terraform-db-assessment.git

cd devops-terraform-db-assessment
```

All subsequent commands assume execution from the repository root unless another directory is specified.

## 7. Local PostgreSQL Setup

### Step 1: Start PostgreSQL

```bash
docker compose up -d --wait db
```

This starts PostgreSQL 16 and initializes the database on first volume creation.

The initialization process executes:

- `001_schema.sql` — creates the database tables and indexes.
- `002_seed.sql` — inserts deterministic sample records.

### Step 2: Verify Container Status

```bash
docker compose ps
```

The PostgreSQL database container should be running and healthy.

### Step 3: Verify Seed Data

```bash
docker compose exec -T db psql -U hotel -d hotels \
  -c "SELECT COUNT(*) FROM hotel_bookings;"
```

Expected result:

```text
 count
-------
   250
(1 row)
```

Check booking events:

```bash
docker compose exec -T db psql -U hotel -d hotels \
  -c "SELECT COUNT(*) FROM booking_events;"
```

Check bookings grouped by city:

```bash
docker compose exec -T db psql -U hotel -d hotels \
  -c "SELECT city, COUNT(*) FROM hotel_bookings GROUP BY city ORDER BY city;"
```

Check booking statuses:

```bash
docker compose exec -T db psql -U hotel -d hotels \
  -c "SELECT status, COUNT(*) FROM hotel_bookings GROUP BY status ORDER BY status;"
```

The dataset contains multiple organizations, cities, booking statuses and booking events.

## 8. Database Schema

### hotel_bookings

Stores hotel booking information.

| Column | Type |
|---|---|
| id | UUID PRIMARY KEY |
| org_id | UUID NOT NULL |
| hotel_id | VARCHAR(100) |
| city | VARCHAR(100) |
| checkin_date | DATE |
| checkout_date | DATE |
| amount | NUMERIC(12,2) |
| status | VARCHAR(50) |
| created_at | TIMESTAMP |

### booking_events

Stores events associated with hotel bookings.

| Column | Type |
|---|---|
| id | BIGSERIAL PRIMARY KEY |
| booking_id | UUID |
| event_type | VARCHAR(100) |
| payload | JSONB |
| created_at | TIMESTAMP |

The schema includes an index on `booking_events.booking_id` to improve booking-event lookups.

## 9. Query Optimization and Indexing

The assessment requires optimization of this query:

```sql
SELECT
    org_id,
    status,
    COUNT(*),
    SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

### Index Strategy

The composite index is:

```sql
CREATE INDEX idx_bookings_city_created_org_status
ON hotel_bookings (
    city,
    created_at DESC,
    org_id,
    status
)
INCLUDE (amount);
```

### Why This Index?

- `city` is first because the query uses an equality filter.
- `created_at` is second because the query filters by a date range.
- `org_id` and `status` are included as index key columns because they are required for grouping and aggregation.
- `amount` is included as a non-key column to allow PostgreSQL to consider index-only scans.

This index can reduce the number of table rows PostgreSQL needs to inspect when the dataset becomes large and the filter is selective.

With only 250 records, PostgreSQL may prefer a sequential scan because reading the small table can be cheaper than using an index.

### Execute the Query and Inspect Its Plan

From the repository root:

```bash
docker compose exec -T db psql -U hotel -d hotels \
  < db/query.sql
```

The SQL file includes query execution-plan analysis using:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

Review execution time, scan type, actual rows and buffer usage.

For meaningful performance comparisons, use a realistically sized dataset and compare query plans before and after indexing.

## 10. Database Backup

The backup script creates a timestamped PostgreSQL dump.

### Step 1: Make Scripts Executable

On Linux or macOS, if necessary:

```bash
chmod +x scripts/*.sh
```

On Windows, use Git Bash to execute the scripts.

### Step 2: Run Backup

```bash
./scripts/backup.sh
```

The script creates a timestamped dump in the `backups/` directory.

Example:

```text
backups/hotels_20261101T103000Z.dump
```

The backup uses PostgreSQL's `pg_dump` utility.

### Step 3: Verify Backup File

```bash
ls -lh backups/
```

Expected result: at least one non-empty timestamped database dump.

Backups are local test artifacts and should not be committed to Git.

## 11. Database Restore

The restore process demonstrates recovery into a separate fresh PostgreSQL database.

### Step 1: Restore the Latest Backup

```bash
./scripts/restore.sh
```

The restore script uses the backup created by `backup.sh` and restores it into the separate `restore_db` PostgreSQL service.

The source database is not overwritten.

### Step 2: Verify the Restored Database

```bash
./scripts/verify.sh
```

Expected result:

```text
PASS: counts and total amount match
```

The verification compares booking counts, event counts and booking amount totals between the source and restored databases.

This demonstrates that the backup contains the expected data and that the restored database matches the source for these checks.

### Step 3: Stop Containers

```bash
docker compose --profile restore down
```

To perform a completely fresh test:

```bash
docker compose --profile restore down -v
```

**Warning:** The `-v` flag deletes the local database volumes and their data.

Database initialization scripts run only when the database volume is first created.

## 12. Terraform Environment Configuration

The project uses reusable modules and separate environment configurations.

| Configuration | Development | Production |
|---|---|---|
| ECS CPU | 256 units | 512 units |
| ECS Memory | 512 MiB | 1024 MiB |
| ECS Desired Tasks | 1 | 2 |
| RDS Instance | db.t3.micro | db.t3.medium |
| RDS Storage | 20 GiB | 100 GiB |
| Backup Retention | 1 day | 14 days |
| Deletion Protection | Disabled | Enabled |
| Multi-AZ RDS | Disabled | Enabled |
| Terraform Backend Key | dev | prod |

Each environment has its own variables, Terraform variable values and backend configuration example.

The production environment uses larger resource allocations, longer backup retention, deletion protection and Multi-AZ RDS.

## 13. Terraform Formatting and Validation

No AWS deployment is required.

### Step 1: Format Terraform Files

From the repository root:

```bash
terraform fmt -recursive infra
```

Verify formatting:

```bash
terraform fmt -check -recursive infra
```

### Step 2: Validate Development

```bash
cd infra/envs/dev

terraform init -backend=false -input=false

terraform validate
```

Expected output:

```text
Success! The configuration is valid.
```

### Step 3: Validate Production

From the development directory:

```bash
cd ../prod

terraform init -backend=false -input=false

terraform validate
```

Expected output:

```text
Success! The configuration is valid.
```

### Step 4: Return to the Repository Root

```bash
cd ../../..
```

The `-backend=false` option avoids initializing the example remote S3 backend. Terraform still downloads the required providers and modules.

Formatting and validation do not require AWS credentials.

## 14. Terraform Plan Review (Optional)

A real Terraform plan can be generated with valid AWS credentials and the required permissions.

Actual AWS deployment is not required.

### Option A: Plan Without S3 Backend

From the repository root:

```bash
cd infra/envs/dev

terraform init -backend=false -input=false

terraform plan -refresh=false -lock=false
```

Repeat for production:

```bash
cd ../prod

terraform init -backend=false -input=false

terraform plan -refresh=false -lock=false
```

This approach is suitable for a local assessment plan review when no remote backend has been initialized.

It is not a recommended shared team state-management workflow.

### Option B: Plan With S3 Remote Backend

The repository contains separate backend configuration examples:

```text
infra/envs/dev/backend.hcl.example
infra/envs/prod/backend.hcl.example
```

Create an S3 state bucket separately with appropriate encryption, versioning, access controls and state locking.

Copy the relevant example file to `backend.hcl` and update the bucket configuration.

From the dev environment:

```bash
terraform init -backend-config=backend.hcl

terraform validate

terraform plan -refresh=false -out=tfplan

terraform show -no-color tfplan > plan.txt
```

Repeat the process for production.

The backend keys are separate:

```text
hotel-assessment/dev/terraform.tfstate
hotel-assessment/prod/terraform.tfstate
```

**Important notes:**

- `terraform plan -refresh=false` is not an offline plan.
- AWS credentials and provider permissions are still required.
- The S3 bucket must exist before initializing the remote backend.
- No `terraform apply` is required.
- Terraform plan files and state files may contain sensitive information and must not be committed.
- AWS infrastructure will incur charges if deployed.

## 15. GitHub Actions CI/CD

The CI/CD workflow is defined in:

```text
.github/workflows/ci.yml
```

### Workflow Triggers

The workflow runs on supported pushes, pull requests and manual dispatch.

### Terraform Validation Jobs

The workflow runs separate Terraform checks for:

- Development
- Production

Each environment performs:

1. Terraform setup.
2. Formatting check.
3. Terraform initialization without remote backend.
4. Terraform configuration validation.
5. Optional Terraform plan when AWS credentials and plan execution are enabled.

### PostgreSQL Database Job

The database job performs:

1. Checkout repository.
2. Start PostgreSQL with Docker Compose.
3. Initialize schema and seed data.
4. Verify database records and query plan.
5. Execute database backup.
6. Restore into a fresh database.
7. Verify restored data.

### Expected Workflow Results

| Job | Expected Result |
|---|---|
| terraform (dev) | Passed |
| terraform (prod) | Passed |
| database | Passed |

All three required jobs have passed successfully during project verification.

[View GitHub Actions Workflow Results](https://github.com/vinit992/devops-terraform-db-assessment/actions)

## 16. Running GitHub Actions on a Pull Request

1. Clone the repository.
2. Create a feature branch.
3. Make a small change.
4. Commit and push the branch.
5. Open a pull request against `main`.
6. Open the **Actions** tab.
7. Inspect the Terraform and database jobs.
8. Review the job logs and any generated plan artifacts.

Example Git commands:

```bash
git checkout -b test/ci-validation

git add README.md

git commit -m "Test CI validation"

git push -u origin test/ci-validation
```

Open a pull request from `test/ci-validation` into `main`.

If no files have changed, make a small README update before committing.

### Optional AWS Plan in GitHub Actions

To enable real Terraform plans, configure the repository with:

**Repository secrets:**

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
```

`AWS_SESSION_TOKEN` is required only for temporary credentials.

**Repository variable:**

```text
ENABLE_AWS_PLAN=true
```

When enabled with valid AWS credentials, the workflow runs Terraform plans for dev and prod and uploads plan text artifacts.

Expected artifact names:

```text
terraform-plan-dev
terraform-plan-prod
```

For production CI, GitHub OIDC with short-lived AWS credentials is preferable to long-lived AWS access keys.

Pull requests from forks may not receive repository secrets.

Terraform plan outputs can expose sensitive information and should be access-controlled.

## 17. Troubleshooting

### Docker Engine Is Not Running

Error:

```text
Cannot connect to Docker daemon
```

Solution: Start Docker Desktop, wait for the engine to become ready and verify:

```bash
docker info
```

### PostgreSQL Port Already in Use

If port `5432` is occupied, stop the conflicting PostgreSQL service or change the published host port in `compose.yaml`.

### Seed Data Missing

PostgreSQL initialization scripts run only when the database volume is created for the first time.

To recreate the local test database:

```bash
docker compose --profile restore down -v

docker compose up -d --wait db
```

This deletes existing local database data.

### Terraform Formatting Failure

Run:

```bash
terraform fmt -recursive infra
```

Ensure Terraform blocks use valid HCL syntax.

### Terraform Validation Failure

Run from the relevant environment directory:

```bash
terraform init -backend=false

terraform validate
```

Review the error messages and referenced module files.

### Backup Script Permission Denied

On Linux:

```bash
chmod +x scripts/*.sh
```

If GitHub Actions reports permission denied, ensure executable permissions are tracked in Git:

```bash
git update-index --chmod=+x scripts/backup.sh
git update-index --chmod=+x scripts/restore.sh
git update-index --chmod=+x scripts/verify.sh
```

### AWS Terraform Plan Failure

Possible causes:

- Missing or invalid AWS credentials.
- Insufficient IAM permissions.
- Unsupported RDS instance class or PostgreSQL version in the selected region.
- Incorrect S3 backend configuration.
- AWS account or regional restrictions.

Terraform validation does not guarantee that AWS will accept every resource configuration during a real plan or deployment.

## 18. Security and Production Considerations

The implementation demonstrates security-oriented infrastructure design:

- RDS is not publicly accessible.
- Database inbound access is restricted to ECS.
- ECS tasks run without public IP addresses.
- Database storage is encrypted.
- Master credentials are managed through AWS Secrets Manager.
- Production deletion protection is enabled.
- Production RDS uses Multi-AZ configuration.
- Separate Terraform environment configurations are maintained.

For a production deployment, additional improvements would include:

- HTTPS with ACM certificates.
- AWS WAF protection.
- ECS service autoscaling.
- Container image digest pinning.
- Dedicated application IAM roles.
- VPC endpoints where appropriate.
- RDS performance monitoring and alerting.
- Automated backup recovery testing.
- Separate AWS accounts for development and production.
- Remote Terraform state with appropriate locking and access controls.

## 19. Assessment Verification Checklist

| Requirement | Implementation |
|---|---|
| Terraform AWS infrastructure | Included |
| VPC and public/private subnets | Included |
| ALB and security groups | Included |
| ECS/Fargate cluster, task and service | Included |
| Private RDS PostgreSQL | Included |
| Separate dev/prod environments | Included |
| Separate backend configurations | Included as examples |
| Environment-specific resource sizing | Included |
| Backup retention and deletion protection | Included |
| PostgreSQL Docker Compose | Included |
| SQL schema migrations | Included |
| 100+ booking records | 250 records |
| Multiple organizations, cities and statuses | Included |
| Booking events | Included |
| Query optimization index | Included |
| Timestamped database backup | Included |
| Fresh database restore | Included |
| Restore verification | Included |
| GitHub Actions workflow | Included |
| Terraform formatting and validation | Passed in CI |
| PostgreSQL backup/restore verification | Passed in CI |
| Real AWS Terraform plan | Optional; requires credentials |
| AWS deployment | Not required |

## 20. Submission

**Project:** DevOps Assessment — Terraform + PostgreSQL

**Candidate:** Vinit Kumar

**Repository:** https://github.com/vinit992/devops-terraform-db-assessment

**CI/CD Results:** https://github.com/vinit992/devops-terraform-db-assessment/actions

The project provides a reproducible local PostgreSQL reliability workflow and modular Terraform AWS infrastructure design.

All three required GitHub Actions jobs have passed. AWS deployment has intentionally not been performed, as permitted by the assessment requirements.
