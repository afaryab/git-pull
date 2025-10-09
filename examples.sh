#!/bin/bash
# Example script showing how to use the git-pull Docker image

# Build the image
echo "Building the git-pull Docker image..."
docker build -t git-pull .

echo ""
echo "===== Example Usage ====="
echo ""

# Example 1: Basic usage
echo "1. Basic usage (fast-forward only):"
echo "   docker run --rm -v /path/to/repo:/work -e REPO_DIR=/work git-pull"
echo ""

# Example 2: With HTTPS authentication
echo "2. With HTTPS authentication using a token file:"
echo "   docker run --rm \\"
echo "     -v /path/to/repo:/work \\"
echo "     -v /path/to/token-file:/token:ro \\"
echo "     -e REPO_DIR=/work \\"
echo "     -e ASKPASS_TOKEN_FILE=/token \\"
echo "     git-pull"
echo ""

# Example 3: With SSH authentication
echo "3. With SSH authentication:"
echo "   docker run --rm \\"
echo "     -v /path/to/repo:/work \\"
echo "     -v ~/.ssh/id_rsa:/ssh-key:ro \\"
echo "     -v ~/.ssh/known_hosts:/etc/ssh/ssh_known_hosts:ro \\"
echo "     -e REPO_DIR=/work \\"
echo "     -e SSH_PRIVATE_KEY_FILE=/ssh-key \\"
echo "     git-pull"
echo ""

# Example 4: Hard reset strategy
echo "4. Hard reset to remote (discards local changes):"
echo "   docker run --rm -v /path/to/repo:/work -e REPO_DIR=/work -e STRATEGY=hard git-pull"
echo ""

# Example 5: Rebase strategy
echo "5. Rebase on remote branch:"
echo "   docker run --rm -v /path/to/repo:/work -e REPO_DIR=/work -e STRATEGY=rebase git-pull"
echo ""

# Example 6: Stash strategy
echo "6. Stash local changes before pulling:"
echo "   docker run --rm -v /path/to/repo:/work -e REPO_DIR=/work -e STRATEGY=stash git-pull"
echo ""

# Example 7: With submodules
echo "7. Update repository with submodules:"
echo "   docker run --rm -v /path/to/repo:/work -e REPO_DIR=/work -e GIT_SUBMODULES=true git-pull"
echo ""

# Example 8: Advanced options
echo "8. Advanced: Shallow fetch with pruning and specific branch:"
echo "   docker run --rm \\"
echo "     -v /path/to/repo:/work \\"
echo "     -e REPO_DIR=/work \\"
echo "     -e BRANCH=main \\"
echo "     -e FETCH_DEPTH=1 \\"
echo "     -e PRUNE=true \\"
echo "     -e FETCH_TAGS=false \\"
echo "     git-pull"
echo ""

# Example 9: With ownership change
echo "9. Change ownership after pull (requires running as root):"
echo "   docker run --rm \\"
echo "     --user root \\"
echo "     -v /path/to/repo:/work \\"
echo "     -e REPO_DIR=/work \\"
echo "     -e UID_GID=1000:1000 \\"
echo "     git-pull"
echo ""

echo "===== Environment Variables ====="
echo ""
echo "Required:"
echo "  REPO_DIR - Directory path of the git repository"
echo ""
echo "Optional:"
echo "  REMOTE_NAME - Remote name (default: origin)"
echo "  BRANCH - Branch name (default: current branch)"
echo "  STRATEGY - ff-only|rebase|hard|stash (default: ff-only)"
echo "  FETCH_DEPTH - Limit fetch depth for large repos"
echo "  PRUNE - Prune remote-tracking branches (default: false)"
echo "  FETCH_TAGS - Fetch tags (default: false)"
echo "  GIT_SUBMODULES - Update submodules (default: false)"
echo "  UID_GID - Change ownership to UID:GID (requires root)"
echo ""
echo "Authentication:"
echo "  GIT_TOKEN - Git token for HTTPS"
echo "  ASKPASS_TOKEN_FILE - Path to token file for HTTPS"
echo "  SSH_PRIVATE_KEY_FILE - Path to SSH private key"
echo ""
