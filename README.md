# DevOps Assessment — Terraform + PostgreSQL

One database engine: PostgreSQL 16. AWS architecture: Internet → public ALB → private ECS/Fargate → isolated private RDS PostgreSQL. **AWS deployment is not required**. Local database tasks run with Docker Compose.

## Prerequisites

- Docker Engine with Compose v2, Bash, Terraform >= 1.6, Git
- AWS credentials **only** if reviewing a real Terraform plan
- GitHub repository for CI

## Repository

- `infra/modules/{network,ecs,rds}` reusable infrastructure
- `infra/envs/{dev,prod}` separate configurations and S3 backend examples
- `db/migrations` SQL schema and deterministic 250-row seed
- `scripts` backup, fresh restore and verification
- `.github/workflows/ci.yml` CI checks

## Run locally

```bash
chmod +x scripts/*.sh
docker compose up -d --wait db
docker compose exec -T db psql -U hotel -d hotels -c 'SELECT COUNT(*) FROM hotel_bookings;'
docker compose exec -T db psql -U hotel -d hotels < db/query.sql
./scripts/backup.sh
./scripts/restore.sh
./scripts/verify.sh
```

Expected: 250 hotel bookings, events for some bookings, a timestamped `backups/hotels_YYYYMMDDTHHMMSSZ.dump`, and `PASS: counts and total amount match`. Restore uses a separate `restore_db` service with its own volume and drops/recreates its database before importing. The original database is untouched. Migration files in `docker-entrypoint-initdb.d` run only on **first creation** of the source database volume. For a completely clean reset, `docker compose --profile restore down -v` **deletes all local data**.

### Index explanation

`idx_bookings_city_created_org_status` uses `(city, created_at DESC, org_id, status) INCLUDE (amount)`. `city` is an equality predicate, then `created_at` is a range predicate; included columns allow the planner to consider index-only scans for the aggregate. With only 250 rows, PostgreSQL may reasonably choose a sequential scan. Use `EXPLAIN (ANALYZE, BUFFERS)` in `db/query.sql` and compare at realistic scale before assuming the index improves latency. The events foreign-key lookup has its own `booking_id` index.

## Terraform checks (no AWS account needed)

```bash
terraform fmt -recursive infra
for env in dev prod; do
  (cd "infra/envs/$env" && terraform init -backend=false -input=false && terraform validate)
done
```

`init -backend=false` installs provider/modules but does not access the example S3 state backend. A true `terraform plan -refresh=false` still requires AWS credentials because the AWS provider and data sources access AWS APIs. `-refresh=false` only skips state refresh; it is **not** offline mode. No deployment or `apply` is needed.

## Real plan review (optional; AWS credentials required)

First create a secure S3 state bucket (outside this assessment) with versioning, encryption, least-privilege access, and use an appropriate backend lock configuration. Copy `backend.hcl.example` to `backend.hcl` for each environment and replace the bucket placeholder. With AWS credentials configured:

```bash
cd infra/envs/dev
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -refresh=false -out=tfplan
terraform show -no-color tfplan > plan.txt
```

Repeat for prod. Backend keys are separate (`hotel-assessment/dev/terraform.tfstate` and `hotel-assessment/prod/terraform.tfstate`). If a state bucket is not configured, you can instead run `terraform init -backend=false` followed by `terraform plan -refresh=false -lock=false` with valid AWS credentials to inspect a plan without configuring S3 state; do not use this as a shared team state workflow.

**Plan costs:** two NAT gateways per environment, ALB, Fargate and RDS incur charges if applied. No `apply` is part of this submission.

## Environment differences

| Setting | dev | prod |
|---|---|---|
| ECS CPU / memory | 256 / 512 MiB | 512 / 1024 MiB |
| ECS desired tasks | 1 | 2 |
| RDS class | db.t3.micro | db.t3.medium |
| Storage | 20 GiB | 100 GiB |
| RDS backups | 1 day | 14 days |
| Deletion protection | false | true |
| Multi-AZ RDS | false | true |

RDS has `publicly_accessible=false`, isolated DB subnet route tables, and port 5432 inbound only from the ECS security group. ECS is in private app subnets with NAT egress; ALB is public. The demo Nginx container does not actually connect to PostgreSQL. An application would need a DB client and securely retrieved credentials (e.g. Secrets Manager), not hardcoded secrets. Production improvements: HTTPS/ACM, WAF, VPC endpoints, container image digest pinning, IAM least privilege, ECS autoscaling, RDS monitoring, and multi-account separation.

## GitHub Actions

1. Create a GitHub repository and push these files to `main`.
2. Open a feature branch, make a small change, push it and create a pull request.
3. Under **Actions → Terraform and PostgreSQL checks**, inspect `terraform (dev)`, `terraform (prod)` and `database` jobs.
4. Both Terraform jobs run formatting, init without backend and validation. Database job starts PostgreSQL, runs SQL, backs up, restores and verifies counts.
5. **Optional real plans:** configure GitHub Actions repository secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (and `AWS_SESSION_TOKEN` for temporary credentials). Set repository variable `ENABLE_AWS_PLAN` to `true`. The plan step runs for dev and prod and uploads `terraform-plan-dev` and `terraform-plan-prod` text artifacts. Use short-lived OIDC credentials for production CI rather than long-lived keys. PRs from forks may not receive secrets. Plan output can contain sensitive values; restrict artifact access.
6. Expected result without AWS credentials: all jobs green; the optional plan steps are **skipped**, not reported as executed. With valid AWS credentials and plan enabled: plan output in logs and artifacts, no apply.

### Troubleshooting

- If port 5432 is occupied, change the host port in `compose.yaml` or stop the other local PostgreSQL instance.
- If seed data does not appear, the database volume may already exist; migration scripts run only on first initialization.
- `terraform plan` may fail with AWS permissions, invalid credentials, or unsupported regional instance/engine combinations; validate the chosen AWS region before any deployment.
- The S3 backend configuration is a template, not a pre-created bucket. Do not commit real secrets or state files.
