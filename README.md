# 🐘 PostgreSQL on EC2 — General Purpose Container

A production-ready, Dockerized PostgreSQL 16 server designed to run on an EC2 instance and serve **any of your projects** from a single, centralized database server.

---

## 📁 Project Structure

```
.
├── Dockerfile                    # Custom PostgreSQL 16 Alpine image
├── docker-compose.yml            # Orchestration (local build)
├── docker-compose.hub.yml        # Orchestration (pull from Docker Hub)
├── .env.example                  # Environment variable template
├── config/
│   ├── postgresql.conf           # Tuned server configuration
│   └── pg_hba.conf               # Client authentication rules
├── init-scripts/
│   ├── 01-extensions.sh          # Install common extensions (uuid, pgcrypto, etc.)
│   ├── 02-roles.sh               # Create reusable app roles
│   └── 03-functions.sql          # Utility functions (auto-timestamps, short IDs)
├── scripts/
│   ├── build-and-push.sh         # Build image & push to Docker Hub
│   ├── ec2-deploy.sh             # One-command EC2 deploy (pulls from Hub)
│   ├── ec2-setup.sh              # EC2 bootstrap (git clone method)
│   ├── backup.sh                 # Compressed backup with retention
│   ├── restore.sh                # Interactive restore from backup
│   ├── create-project-db.sh      # Spin up a new project database
│   └── health-check.sh           # Full status report
└── backups/                      # Backup storage (gitignored)
```

---

## 🚀 Quick Start

### 1. Launch an EC2 Instance

- **Instance Type**: `c7i-flex.large` (2 vCPU Intel Xeon, 4 GB RAM)
- **OS**: Amazon Linux 2023
- **Storage**: 20+ GB EBS (gp3 recommended)
- **Security Group**: Open port `5432` (PostgreSQL) and `6432` (PgBouncer) to your application IPs only

---

## 🐳 Deployment Method: Docker Hub (Recommended)

Build the image on your local machine, push to Docker Hub, then pull on EC2. **No need to clone the repo on EC2!**

### Step 1: Build & Push (on your local machine)

```bash
# Login to Docker Hub
docker login

# Build and push the image
bash scripts/build-and-push.sh

# Or push with a version tag
bash scripts/build-and-push.sh v1.0
```

This pushes to: `kaushaljainai/postgres-ec2:latest`

### Step 2: Prepare Production Environment (On EC2)

Connect to your EC2 instance and ensure Docker is installed.

```bash
# SSH into your EC2 instance
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>

# Create deployment directory
mkdir -p ~/postgres-server
cd ~/postgres-server
```

*(If Docker isn't installed on your EC2 instance yet, install it using the steps provided in the standard install guide for Amazon Linux).*

### Step 3: Copy Configuration to EC2

From your local machine (in a new terminal), copy the configured `.env` and the modified Docker Hub configuration to your EC2 instance:

```bash
# Copy your configured .env file
scp -i your-key.pem .env ec2-user@<EC2_PUBLIC_IP>:~/postgres-server/.env

# Copy the hub-specific docker compose file
scp -i your-key.pem docker-compose.hub.yml ec2-user@<EC2_PUBLIC_IP>:~/postgres-server/docker-compose.yml
```

### Step 4: Configure & Start

SSH back into your EC2 instance, navigate to the directory, and start the containers.

```bash
# Start everything
cd ~/postgres-server
sudo docker compose pull
sudo docker compose up -d

# Verify
sudo docker compose ps
```

### Updating the Image

When you make changes to the Dockerfile or config:

```bash
# On your local machine: rebuild & push
bash scripts/build-and-push.sh v1.1

# On EC2: pull the new image & restart
cd ~/postgres-server
sudo docker compose pull
sudo docker compose up -d
```

---

## 📦 Alternative: Git Clone Method

<details>
<summary>Click to expand (if you prefer cloning the repo on EC2)</summary>

### Clone & Bootstrap

```bash
# SSH into your EC2 instance
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>

# Clone this repo
git clone <your-repo-url> postgres-server
cd postgres-server

# Run the setup script (installs Docker + Docker Compose)
sudo ./scripts/ec2-setup.sh
```

### Configure

```bash
# Edit the environment file
nano .env

# At minimum, change these:
# POSTGRES_PASSWORD=<a-strong-password>
# POSTGRES_USER=admin
# POSTGRES_DB=app_db
```

### Start the Server

```bash
# Start PostgreSQL (builds locally)
docker compose up -d

# Verify it's running
docker compose ps
./scripts/health-check.sh
```

</details>

---

## 🔌 Connecting From Your Projects

### Via PgBouncer (Recommended — Connection Pooling)

Connect through PgBouncer on port **6432** for connection pooling. This reuses database connections, drastically reducing memory usage under load.

```
postgresql://<POSTGRES_USER>:<POSTGRES_PASSWORD>@<EC2_PUBLIC_IP>:6432/<DATABASE_NAME>
```

### Direct Connection (Bypass Pooler)

For admin tasks or when you need session-level features (e.g., `LISTEN/NOTIFY`, temp tables):

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
# Use port 6432 for connection pooling via PgBouncer
engine = create_engine("postgresql://my_project_user:password@ec2-ip:6432/my_project")
```

### Example: Node.js (pg)

```javascript
const { Pool } = require('pg');
const pool = new Pool({
  // Use port 6432 for connection pooling via PgBouncer
  connectionString: 'postgresql://my_project_user:password@ec2-ip:6432/my_project'
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

Backups use **parallel directory-format dumps** for faster backup and restore.

```bash
# Manual backup (parallel, compressed)
./scripts/backup.sh

# Backup a specific database
./scripts/backup.sh my_project_db

# Restore from backup (parallel restore)
./scripts/restore.sh backups/app_db_20260413_020000

# Legacy .sql.gz backups are also supported
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

## ⚡ Performance Monitoring

### Query Statistics (pg_stat_statements)

`pg_stat_statements` is pre-configured to track all query performance. Use it to find slow queries:

```sql
-- Top 10 slowest queries by total execution time
SELECT query, calls, total_exec_time, mean_exec_time, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Reset stats (do this periodically)
SELECT pg_stat_statements_reset();
```

### Connection Pool Stats (PgBouncer)

```bash
# Connect to PgBouncer admin console
docker compose exec pgbouncer psql -p 5432 -U admin pgbouncer

# Show pool stats
SHOW POOLS;
SHOW STATS;
SHOW CLIENTS;
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
