export const meta = {
  name: 'workflows:remote:fix-merge',
  description: 'Dynamic-workflow rewrite of workflow:remote:fix-merge.md — retrieves PR info, ensures the local worktree exists, merges from target branch, resolves conflicts, fixes issues, and pushes to remote',
  whenToUse: 'Fix a pull request with merge conflicts: read the PR, merge target into source, resolve conflicts automatically, identify and fix post-merge issues, and push to remote',
  phases: [
    { title: 'PR Info' },
    { title: 'Setup' },
    { title: 'Merge' },
    { title: 'Review' },
    { title: 'Fix' },
    { title: 'Commit' },
  ],
}

// args: { repo, pr, portal, project, description }
// workingBranch/targetBranch are NOT passed directly — they're derived from the PR itself

const PR_INFO_SCHEMA = {
  type: 'object',
  properties: {
    sourceBranch: { type: 'string' },
    targetBranch: { type: 'string' },
    title: { type: 'string' },
  },
  required: ['sourceBranch', 'targetBranch'],
}

const CONFLICT_RESOLUTION_SCHEMA = {
  type: 'object',
  properties: {
    resolved: { type: 'boolean' },
  },
  required: ['resolved'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    issues: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          summary: { type: 'string' },
        },
        required: ['file', 'summary'],
      },
    },
  },
  required: ['issues'],
}

phase('PR Info')
const prInfo = await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:devops:pull-request --action read --portal ${args.portal} --project ${args.project} --repo ${args.repo} --pr ${args.pr}. Return the PR's source branch and target branch (and title if available) — these are the branches this workflow will merge and fix conflicts on.`,
  { agentType: 'zzaia-devops-specialist', schema: PR_INFO_SCHEMA, label: 'read-pr-info' }
)

const workingBranch = prInfo.sourceBranch
const targetBranch = prInfo.targetBranch

phase('Setup')
await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:workspace:repo --action new --repo ${args.repo} --branch ${workingBranch} --target-branch ${targetBranch}. This ensures the local worktree and working branch exist — it is safe to call even if they already exist.`,
  { agentType: 'zzaia-workspace-manager', label: 'ensure-workspace' }
)

phase('Merge')
await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:development:git --action pull --repo ${args.repo} --branch ${targetBranch}. Ensure the target branch is up to date with the remote.`,
  { agentType: 'zzaia-workspace-manager', label: 'pull-target-branch' }
)

await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:development:git --action merge --repo ${args.repo} --branch ${workingBranch} --source-branch ${targetBranch}. Perform the merge operation.`,
  { agentType: 'zzaia-workspace-manager', label: 'merge-target-into-working' }
)

const conflictResolution = await agent(
  `Resolve all merge conflicts in the "${workingBranch}" branch of repo "${args.repo}". Use context: "${args.description || 'No additional context provided'}". MANDATORY: After resolving each conflict, verify no unresolved conflicts remain by inspecting the working directory. Return {resolved: true} if all conflicts are resolved successfully.`,
  { agentType: 'zzaia-developer-specialist', schema: CONFLICT_RESOLUTION_SCHEMA, label: 'resolve-merge-conflicts' }
)

phase('Review')
const review = await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:development:review --target repo --repo ${args.repo} --branch ${workingBranch} --context "verification of merged related files". Focus only on issues in files involved in the merge. Return issues array with file and summary for each finding.`,
  { agentType: 'zzaia-workspace-manager', schema: REVIEW_SCHEMA, label: 'review-post-merge' }
)

log(`Review complete: ${review.issues.length} issues found. NOTE: dynamic workflows run non-interactively — there is no manual confirmation gate here. This script always proceeds automatically to fix all identified issues.`)

phase('Fix')
await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:development:develop --task "Fix post-merge issues: ${JSON.stringify(review.issues)}" --repo ${args.repo} --branch ${workingBranch}. Systematically address all identified issues.`,
  { agentType: 'zzaia-developer-specialist', label: 'fix-post-merge-issues' }
)

const reReview = await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:development:review --target repo --repo ${args.repo} --branch ${workingBranch} --context "verify post-merge fixes". Return issues array with file and summary for any remaining issues.`,
  { agentType: 'zzaia-workspace-manager', schema: REVIEW_SCHEMA, label: 'verify-fixes' }
)

phase('Commit')
await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:development:git --action commit-push --repo ${args.repo} --branch ${workingBranch} --message "fix: resolve post-merge issues". Commit all changes and push to remote branch.`,
  { agentType: 'zzaia-workspace-manager', label: 'commit-and-push' }
)

return {
  pr: prInfo,
  workingBranch,
  targetBranch,
  conflictsResolved: conflictResolution.resolved,
  issuesFound: review.issues,
  verificationReview: reReview.issues,
}
