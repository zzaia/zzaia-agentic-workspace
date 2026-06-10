#!/bin/bash
set -e

WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
NEO4J_URI="${NEO4J_URI:-bolt://database-neo4j:7687}"
NEO4J_USERNAME="${NEO4J_USERNAME:-neo4j}"
NEO4J_PASSWORD="${NEO4J_PASSWORD:-zzaia1234}"
CGC_PORT="${CGC_PORT:-8000}"
CGC_HOST="${CGC_HOST:-0.0.0.0}"

echo "CodeGraphContext MCP Container — Starting"
echo "Workspace: $WORKSPACE_PATH"
echo "Neo4j URI: $NEO4J_URI"

# Index all worktree repositories
if [ -d "$WORKSPACE_PATH" ]; then
    echo "Discovering repository directories..."
    find "$WORKSPACE_PATH" -maxdepth 2 -name ".worktrees" -type d | while read worktree_dir; do
        echo "Found worktree: $worktree_dir"

        # Index each branch directory in the worktree
        for branch_dir in "$worktree_dir"/*; do
            if [ -d "$branch_dir" ] && [ -f "$branch_dir/.git" ]; then
                echo "Indexing: $branch_dir"
                cgc index "$branch_dir" 2>&1 || echo "Warning: Failed to index $branch_dir"
            fi
        done
    done
    echo "Repository indexing complete"
else
    echo "Workspace directory not found at $WORKSPACE_PATH"
fi

echo "Starting CGC API server..."
exec cgc api start --port "$CGC_PORT" --host "$CGC_HOST"
