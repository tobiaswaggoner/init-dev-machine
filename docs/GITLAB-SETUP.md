# GitLab Setup Guide

## Creating a GitLab Personal Access Token

A Personal Access Token (PAT) is required for Git operations over HTTPS.

### Step 1: Navigate to Access Tokens

1. Log in to GitLab (e.g., `https://gitlab.com` or your company's GitLab instance)
2. Click your avatar (top right) → **Edit profile**
3. In the left sidebar, click **Access Tokens**

### Step 2: Create New Token

1. Click **Add new token**
2. Fill in the form:
   - **Token name**: `wsl-dev` (or any descriptive name)
   - **Expiration date**: Set according to your security policy (max 1 year)
   - **Scopes**: Select the following:
     - `read_repository` - Clone and pull
     - `write_repository` - Push changes
     - `read_api` (optional) - For GitLab CLI tools

3. Click **Create personal access token**
4. **IMPORTANT**: Copy the token immediately - it won't be shown again!

### Step 3: Store Token in Git Credential Helper

The bootstrap script configures Git to use the `store` credential helper. On first use, Git will prompt for credentials:

```bash
git clone https://gitlab.com/your-org/your-repo.git
# Username: your-gitlab-username
# Password: <paste your token here>
```

Credentials are stored in `~/.git-credentials` (plaintext, chmod 600).

### Alternative: SSH Key (Recommended for Long-term)

For a more secure setup, use SSH keys instead of HTTPS:

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy public key
cat ~/.ssh/id_ed25519.pub
```

1. Go to GitLab → **Edit profile** → **SSH Keys**
2. Paste your public key
3. Clone using SSH URL: `git clone git@gitlab.com:your-org/your-repo.git`

## Git Configuration

The bootstrap script sets up these helpful configurations:

### Aliases
| Alias | Command |
|-------|---------|
| `git st` | `git status` |
| `git co` | `git checkout` |
| `git br` | `git branch` |
| `git ci` | `git commit` |
| `git lg` | Pretty log with graph |
| `git last` | Show last commit |
| `git unstage` | Unstage files |

### Defaults
- Default branch: `main`
- Pull strategy: merge (not rebase)
- Auto setup remote tracking on push

## Setting User Identity

After bootstrap, set your Git identity:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

For company GitLab, you may want to use your work email.

## Multiple Git Identities

If you work with multiple GitLab instances (personal + work), use conditional includes:

```gitconfig
# ~/.gitconfig
[user]
    name = Your Name
    email = personal@email.com

[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig-work
```

```gitconfig
# ~/.gitconfig-work
[user]
    email = work@company.com
```

## Troubleshooting

### "Permission denied" on clone/push
- Check if token has correct scopes
- Token may have expired - create a new one
- Clear stored credentials: `rm ~/.git-credentials`

### "SSL certificate problem"
For self-signed GitLab instances:
```bash
git config --global http.sslVerify false  # Not recommended for production
# Or better: add the CA certificate
git config --global http.sslCAInfo /path/to/ca-bundle.crt
```

### Two-Factor Authentication
If 2FA is enabled, you MUST use a Personal Access Token (not your password) for HTTPS operations. SSH keys work regardless of 2FA.
