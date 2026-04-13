# 🐘 PostgreSQL on EC2 — General Purpose Container

A production-ready, Dockerized PostgreSQL 16 server designed to run on an EC2 instance and serve **any of your projects** from a single, centralized database server.

---

## 📁 Project Structure

```
.
├── Dockerfile                    # Custom PostgreSQL 16 Alpine image
├── docker-compose.yml            # Orchestration (DB + optional PgAdmin + Exporter)
├── .env.example                  # Environment variable template
├── config/
│   ├── postgresql.conf           # Tuned server configuration
│   └── pg_hba.conf               # Client authentication rules
├── init-scripts/
│   ├── 01-extensions.sh          # Install common extensions (uuid, pgcrypto, etc.)
│   ├── 02-roles.sh               # Create reusable app roles
│   └── 03-functions.sql          # Utility functions (auto-timestamps, short IDs)
├── scripts/
│   ├── ec2-setup.sh              # One-command EC2 bootstrap
│   ├── backup.sh                 # Compressed backup with retention
│   ├── restore.sh                # Interactive restore from backup
│   ├── create-project-db.sh      # Spin up a new project database
│   └── health-check.sh           # Full status report
└── backups/                      # Backup storage (gitignored)
```

---

## 🚀 Quick Start

### 1. Launch an EC2 Instance

- **Recommended**: `t3.medium` (2 vCPU, 4 GB RAM) or larger
- **OS**: Amazon Linux 2023 or Ubuntu 22.04+
- **Storage**: 20+ GB EBS (gp3 recommended)
- **Security Group**: Open port `5432` to your application IPs only

### 2. Clone & Bootstrap

```bash
# SSH into your EC2 instance
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>

# Clone this repo
git clone <your-repo-url> postgres-server
cd postgres-server

# Run the setup script (installs Docker + Docker Compose)
sudo ./scripts/ec2-setup.sh
```

### 3. Configure

```bash
# Edit the environment file
nano .env

# At minimum, change these:
# POSTGRES_PASSWORD=<a-strong-password>
# POSTGRES_USER=admin
# POSTGRES_DB=app_db
```

### 4. Start the Server

```bash
# Start PostgreSQL
docker compose up -d

# Verify it's running
docker compose ps
./scripts/health-check.sh
```

---

## 🔌 Connecting From Your Projects

Use this connection string in any of your applications:

```
postgresql://<POSTGRES_USER>:<POSTGRES_PASSWORD>@<EC2_PUBLIC_IP>:5432/<DATABASE_NAME>
```

### Create a Dedicated Database Per Project

```bash
# Creates a new DB with its own user and permissions
./scripts/create-project-db.sh my_awesome_project

# Output will include the connection string — save it!
```

### Example: Python (SQLAlchemy)

```python
from sqlalchemy import create_engine
engine = create_engine("postgresql://my_project_user:password@ec2-ip:5432/my_project")
```

### Example: Node.js (pg)

```javascript
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://my_project_user:password@ec2-ip:5432/my_project'
});
```

---

## 🛡️ Security Best Practices

| Layer | Recommendation |
|-------|---------------|
| **EC2 Security Group** | Only allow port 5432 from your app's IP/VPC |
| **Password** | Use a strong, unique password (32+ chars) |
| **Authentication** | `scram-sha-256` is enforced (most secure method) |
| **SSL** | Enable SSL for production (see below) |
| **Roles** | Use `app_readonly` / `app_readwrite` roles, never the superuser |

### Enable SSL (Recommended for Production)

```bash
# Generate a self-signed certificate (or use a real one)
openssl req -new -x509 -days 365 -nodes \
    -out config/server.crt -keyout config/server.key \
    -subj "/CN=postgres-server"

# Add to postgresql.conf:
# ssl = on
# ssl_cert_file = '/etc/postgresql/server.crt'
# ssl_key_file = '/etc/postgresql/server.key'
```

---

## 💾 Backup & Restore

```bash
# Manual backup
./scripts/backup.sh

# Backup a specific database
./scripts/backup.sh my_project_db

# Restore from backup
./scripts/restore.sh backups/app_db_20260413_020000.sql.gz

# Automate daily backups via cron
crontab -e
# Add: 0 2 * * * cd /home/ec2-user/postgres-server && ./scripts/backup.sh >> logs/backup.log 2>&1
```

---

## 📊 Optional Add-ons

### PgAdmin (Web UI)

```bash
docker compose --profile admin up -d
# Access at http://<EC2_IP>:5050
```

### Prometheus Exporter (Monitoring)

```bash
docker compose --profile monitoring up -d
# Metrics at http://<EC2_IP>:9187/metrics
```

---

## 🔧 Tuning for Your EC2 Instance

The default `postgresql.conf` is tuned for a 4 GB RAM instance. Adjust these for your instance size:

| Setting | 2 GB RAM | 4 GB RAM | 8 GB RAM | 16 GB RAM |
|---------|----------|----------|----------|-----------|
| `shared_buffers` | 512MB | 1GB | 2GB | 4GB |
| `effective_cache_size` | 1.5GB | 3GB | 6GB | 12GB |
| `work_mem` | 8MB | 16MB | 32MB | 64MB |
| `maintenance_work_mem` | 128MB | 256MB | 512MB | 1GB |
| `max_connections` | 100 | 200 | 300 | 400 |

After editing `config/postgresql.conf`, restart:

```bash
docker compose restart db
```

---

## 📋 Pre-installed Extensions

| Extension | Purpose |
|-----------|---------|
| `uuid-ossp` | UUID generation |
| `pgcrypto` | Cryptographic functions |
| `pg_trgm` | Trigram-based text similarity & search |
| `unaccent` | Remove accents from text |
| `pg_stat_statements` | Query performance statistics |

---

## 📋 Utility Functions

These are available in every database created through the init scripts:

| Function | Usage |
|----------|-------|
| `trigger_set_updated_at()` | Trigger to auto-update `updated_at` columns |
| `create_updated_at_trigger('table')` | One-liner to add the trigger to any table |
| `generate_short_id(length)` | Generate URL-safe random IDs |

---

## 🆘 Troubleshooting

```bash
# View container logs
docker compose logs -f db

# Connect to psql shell
docker compose exec db psql -U admin -d app_db

# Check disk space
df -h

# Full health report
./scripts/health-check.sh
```

---

## License

MIT
