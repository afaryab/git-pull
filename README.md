# git-pull

A minimal Alpine-based Docker image for updating a cloned git repository with various strategies and authentication methods.

## Features

- **Multiple Update Strategies**: Fast-forward only, rebase, hard reset, or stash
- **Flexible Authentication**: Support for both HTTPS (via GIT_ASKPASS) and SSH
- **Submodule Support**: Optional recursive submodule updates
- **Security**: Runs as non-root user, no secrets in logs
- **Customizable**: Configurable fetch depth, pruning, and tags
- **Ownership Management**: Optional UID/GID configuration

## Environment Variables

### Required
- `REPO_DIR`: Directory path of the git repository (required)

### Optional
- `REMOTE_NAME`: Remote name to fetch from (default: `origin`)
- `BRANCH`: Branch name to update (default: current branch)
- `STRATEGY`: Update strategy (default: `ff-only`)
  - `ff-only`: Fast-forward only merge (resets local changes if present)
  - `rebase`: Rebase on remote branch
  - `hard`: Hard reset to remote branch
  - `stash`: Stash local changes, merge, and pop stash
- `FETCH_DEPTH`: Limit fetch depth (useful for large repositories)
- `PRUNE`: Prune remote-tracking branches (default: `false`)
- `FETCH_TAGS`: Fetch tags from remote (default: `false`)
- `GIT_SUBMODULES`: Update submodules recursively (default: `false`)
- `UID_GID`: Change ownership to specified UID:GID (requires root)

### Authentication (HTTPS)
- `GIT_TOKEN`: Git token for HTTPS authentication
- `ASKPASS_TOKEN_FILE`: Path to file containing the git token

### Authentication (SSH)
- `SSH_PRIVATE_KEY_FILE`: Path to SSH private key file
- Known hosts should be mounted at `/etc/ssh/ssh_known_hosts` or `~/.ssh/known_hosts`

## Usage Examples

### Basic Usage (Fast-forward only)
```bash
docker run --rm \
  -v /path/to/repo:/work \
  -e REPO_DIR=/work \
  git-pull
```

### With HTTPS Authentication
```bash
docker run --rm \
  -v /path/to/repo:/work \
  -v /path/to/token:/token:ro \
  -e REPO_DIR=/work \
  -e ASKPASS_TOKEN_FILE=/token \
  git-pull
```

### With SSH Authentication
```bash
docker run --rm \
  -v /path/to/repo:/work \
  -v ~/.ssh/id_rsa:/ssh-key:ro \
  -v ~/.ssh/known_hosts:/etc/ssh/ssh_known_hosts:ro \
  -e REPO_DIR=/work \
  -e SSH_PRIVATE_KEY_FILE=/ssh-key \
  git-pull
```

### Hard Reset Strategy
```bash
docker run --rm \
  -v /path/to/repo:/work \
  -e REPO_DIR=/work \
  -e STRATEGY=hard \
  git-pull
```

### With Submodules
```bash
docker run --rm \
  -v /path/to/repo:/work \
  -e REPO_DIR=/work \
  -e GIT_SUBMODULES=true \
  git-pull
```

### Rebase with Specific Branch
```bash
docker run --rm \
  -v /path/to/repo:/work \
  -e REPO_DIR=/work \
  -e BRANCH=main \
  -e STRATEGY=rebase \
  git-pull
```

### With Ownership Change (requires running as root)
```bash
docker run --rm \
  -v /path/to/repo:/work \
  -e REPO_DIR=/work \
  -e UID_GID=1000:1000 \
  --user root \
  git-pull
```

### Advanced: Shallow Clone Update with Pruning
```bash
docker run --rm \
  -v /path/to/repo:/work \
  -e REPO_DIR=/work \
  -e FETCH_DEPTH=1 \
  -e PRUNE=true \
  -e FETCH_TAGS=false \
  git-pull
```

## Building the Image

```bash
docker build -t git-pull .
```

## Security Considerations

- The entrypoint script never prints secrets or tokens
- Runs as non-root user by default (UID 1000)
- SSH keys and tokens should be mounted read-only
- Commands are printed before execution for transparency

## Output

The script prints:
- `[INFO]` messages for general information
- `[WARN]` messages for warnings
- `[ERROR]` messages for errors
- `# will run:` prefix for commands before execution

Example output:
```
[INFO] Using strategy: ff-only
[INFO] Working in repository: /work
[INFO] Using current branch: main
# will run: git fetch origin --no-tags
# will run: git merge --ff-only origin/main
[INFO] Git pull completed successfully
```