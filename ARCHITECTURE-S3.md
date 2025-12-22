# 🏗️ Hyperlane Architecture with AWS S3 - Complete Analysis

This document explains the complete architecture of the project using AWS S3, showing the data flow and why each component is necessary.

## 🎯 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    HYPERLANE VALIDATOR + RELAYER                │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────┐              ┌──────────────────────┐
│   VALIDATOR          │              │     RELAYER          │
│  (terraclassic)      │              │  (terra ↔ bsc)       │
├──────────────────────┤              ├──────────────────────┤
│                      │              │                      │
│  ┌────────────────┐  │              │  ┌────────────────┐  │
│  │ Configurations │  │              │  │ Configurations │  │
│  │ /etc/hyperlane │◄─┼─────┐        │  │ /etc/hyperlane │◄─┼─────┐
│  └────────────────┘  │     │        │  └────────────────┘  │     │
│                      │     │        │                      │     │
│  ┌────────────────┐  │     │        │  ┌────────────────┐  │     │
│  │ Database       │  │     │        │  │ Database       │  │     │
│  │ /etc/data/db   │◄─┼──┐  │        │  │ /etc/data/db   │◄─┼──┐  │
│  └────────────────┘  │  │  │        │  └────────────────┘  │  │  │
│                      │  │  │        │                      │  │  │
│  ┌────────────────┐  │  │  │        │  ┌────────────────┐  │  │  │
│  │ Checkpoints    │  │  │  │        │  │ Checkpoints    │  │  │  │
│  │   AWS S3 ☁️    │◄─┼──┼──┼────┐   │  │   AWS S3 ☁️    │◄─┼──┼──┼──┐
│  └────────────────┘  │  │  │    │   │  └────────────────┘  │  │  │  │
│         ▲            │  │  │    │   │         ▲            │  │  │  │
│         │ write      │  │  │    │   │         │ read       │  │  │  │
│         └────────────┼──┼──┼────┤   │         └────────────┼──┼──┼──┤
│                      │  │  │    │   │                      │  │  │  │
│  ┌────────────────┐  │  │  │    │   │  ┌────────────────┐  │  │  │  │
│  │ AWS KMS        │  │  │  │    │   │  │ AWS KMS        │  │  │  │  │
│  │ Signing Key    │◄─┼──┼──┼────┤   │  │ Signing Keys   │◄─┼──┼──┼──┤
│  └────────────────┘  │  │  │    │   │  └────────────────┘  │  │  │  │
│                      │  │  │    │   │                      │  │  │  │
└──────────────────────┘  │  │    │   └──────────────────────┘  │  │  │
                          │  │    │                              │  │  │
                          │  │    │                              │  │  │
                    [Volume] │    │                        [Volume] │  │
                 ./hyperlane │    │                     ./hyperlane │  │
                          │  │    │                              │  │  │
                    [Volume] │    │                        [Volume] │  │
                 ./validator │    │                      ./relayer  │  │
                             │    │                                 │  │
                             │    └─────────────────────────────────┘  │
                             │                                          │
                             │          [AWS S3 Bucket]                │
                             │  hyperlane-validator-signatures-...     │
                             └──────────────────────────────────────────┘
```

## 📊 Separation of Responsibilities

### 🔐 Validator (terraclassic)

**Function:** Sign checkpoints of messages from Terra Classic chain

**Stores:**
- ✅ **Configurations** → Local volume: `./hyperlane:/etc/hyperlane`
- ✅ **Database** → Local volume: `./validator:/etc/data`
- ✅ **Checkpoints** → AWS S3 (public bucket for reading)

**Does NOT need:**
- ❌ Access to relayer database
- ❌ Local volume for checkpoints (goes to S3)

**Configuration:**
```json
{
  "db": "/etc/data/db",                    // ← Volume: ./validator
  "checkpointSyncer": {
    "type": "s3",                          // ← Goes to S3
    "bucket": "hyperlane-validator-...",
    "region": "us-east-1"
  }
}
```

**Required volumes:**
```yaml
volumes:
  - ./hyperlane:/etc/hyperlane   # Config
  - ./validator:/etc/data        # Database
  # NO volume for checkpoints!
```

---

### 🔄 Relayer (terra ↔ bsc)

**Function:** Relay messages between Terra Classic and BSC

**Stores:**
- ✅ **Configurations** → Local volume: `./hyperlane:/etc/hyperlane`
- ✅ **Database** → Local volume: `./relayer:/etc/data`
- ✅ **Reads checkpoints** → AWS S3 (from validator)

**Does NOT need:**
- ❌ Access to validator database
- ❌ Volume for checkpoints (reads from S3)
- ❌ Volume `./validator` (doesn't make sense!)

**Configuration:**
```json
{
  "db": "/etc/data/db",                    // ← Volume: ./relayer
  "allowLocalCheckpointSyncers": "false",  // ← Reads from S3, not local
  "relayChains": "terraclassic,bsc"
}
```

**Required volumes:**
```yaml
volumes:
  - ./hyperlane:/etc/hyperlane   # Config
  - ./relayer:/etc/data          # Database
  # NO ./validator! Not needed!
```

---

## 🔄 Complete Data Flow

### Step 1: Message Sent on Terra Classic

```
Terra Classic
     ↓
Hyperlane Mailbox Contract
     ↓
Event emitted
     ↓
VALIDATOR detects event
     ↓
VALIDATOR creates checkpoint
     ↓
AWS KMS signs checkpoint
     ↓
✅ VALIDATOR writes to S3
```

### Step 2: Relayer Processes Message

```
✅ S3 Bucket (checkpoint available)
     ↓
RELAYER reads checkpoint from S3
     ↓
RELAYER verifies signature
     ↓
AWS KMS signs delivery transaction
     ↓
RELAYER sends to BSC
     ↓
Message delivered on BSC
```

## 📁 Correct Directory Structure

```
hyperlane-validator/
├── docker-compose.yml
├── .env                              # AWS Credentials
│
├── hyperlane/                        # Shared volume (read-only)
│   ├── agent-config.docker.json     # Chain configuration
│   ├── validator.terraclassic.json  # Validator config
│   └── relayer.json                 # Relayer config
│
├── validator/                        # EXCLUSIVE validator volume
│   └── db/                           # Validator database
│       ├── CURRENT
│       ├── LOCK
│       └── *.sst
│
└── relayer/                          # EXCLUSIVE relayer volume
    └── db/                           # Relayer database
        ├── CURRENT
        ├── LOCK
        └── *.sst

AWS S3 (remote):
└── hyperlane-validator-signatures-YOUR-NAME-terraclassic/
    ├── checkpoint_0x1234...json      # Written by validator
    ├── checkpoint_0x5678...json      # Read by relayer
    └── checkpoint_0xabcd...json
```

## ⚠️ INCORRECT Configurations (Avoid)

### ❌ Relayer with Validator Volume

```yaml
# WRONG!
relayer:
  volumes:
    - ./hyperlane:/etc/hyperlane
    - ./relayer:/etc/data
    - ./validator:/etc/validator    # ❌ WHY?!
```

**Problems:**
1. Relayer doesn't use validator data
2. Creates unnecessary coupling
3. Can cause access conflicts
4. Wastes resources

### ❌ Checkpoints in Local Volume

```yaml
# WRONG!
validator:
  volumes:
    - ./hyperlane:/etc/hyperlane
    - ./validator:/etc/data
    - ./validator/checkpoint:/etc/checkpoint  # ❌ Not needed!
```

**Problems:**
1. Checkpoints go to S3
2. Local volume wasted
3. Not available to other agents
4. No redundancy

### ❌ Shared Databases

```yaml
# WRONG!
validator:
  volumes:
    - ./data:/etc/data    # ❌ Shared

relayer:
  volumes:
    - ./data:/etc/data    # ❌ Same volume!
```

**Problems:**
1. Write conflicts
2. Data corruption
3. Lock issues
4. Impossible to debug

## ✅ CORRECT Final Configuration

### docker-compose.yml

```yaml
version: '2'
services:
  relayer:
    container_name: hpl-relayer
    image: gcr.io/abacus-labs-dev/hyperlane-agent:latest
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - AWS_REGION=${AWS_REGION:-us-east-1}
    volumes:
      - ./hyperlane:/etc/hyperlane    # ✅ Config (shared read-only)
      - ./relayer:/etc/data           # ✅ Own database
      # ✅ NO ./validator! Not needed!
      # ✅ Checkpoints read from S3

  validator-terraclassic:
    container_name: hpl-validator-terraclassic
    image: gcr.io/abacus-labs-dev/hyperlane-agent:latest
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - AWS_REGION=${AWS_REGION:-us-east-1}
    volumes:
      - ./hyperlane:/etc/hyperlane    # ✅ Config (shared read-only)
      - ./validator:/etc/data         # ✅ Own database
      # ✅ Checkpoints written to S3
```

## 🔐 AWS Authentication Flow

### Validator

```
Container validator-terraclassic
         ↓
AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
         ↓
AWS STS (verifies identity)
         ↓
IAM Policy (verifies permissions)
         ↓
├─→ AWS KMS (sign checkpoints)
│   └─→ hyperlane-validator-signer-terraclassic
│
└─→ AWS S3 (write checkpoints)
    └─→ PutObject in hyperlane-validator-signatures-...
```

### Relayer

```
Container hpl-relayer
         ↓
AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
         ↓
AWS STS (verifies identity)
         ↓
IAM Policy (verifies permissions)
         ↓
├─→ AWS KMS (sign transactions)
│   ├─→ hyperlane-relayer-signer-bsc
│   └─→ hyperlane-validator-signer-terraclassic
│
└─→ AWS S3 (read checkpoints)
    └─→ GetObject in hyperlane-validator-signatures-...
```

## 📊 Resource Usage Comparison

### With S3 (Current - Correct)

| Service | Volumes | Disk Usage | S3 Access |
|---------|---------|------------|-----------|
| Validator | 2 (config + db) | ~100 MB | Write |
| Relayer | 2 (config + db) | ~100 MB | Read |
| **Total** | **4 volumes** | **~200 MB** | ✅ |

### With localStorage (Old - Incorrect)

| Service | Volumes | Disk Usage | S3 Access |
|---------|---------|------------|-----------|
| Validator | 3 (config + db + checkpoint) | ~500 MB+ | None |
| Relayer | 3 (config + db + validator?!) | ~500 MB+ | None |
| **Total** | **6 volumes** | **~1 GB+** | ❌ |

**Savings with S3:**
- 🟢 33% fewer volumes
- 🟢 80% less disk usage
- 🟢 Checkpoints available globally
- 🟢 Automatic backup

## 🎯 Verification Checklist

Use this checklist to verify your configuration is correct:

### Validator

- [ ] Volume `./hyperlane:/etc/hyperlane` exists
- [ ] Volume `./validator:/etc/data` exists
- [ ] **NO** volume for `/etc/validator/checkpoint`
- [ ] Config has `"checkpointSyncer": { "type": "s3" }`
- [ ] Config has `"db": "/etc/data/db"`
- [ ] AWS variables configured
- [ ] S3 bucket exists and is accessible

### Relayer

- [ ] Volume `./hyperlane:/etc/hyperlane` exists
- [ ] Volume `./relayer:/etc/data` exists
- [ ] **NO** volume `./validator`
- [ ] Config has `"allowLocalCheckpointSyncers": "false"`
- [ ] Config has `"db": "/etc/data/db"`
- [ ] AWS variables configured
- [ ] Can read from validator's S3 bucket

### S3 Bucket

- [ ] Bucket created in correct region
- [ ] Policy allows public read
- [ ] Policy allows write only from IAM user
- [ ] Checkpoints appear after messages

## 🔧 Verification Commands

```bash
# 1. Check volume structure
docker inspect hpl-validator-terraclassic | jq '.[0].Mounts'
docker inspect hpl-relayer | jq '.[0].Mounts'

# Should show only 2 volumes each:
# - ./hyperlane:/etc/hyperlane
# - ./validator or ./relayer:/etc/data

# 2. Check configurations
cat hyperlane/validator.terraclassic.json | jq '.checkpointSyncer'
# Should show: {"type": "s3", "bucket": "...", "region": "..."}

cat hyperlane/relayer.json | jq '.allowLocalCheckpointSyncers'
# Should show: "false"

# 3. Check checkpoints in S3
aws s3 ls s3://hyperlane-validator-signatures-YOUR-NAME-terraclassic/ \
  --region us-east-1

# 4. Check logs
docker logs hpl-validator-terraclassic | grep -i "checkpoint"
docker logs hpl-relayer | grep -i "checkpoint"

# 5. Verify relayer does NOT have access to ./validator
docker exec hpl-relayer ls /etc/validator 2>&1
# Should give error: "No such file or directory" ✅
```

## 📚 Additional Resources

- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/best-practices.html)
- [Docker Volumes Guide](https://docs.docker.com/storage/volumes/)
- [Hyperlane Validator Setup](https://docs.hyperlane.xyz/docs/operate/validators/validator-signatures-aws)

---

**✅ Correct Architecture Summary:**

1. **Validator** = 2 volumes (config + database) + S3 write
2. **Relayer** = 2 volumes (config + database) + S3 read
3. **DO NOT** share volumes between services
4. **DO NOT** have volumes for checkpoints (they're in S3)
5. **YES** use AWS credentials for both services

🚀 **Clean, efficient, and scalable architecture!**

