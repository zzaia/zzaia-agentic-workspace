export const meta = {
  name: 'workflows:remote:homologate',
  description: 'Orchestrate homologation testing with live-URL BDD execution, diagnostics, and bug reporting via Azure DevOps work items',
  whenToUse: 'QA validation of a work item against a live URL using an existing Test Case with BDD scenarios, collecting diagnostics and creating bugs for approved failures',
  phases: [
    { title: 'Work Item' },
    { title: 'Context' },
    { title: 'Execute Tests' },
    { title: 'Correlate' },
    { title: 'Report' },
    { title: 'Bug Approval' },
    { title: 'Bugs' },
  ],
}

// args: { workItem, project, url, application, type, testCase, description?, doc?, debugSources?, sourceMetadata?, refUrl? }

const WORK_ITEM_SCHEMA = {
  type: 'object',
  properties: {
    workItem: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        description: { type: 'string' },
        acceptanceCriteria: { type: 'array', items: { type: 'string' } },
      },
      required: ['title', 'description', 'acceptanceCriteria'],
    },
    testCase: {
      type: 'object',
      properties: {
        steps: { type: 'array', items: { type: 'string' } },
      },
      required: ['steps'],
    },
  },
  required: ['workItem', 'testCase'],
}

const STEP_RESULT_SCHEMA = {
  type: 'object',
  properties: {
    step: { type: 'string' },
    passed: { type: 'boolean' },
    responseTimeMs: { type: 'number' },
    anomalies: { type: 'array', items: { type: 'string' } },
  },
  required: ['step', 'passed'],
}

const REPORT_SCHEMA = {
  type: 'object',
  properties: {
    posted: { type: 'boolean' },
  },
  required: ['posted'],
}

const BUG_APPROVAL_SCHEMA = {
  type: 'object',
  properties: {
    approvedBugs: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          repo: { type: 'string' },
          stepsToReproduce: { type: 'string' },
          severity: { type: 'string' },
        },
        required: ['title', 'repo', 'stepsToReproduce', 'severity'],
      },
    },
    dismissed: { type: 'array', items: { type: 'string' } },
  },
  required: ['approvedBugs', 'dismissed'],
}

const BUG_CREATION_SCHEMA = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    url: { type: 'string' },
  },
  required: ['id'],
}

phase('Work Item')
const workItemData = await agent(
  `Invoke the SlashCommand tool twice: first /behavior:devops:work-item --action read --id ${args.workItem} --project ${args.project}, then /behavior:devops:work-item --action read --id ${args.testCase} --project ${args.project}. Return work item (title, full description, acceptance criteria list) and Test Case (ordered list of BDD steps). MANDATORY: work item description must not be empty — fail if it is. Both operations are read-only; do NOT update, comment on, or write to either work item.`,
  { agentType: 'zzaia-devops-specialist', schema: WORK_ITEM_SCHEMA, label: 'work-item-load' }
)
const { workItem, testCase } = workItemData

phase('Context')
let context = ''
if (args.doc || args.refUrl) {
  const contextSources = []
  if (args.doc) contextSources.push({ type: 'doc', value: args.doc })
  if (args.refUrl) contextSources.push({ type: 'url', value: args.refUrl })

  const contextResults = await parallel(
    contextSources.map(source => () =>
      source.type === 'doc'
        ? agent(
            `Invoke /capability:document:read --file ${source.value}. Extract key context relevant to testing the BDD scenarios in work item ${args.workItem}.`,
            { agentType: 'zzaia-document-specialist', label: 'context-doc' }
          )
        : agent(
            `Fetch and summarize the URL ${source.value}. Extract key context relevant to testing the BDD scenarios in work item ${args.workItem}.`,
            { agentType: 'zzaia-web-searcher', label: 'context-url' }
          )
    )
  )
  context = contextResults.filter(Boolean).join('\n---\n')
}

phase('Execute Tests')
const stepResults = []
for (const step of testCase.steps) {
  const stepResult = await agent(
    `Invoke /behavior:development:test --type ${args.type} --step "${step}" --environment ${args.url} --application ${args.application} --debug-sources ${args.debugSources || 'new-relic'}${args.sourceMetadata ? ` --source-metadata ${args.sourceMetadata}` : ''}${context ? `\n\nTest context:\n${context}` : ''}. Report: step name, pass/fail, response time (ms), any anomalies found.`,
    { agentType: 'zzaia-tester-specialist', schema: STEP_RESULT_SCHEMA, label: `step:${step.substring(0, 30)}` }
  )
  stepResults.push(stepResult)
  log(`Step "${step.substring(0, 50)}..." — ${stepResult.passed ? 'PASS' : 'FAIL'}${stepResult.responseTimeMs ? ` (${stepResult.responseTimeMs}ms)` : ''}${stepResult.anomalies && stepResult.anomalies.length > 0 ? ` — anomalies: ${stepResult.anomalies.join(', ')}` : ''}`)
}

phase('Correlate')
const failedSteps = stepResults.filter(s => !s.passed || (s.anomalies && s.anomalies.length > 0))
const findings = failedSteps.map(s => ({
  step: s.step,
  passed: s.passed,
  anomalies: s.anomalies || [],
  severity: s.anomalies && s.anomalies.some(a => a.toLowerCase().includes('critical')) ? 'critical' : 'high',
}))

phase('Report')
const reportResult = await agent(
  `Invoke /capability:document:write --template test-result-report --title "${args.type} Test Results: ${workItem.title}" --context "Summary: ${stepResults.length} steps executed, ${stepResults.filter(s => s.passed).length} passed, ${failedSteps.length} failed/anomalies. Findings: ${findings.map(f => f.step).join('; ')}" --work-item ${args.testCase} --target-field discussion. Return confirmation of posted status.`,
  { agentType: 'zzaia-document-specialist', schema: REPORT_SCHEMA, label: 'test-report' }
)

phase('Bug Approval')
log('Delegating approval gate to agent: polling Test Case discussion for human reply with approved bug list. Since dynamic workflows are non-interactive, this agent will poll the discussion using its own tool access until a human reply appears with bug approvals, then parse and return the approved list.')
const approvalResult = await agent(
  `Poll the Test Case work item (ID ${args.testCase}) discussion in Azure DevOps project "${args.project}" every ~60 seconds by invoking /behavior:devops:work-item --action read-discussion --id ${args.testCase} --project ${args.project} on each check, until a human reply appears. Parse the reply to extract: approved bugs (with any severity adjustments), dismissed items. Return the final approved bug list with title, repo, steps to reproduce, and severity for each.`,
  { agentType: 'zzaia-devops-specialist', schema: BUG_APPROVAL_SCHEMA, label: 'bug-approval' }
)
const { approvedBugs, dismissed } = approvalResult

phase('Bugs')
const createdBugs = approvedBugs.length
  ? await parallel(
      approvedBugs.map(bug => () =>
        agent(
          `Invoke /behavior:devops:work-item --action create --type Bug --title "${bug.title}" --description "Steps to reproduce: ${bug.stepsToReproduce}\n\nAssociated repo: ${bug.repo}" --severity ${bug.severity} --parent ${args.testCase} --project ${args.project}. Return the created bug ID.`,
          { agentType: 'zzaia-devops-specialist', schema: BUG_CREATION_SCHEMA, label: `bug:${bug.title.substring(0, 30)}` }
        )
      )
    )
  : []

if (createdBugs.length > 0 || dismissed.length > 0) {
  await agent(
    `Invoke /behavior:devops:work-item --action post-discussion --id ${args.testCase} --project ${args.project} with a reply summarizing: Created ${createdBugs.length} bug work item${createdBugs.length !== 1 ? 's' : ''}${createdBugs.length > 0 ? ` (IDs: ${createdBugs.map(b => b.id).join(', ')})` : ''}. Dismissed ${dismissed.length} item${dismissed.length !== 1 ? 's' : ''}${dismissed.length > 0 ? `: ${dismissed.join(', ')}` : ''}.`,
    { agentType: 'zzaia-devops-specialist', label: 'bug-summary-post' }
  )
}

return {
  workItem,
  testCase,
  stepResults,
  report: reportResult,
  bugs: createdBugs.filter(Boolean),
  dismissedItems: dismissed,
}
