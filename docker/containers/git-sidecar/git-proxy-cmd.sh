#!/bin/sh
set -eu

# Only allow git-upload-pack (fetch) and git-receive-pack (push)
case "$SSH_ORIGINAL_COMMAND" in
    git-upload-pack*|git-receive-pack*)
        ;;
    *)
        echo "Command not allowed: $SSH_ORIGINAL_COMMAND" >&2
        exit 1
        ;;
esac

# Extract command and path from SSH_ORIGINAL_COMMAND
cmd=$(echo "$SSH_ORIGINAL_COMMAND" | cut -d' ' -f1)
path=$(echo "$SSH_ORIGINAL_COMMAND" | cut -d"'" -f2)

# Route based on path prefix
case "$path" in
    github/*)
        # Extract org/repo from path
        repo=$(echo "$path" | sed 's|^github/||')
        ssh -i /home/git/.ssh/id_rsa_github -o StrictHostKeyChecking=no \
            git@github.com "$cmd '$repo.git'"
        ;;
    ado/*)
        # Extract org/project/_git/repo from path
        repo=$(echo "$path" | sed 's|^ado/||')
        ssh -i /home/git/.ssh/id_rsa_ado -o StrictHostKeyChecking=no \
            git@ssh.dev.azure.com "$cmd 'v3/$repo'"
        ;;
    *)
        echo "Invalid path prefix: $path (expected github/ or ado/)" >&2
        exit 1
        ;;
esac
