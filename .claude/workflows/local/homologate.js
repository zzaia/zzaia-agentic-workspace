export const meta = {
  name: 'workflows:local:homologate',
  description: 'Execute BDD-style homologation tests against a URL locally and generate a test result report',
  whenToUse: 'Developer validation of BDD scenarios against a live or local URL, collecting diagnostics and generating a local report file',
  phases: [
    { title: 'Context' },
    { title: 'Execute Tests' },
    { title: 'Correlate' },
    { title: 'Report' },
  ],
}

// args: { url, application, type, steps, description, doc?, debugSources?, sourceMetadata? }
// type: 'e2e' | 'ui'
// steps: array of BDD step strings (no remote Test Case retrieval)

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
    path: { type: 'string' },
  },
  required: ['path'],
}

phase('Context')
let context = ''
if (args.doc) {
  const contextResult = await agent(
    `Invoke the SlashCommand tool to run exactly: /capability:document:read --file ${args.doc}. Extract key context relevant to testing the BDD scenarios for application "${args.application}".`,
    { agentType: 'zzaia-document-specialist', label: 'context-doc' }
  )
  context = contextResult || ''
}

phase('Execute Tests')
const stepResults = []
for (const step of args.steps) {
  let command = `/behavior:development:test --type ${args.type} --step "${step}" --environment ${args.url} --application ${args.application} --debug-sources ${args.debugSources || 'new-relic'}`
  if (args.sourceMetadata) {
    command += ` --source-metadata ${args.sourceMetadata}`
  }
  const stepResult = await agent(
    `Invoke the SlashCommand tool to run exactly: ${command}. Report step name, pass/fail, response time (ms), and any anomalies found.`,
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
const slugFromDescription = (args.description || args.application || 'homologation')
  .toLowerCase()
  .replace(/[^\w\s-]/g, '')
  .replace(/\s+/g, '-')
  .replace(/-+/g, '-')
  .substring(0, 60)

const stepResultsAndFindings = JSON.stringify({ stepResults, findings }, null, 2)
const reportResult = await agent(
  `Invoke the SlashCommand tool to run exactly: /capability:document:write --template test-result-report --title "${args.type} Test Results: ${args.application}" --context "${stepResultsAndFindings}" --output "./docs/homologation-reports/${slugFromDescription}.md". Return the written file path.`,
  { agentType: 'zzaia-document-specialist', schema: REPORT_SCHEMA, label: 'test-report' }
)

return {
  stepResults,
  findings,
  reportPath: reportResult.path,
}
