#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_command() {
    echo -e "${YELLOW}# will run:${NC} $1"
}

# Validate required environment variables
if [ -z "$REPO_DIR" ]; then
    print_error "REPO_DIR environment variable is required"
    exit 1
fi

# Set defaults
REMOTE_NAME="${REMOTE_NAME:-origin}"
STRATEGY="${STRATEGY:-hard}"
PRUNE="${PRUNE:-false}"
FETCH_TAGS="${FETCH_TAGS:-false}"
GIT_SUBMODULES="${GIT_SUBMODULES:-false}"
FORCE_CLEAN="${FORCE_CLEAN:-true}"

# Validate STRATEGY
case "$STRATEGY" in
    hard|ff-only|rebase|stash)
        print_info "Using strategy: $STRATEGY"
        ;;
    *)
        print_error "Invalid STRATEGY: $STRATEGY. Must be one of: hard, ff-only, rebase, stash"
        exit 1
        ;;
esac

# Change to repository directory
cd "$REPO_DIR" || {
    print_error "Cannot change to directory: $REPO_DIR"
    exit 1
}

# Validate it's a git repository
if [ ! -d ".git" ]; then
    print_error "$REPO_DIR is not a git repository"
    exit 1
fi

print_info "Working in repository: $REPO_DIR"

# Fallback: handle "dubious ownership" errors.
# When the repo is a mounted volume owned by a different UID than the container
# user, git refuses to operate on it ("detected dubious ownership in repository").
# Mark the directory as safe so the git commands below can proceed.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_warn "Git reported dubious ownership for $REPO_DIR, adding safe.directory exception"
    print_command "git config --global --add safe.directory $REPO_DIR"
    git config --global --add safe.directory "$REPO_DIR"

    # Re-validate after applying the exception
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        print_error "Cannot access git repository at $REPO_DIR even after adding safe.directory exception"
        exit 1
    fi
    print_info "safe.directory exception applied"
fi

# Setup SSH authentication if private key is provided
if [ -n "$SSH_PRIVATE_KEY_FILE" ]; then
    print_info "Setting up SSH authentication"

    if [ ! -f "$SSH_PRIVATE_KEY_FILE" ]; then
        print_error "SSH_PRIVATE_KEY_FILE does not exist: $SSH_PRIVATE_KEY_FILE"
        exit 1
    fi

    # Setup SSH
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    # Copy private key
    cp "$SSH_PRIVATE_KEY_FILE" ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa

    # Setup known_hosts if available
    if [ -f "/etc/ssh/ssh_known_hosts" ]; then
        cp /etc/ssh/ssh_known_hosts ~/.ssh/known_hosts
        chmod 644 ~/.ssh/known_hosts
    elif [ -f "$HOME/.ssh/known_hosts" ]; then
        chmod 644 ~/.ssh/known_hosts
    fi

    export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    print_info "SSH authentication configured"
fi

# Setup HTTPS authentication via GIT_ASKPASS
if [ -n "$ASKPASS_TOKEN_FILE" ] || [ -n "$GIT_TOKEN" ]; then
    print_info "Setting up HTTPS authentication"

    # Create askpass script
    ASKPASS_SCRIPT="/tmp/git-askpass.sh"

    if [ -n "$ASKPASS_TOKEN_FILE" ]; then
        if [ ! -f "$ASKPASS_TOKEN_FILE" ]; then
            print_error "ASKPASS_TOKEN_FILE does not exist: $ASKPASS_TOKEN_FILE"
            exit 1
        fi
        cat > "$ASKPASS_SCRIPT" << 'ASKPASS_EOF'
#!/bin/sh
cat "$ASKPASS_TOKEN_FILE"
ASKPASS_EOF
    elif [ -n "$GIT_TOKEN" ]; then
        cat > "$ASKPASS_SCRIPT" << 'ASKPASS_EOF'
#!/bin/sh
echo "$GIT_TOKEN"
ASKPASS_EOF
    fi

    chmod +x "$ASKPASS_SCRIPT"
    export GIT_ASKPASS="$ASKPASS_SCRIPT"
    print_info "GIT_ASKPASS configured"
fi

# Get current branch if not specified
if [ -z "$BRANCH" ]; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    print_info "Using current branch: $BRANCH"
else
    print_info "Using specified branch: $BRANCH"
fi

# Build fetch command
FETCH_CMD="git fetch $REMOTE_NAME"

# Add depth if specified
if [ -n "$FETCH_DEPTH" ]; then
    FETCH_CMD="$FETCH_CMD --depth=$FETCH_DEPTH"
fi

# Add prune if enabled
if [ "$PRUNE" = "true" ]; then
    FETCH_CMD="$FETCH_CMD --prune"
fi

# Add tags if enabled
if [ "$FETCH_TAGS" = "true" ]; then
    FETCH_CMD="$FETCH_CMD --tags"
else
    FETCH_CMD="$FETCH_CMD --no-tags"
fi

# Print and execute fetch
print_command "$FETCH_CMD"
eval "$FETCH_CMD"

# Update based on strategy
print_info "Applying strategy: $STRATEGY"

case "$STRATEGY" in
    hard)
        print_warn "Overwriting all local tracked changes with $REMOTE_NAME/$BRANCH"
        print_command "git reset --hard $REMOTE_NAME/$BRANCH"
        git reset --hard "$REMOTE_NAME/$BRANCH"
        ;;

    ff-only)
        # Check if there are local changes and reset them
        if ! git diff-index --quiet HEAD --; then
            print_warn "Local changes detected, resetting before merge"
            print_command "git reset --hard HEAD"
            git reset --hard HEAD
        fi
        
        print_command "git merge --ff-only $REMOTE_NAME/$BRANCH"
        git merge --ff-only "$REMOTE_NAME/$BRANCH"
        ;;

    rebase)
        print_command "git rebase $REMOTE_NAME/$BRANCH"
        git rebase "$REMOTE_NAME/$BRANCH"
        ;;

    stash)
        # Check if there are local changes
        if ! git diff-index --quiet HEAD --; then
            print_info "Local changes detected, stashing"
            print_command "git stash push --include-untracked"
            git stash push --include-untracked

            print_command "git merge --ff-only $REMOTE_NAME/$BRANCH"
            git merge --ff-only "$REMOTE_NAME/$BRANCH"

            print_info "Attempting to apply stashed changes"
            print_command "git stash pop"
            if ! git stash pop; then
                print_warn "Could not automatically apply stashed changes. Resolve conflicts manually."
            fi
        else
            print_info "No local changes, performing fast-forward merge"
            print_command "git merge --ff-only $REMOTE_NAME/$BRANCH"
            git merge --ff-only "$REMOTE_NAME/$BRANCH"
        fi
        ;;
esac

# Remove untracked files/directories after hard reset if enabled
if [ "$STRATEGY" = "hard" ] && [ "$FORCE_CLEAN" = "true" ]; then
    print_warn "Removing untracked files and directories"
    print_command "git clean -fd"
    git clean -fd
fi

# Handle submodules if enabled
if [ "$GIT_SUBMODULES" = "true" ]; then
    print_info "Updating submodules"

    if [ -f ".gitmodules" ]; then
        print_command "git submodule sync --recursive"
        git submodule sync --recursive

        SUBMODULE_CMD="git submodule update --init --recursive --force"

        # Add depth if specified
        if [ -n "$FETCH_DEPTH" ]; then
            SUBMODULE_CMD="$SUBMODULE_CMD --depth=$FETCH_DEPTH"
        fi

        print_command "$SUBMODULE_CMD"
        eval "$SUBMODULE_CMD"

        if [ "$STRATEGY" = "hard" ] && [ "$FORCE_CLEAN" = "true" ]; then
            print_warn "Removing untracked files and directories inside submodules"
            print_command "git submodule foreach --recursive 'git reset --hard && git clean -fd'"
            git submodule foreach --recursive 'git reset --hard && git clean -fd'
        fi
    else
        print_info "No submodules found"
    fi
fi

# Change ownership if UID_GID is specified
if [ -n "$UID_GID" ]; then
    print_info "Changing ownership to $UID_GID"

    # This requires running as root initially
    if [ "$(id -u)" -eq 0 ]; then
        print_command "chown -R $UID_GID $REPO_DIR"
        chown -R "$UID_GID" "$REPO_DIR"
    else
        print_warn "Cannot change ownership: not running as root"
    fi
fi

print_info "Git update completed successfully"
