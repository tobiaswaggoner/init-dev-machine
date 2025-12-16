# Local Development Infrastructure

Local development infrastructure for WSL2/k3d environment.

## Quick Start

**New machine?** See [Complete Setup Guide](docs/SETUP-NEW-MACHINE.md)

**Already have the repo cloned?**
```bash
# 1. Run bootstrap (installs all tools)
./scripts/bootstrap.sh

# 2. Log out and back in (for docker group + zsh)

# 3. Start Docker and create cluster
sudo service docker start
make cluster-up

# 4. Deploy infrastructure services
make infra-up

# 5. Verify
kubectl get pods -A
```

## What Bootstrap Installs

The `bootstrap.sh` script sets up a complete dev environment from a fresh Debian WSL:

| Category | Tools |
|----------|-------|
| System | curl, wget, git, jq, htop, tree, vim, ... |
| Shell | ZSH + Oh My Zsh |
| Containers | Docker, Docker Compose |
| Kubernetes | kubectl, k3d, Helm, k9s |
| Python | uv |
| Node.js | fnm, bun |
| AI | Claude Code CLI (+ ccstatusline) |
| Git | Aliases, credential helper, gh + glab CLI |

## Services

| Service | Port | Credentials |
|---------|------|-------------|
| PostgreSQL | 5432 | postgres / postgres |
| MongoDB | 27017 | root / rootpassword |
| Redis | 6379 | (no auth) |
| Kafka | 9092 | (no auth) |

## Commands

### Cluster Management
```bash
make cluster-up      # Create cluster
make cluster-down    # Stop cluster
make cluster-reset   # Delete and recreate
make cluster-status  # Show status
```

### Infrastructure
```bash
make infra-up        # Deploy all services
make infra-down      # Remove all services
make infra-status    # Show service status
```

### Individual Services
```bash
make postgres-up     # Deploy PostgreSQL only
make postgres-down   # Remove PostgreSQL
# Same pattern for: mongodb, redis, kafka
```

### Port Forwarding
```bash
make port-forward-postgres  # Forward 5432
make port-forward-mongodb   # Forward 27017
make port-forward-redis     # Forward 6379
```

## Volumes

Persistent data is stored on the host under `~/k3d-vol/`:
- `postgres-data/` - PostgreSQL data
- `mongodb-data/` - MongoDB data
- `redis-data/` - Redis data (optional)

Data survives cluster resets.

## Dotfiles

To install shell configuration:
```bash
./dotfiles/install.sh
```

This sets up:
- `~/.zshrc` - Shell config (symlink)
- `~/.gitconfig` - Git config (symlink)
- `~/.claude/settings.json` - Claude Code + ccstatusline config (copy)

## Git Setup

After bootstrap, configure your identity:
```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

For GitLab token setup, see [docs/GITLAB-SETUP.md](docs/GITLAB-SETUP.md).

### Git Aliases (pre-configured)
| Alias | Command |
|-------|---------|
| `git st` | status |
| `git co` | checkout |
| `git br` | branch |
| `git ci` | commit |
| `git lg` | log --oneline --graph |

## Claude Code

After bootstrap, authenticate Claude Code:
```bash
claude
# Follow the authentication prompts
```

The ccstatusline is pre-configured in `~/.claude/settings.json`.

## Documentation

- [Headless Setup](docs/HEADLESS-SETUP.md) - Fully automated WSL setup (recommended)
- [New Machine Setup](docs/SETUP-NEW-MACHINE.md) - Interactive setup from fresh Windows 11
- [GitLab Setup](docs/GITLAB-SETUP.md) - Token creation, SSH keys
- [Volumes](volumes/README.md) - Persistent storage details
- [CLAUDE.md](CLAUDE.md) - LLM context for this repo
