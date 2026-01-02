# Infrastructure Repo - LLM Context

## Overview
This repository manages local development infrastructure and cloud instances. It provides:
- **Headless WSL setup** - Fully automated dev environment creation from config file
- Local Kubernetes cluster (k3d) configuration
- Infrastructure services (PostgreSQL, MongoDB, Redis, Kafka)
- WSL development environment setup (dotfiles, tools, Claude Code)
- **Cloud instance management** - Hetzner servers via Tailscale mesh network

## Environment
- **OS**: Windows 11 + WSL2 (Debian)
- **No local admin rights** on Windows
- **Root access** in WSL
- **Shell**: ZSH with oh-my-zsh

## Key Tools
| Tool | Purpose | Location |
|------|---------|----------|
| claude | Claude Code CLI | `~/.claude/local/bin/claude` |
| gh | GitHub CLI | `/usr/bin/gh` |
| glab | GitLab CLI | `/usr/local/bin/glab` |
| tailscale | VPN/Mesh networking | `/usr/bin/tailscale` |
| mosh | Mobile shell (UDP) | `/usr/bin/mosh` |
| tmux | Terminal multiplexer | `/usr/bin/tmux` |
| k3d | Local k8s cluster | `/usr/local/bin/k3d` |
| kubectl | Kubernetes CLI | `/usr/local/bin/kubectl` |
| helm | Package manager for k8s | `~/.local/bin/helm` |
| k9s | Terminal UI for k8s | `~/.local/bin/k9s` |
| uv | Python package manager | `~/.local/bin/uv` |
| bun | JavaScript runtime | `~/.bun/bin/bun` |
| fnm | Node version manager | `~/.local/share/fnm` |

## Directory Structure
```
infrastructure/
├── CLAUDE.md                # This file - LLM context
├── README.md                # Quick start guide
├── Makefile                 # Cluster & service commands
├── k8s/
│   ├── cluster/             # k3d cluster configuration
│   │   └── k3d-config.yaml
│   ├── manifests/           # K8s manifests (official images)
│   │   ├── postgres.yaml    # PostgreSQL StatefulSet
│   │   ├── mongodb.yaml     # MongoDB StatefulSet
│   │   └── redis.yaml       # Redis Deployment
│   └── helm/                # Helm charts (Kafka only)
│       └── strimzi/         # Kafka via Strimzi Operator
├── dotfiles/
│   ├── zshrc                # Shell configuration
│   ├── gitconfig            # Git configuration
│   ├── claude/              # Claude Code settings
│   │   └── settings.json    # ccstatusline config
│   └── install.sh           # Dotfiles installer
├── scripts/
│   ├── bootstrap.sh         # Full WSL setup (15 steps)
│   ├── cluster-up.sh        # Smart cluster creation (+ Kafka recovery)
│   ├── kafka-recover.sh     # Fix Kafka after WSL restart
│   ├── install-helm.sh      # Helm-only installation
│   └── windows/             # PowerShell scripts for WSL management
│       ├── setup-wsl.ps1        # Headless WSL setup (main script)
│       ├── store-secrets.ps1    # Store tokens in Credential Manager
│       ├── remove-wsl.ps1       # Clean removal of WSL instance
│       └── create-test-wsl.ps1  # Quick test instance creation
├── config.example.json      # Template for headless setup config
├── volumes/
│   └── README.md            # Volume documentation
└── docs/
    ├── cloud/               # Cloud instance documentation
    │   └── HETZNER-N8N.md   # n8n server on Hetzner
    ├── HEADLESS-SETUP.md    # Automated setup guide
    ├── GITLAB-SETUP.md      # Git/GitLab configuration
    └── SETUP-NEW-MACHINE.md # Manual setup guide (interactive)
```

## Cluster Details
- **Cluster name**: `my-dev`
- **LoadBalancer**: Port 8080 mapped to host (auto-selects next free port if occupied)
- **Persistent volumes**: Mounted from `~/k3d-vol/{service}-data/`

## Common Commands

### Headless WSL Setup (PowerShell)
```powershell
# One-time: Store GitHub token securely
.\scripts\windows\store-secrets.ps1

# Create/recreate WSL instance (fully automated)
.\scripts\windows\setup-wsl.ps1 -ConfigFile .\config.json [-Force]

# Remove instance
.\scripts\windows\remove-wsl.ps1 -ConfigFile .\config.json
```

### Cluster Management (Bash/WSL)
```bash
make cluster-up          # Create/start cluster
make cluster-down        # Stop cluster
make cluster-reset       # Delete and recreate cluster

# Infrastructure services
make infra-up            # Deploy all services
make infra-down          # Remove all services
make infra-status        # Show pod/service status

# Individual services
make postgres-up         # Deploy PostgreSQL
make kafka-up            # Deploy Strimzi + Kafka
make kafka-recover       # Fix Kafka after WSL restart
```

## Git Aliases (pre-configured)
| Alias | Full Command |
|-------|--------------|
| `git st` | `git status` |
| `git co` | `git checkout` |
| `git br` | `git branch` |
| `git ci` | `git commit` |
| `git lg` | `git log --oneline --graph --decorate` |

## Volume Mounts
Services requiring persistence mount host directories:
- PostgreSQL: `~/k3d-vol/postgres-data`
- MongoDB: `~/k3d-vol/mongodb-data`
- Redis: `~/k3d-vol/redis-data`

These survive cluster resets.

## Cloud Instances

External servers accessible via Tailscale mesh network.

| Server | Tailscale Host | Provider | Purpose | URL |
|--------|----------------|----------|---------|-----|
| hetzner-n8n | `hetzner-n8n` | Hetzner Cloud | n8n Workflow Automation | https://n8n.internal.xr-ai.de |

### hetzner-n8n Details
- **OS**: Debian 13 (trixie)
- **Specs**: 2 vCPU, 4GB RAM, 40GB system + 10GB data disk
- **Public IP**: 88.198.224.219
- **Tailscale IP**: 100.81.212.93
- **Services**: n8n (Docker), Caddy (reverse proxy), Tailscale
- **Data**: `/mnt/data/n8n/` (external volume)
- **TLS**: Let's Encrypt via Caddy (auto-renewal)
- **Docs**: [docs/cloud/HETZNER-N8N.md](docs/cloud/HETZNER-N8N.md)

### SSH Access
```bash
ssh hetzner-n8n              # via Tailscale (preferred)
ssh root@88.198.224.219      # via public IP
```

## Important Notes for LLMs

### Local Development (k3d)
1. **Cluster can be reset anytime** - design for stateless deployments
2. **Host volumes persist** - data survives cluster deletion
3. **Official Docker images** for PostgreSQL, MongoDB, Redis - see k8s/manifests/
4. **Strimzi** for Kafka - uses Custom Resources, not plain Helm values
5. **No external ingress** - local development only, use port-forward or LoadBalancer
6. **Bootstrap script** installs everything from fresh Debian - 15 steps total
7. **Claude Code** is pre-configured with ccstatusline in `~/.claude/settings.json`
8. **Git credentials** stored via `git credential.helper store` in `~/.git-credentials`
9. **Image versions pinned** - postgres:17-alpine, mongo:8, redis:7-alpine, Strimzi 0.49.1
10. **Port conflict handling** - `make cluster-up` automatically finds free port if 8080 is occupied
11. **WSL interop aware** - Bootstrap script ignores Windows binaries in `/mnt/c/` and installs native Linux versions
12. **Headless setup available** - `setup-wsl.ps1` creates fully configured WSL instance from config file
13. **Secrets in Credential Manager** - GitHub/GitLab tokens stored encrypted via Windows DPAPI
14. **Kafka auto-recovery** - `cluster-up.sh` automatically fixes Kafka after WSL restart (KRaft cluster.id issue)

### Cloud Instances
15. **All cloud servers use Tailscale** - accessible via hostname from any Tailscale-connected device
16. **SSH config** - Cloud servers should be added to `~/.ssh/config` with Tailscale hostnames
17. **hetzner-n8n** - n8n data on external volume at `/mnt/data/`, TLS via Let's Encrypt, Caddy as reverse proxy
18. **Hetzner Firewall** - Remember to check both UFW and Hetzner Cloud Firewall for port access
