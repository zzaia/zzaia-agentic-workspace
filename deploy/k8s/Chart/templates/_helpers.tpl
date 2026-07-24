{{/*
=============================================================================
zzaia-agentic-workspace helpers
Ported from deploy/k8s/infra/Chart/templates/_helpers.tpl (zzaia-infra.*),
renamed to the zzaia-workspace.* prefix, plus workspace-specific helpers.

CALLING CONVENTION
  Zero-arg helpers take the root context:   {{ include "zzaia-workspace.labels" . }}
  Multi-arg helpers take a dict:            {{ include "zzaia-workspace.image" (dict "root" . "image" .Values.images.dind) }}
=============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "zzaia-workspace.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "zzaia-workspace.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "zzaia-workspace.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels. Root context.
*/}}
{{- define "zzaia-workspace.labels" -}}
helm.sh/chart: {{ include "zzaia-workspace.chart" . }}
{{ include "zzaia-workspace.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: zzaia-agentic-workspace
{{- end }}

{{/*
Selector labels. Root context.
*/}}
{{- define "zzaia-workspace.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zzaia-workspace.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full labels for a single workload, including the component label.
Usage: {{ include "zzaia-workspace.componentLabels" (dict "root" . "component" "dind-server") | nindent 4 }}
*/}}
{{- define "zzaia-workspace.componentLabels" -}}
{{ include "zzaia-workspace.labels" .root }}
app.kubernetes.io/component: {{ .component }}
app: {{ .component }}
{{- end }}

{{/*
Selector labels for a single workload. MUST be used for both
spec.selector.matchLabels and the pod template labels — these keys are
immutable on Deployments/StatefulSets, so never add anything volatile here.
Usage: {{ include "zzaia-workspace.componentSelectorLabels" (dict "root" . "component" "dind-server") | nindent 6 }}
*/}}
{{- define "zzaia-workspace.componentSelectorLabels" -}}
{{ include "zzaia-workspace.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
app: {{ .component }}
{{- end }}

{{/*
Fully qualified image reference with registry/tag inheritance.
Falls back: image.registry -> .Values.images.registry
            image.tag      -> .Values.images.defaultTag
Usage: image: {{ include "zzaia-workspace.image" (dict "root" . "image" .Values.images.dind) | quote }}
*/}}
{{- define "zzaia-workspace.image" -}}
{{- $img := .image -}}
{{- $registry := default .root.Values.images.registry $img.registry -}}
{{- $tag := default .root.Values.images.defaultTag $img.tag -}}
{{- if not $tag -}}
{{- fail (printf "image %s has no tag and images.defaultTag is empty: immutable tags are mandatory" $img.repository) -}}
{{- end -}}
{{- if eq (lower (toString $tag)) "latest" -}}
{{- fail (printf "image %s resolves to the mutable tag 'latest': pin an immutable tag" $img.repository) -}}
{{- end -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $img.repository (toString $tag) -}}
{{- else -}}
{{- printf "%s:%s" $img.repository (toString $tag) -}}
{{- end -}}
{{- end }}

{{/*
Image reference looked up by key in .Values.images — used by the MCP loop,
where each server carries `image: "mcpTavily"`.
Usage: image: {{ include "zzaia-workspace.imageByKey" (dict "root" . "key" $mcp.image) | quote }}
*/}}
{{- define "zzaia-workspace.imageByKey" -}}
{{- $img := index .root.Values.images .key -}}
{{- if not $img -}}
{{- fail (printf "no entry .Values.images.%s" .key) -}}
{{- end -}}
{{- include "zzaia-workspace.image" (dict "root" .root "image" $img) -}}
{{- end }}

{{/*
Pull policy with inheritance from .Values.images.pullPolicy.
Usage: imagePullPolicy: {{ include "zzaia-workspace.imagePullPolicy" (dict "root" . "image" .Values.images.dind) }}
*/}}
{{- define "zzaia-workspace.imagePullPolicy" -}}
{{- default .root.Values.images.pullPolicy .image.pullPolicy -}}
{{- end }}

{{/*
imagePullSecrets block. Emits nothing when neither source is set.
MAY RENDER EMPTY -> call it wrapped so no blank line is emitted:
  {{- with (include "zzaia-workspace.imagePullSecrets" .) }}{{ . | nindent 6 }}{{- end }}
*/}}
{{- define "zzaia-workspace.imagePullSecrets" -}}
{{- $secrets := list -}}
{{- if .Values.images.pullSecret -}}
{{- $secrets = append $secrets .Values.images.pullSecret -}}
{{- end -}}
{{- range .Values.imagePullSecrets -}}
{{- $secrets = append $secrets . -}}
{{- end -}}
{{- if $secrets }}
imagePullSecrets:
{{- range $secrets | uniq }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Pod-level securityContext. Emits fsGroup + seccompProfile only.
Usage: {{- include "zzaia-workspace.podSecurityContext" (dict "ctx" .Values.neo4j.securityContext) | nindent 6 }}
*/}}
{{- define "zzaia-workspace.podSecurityContext" -}}
{{- $c := .ctx | default dict -}}
seccompProfile:
  type: RuntimeDefault
{{- if $c.fsGroup }}
fsGroup: {{ $c.fsGroup }}
fsGroupChangePolicy: OnRootMismatch
{{- end }}
{{- end }}

{{/*
Container-level securityContext.
Usage: {{- include "zzaia-workspace.containerSecurityContext" (dict "ctx" .Values.bifrost.securityContext) | nindent 10 }}
*/}}
{{- define "zzaia-workspace.containerSecurityContext" -}}
{{- $c := .ctx | default dict -}}
allowPrivilegeEscalation: {{ $c.allowPrivilegeEscalation | default false }}
{{- if $c.privileged }}
privileged: true
{{- end }}
{{- if hasKey $c "runAsUser" }}
runAsUser: {{ $c.runAsUser }}
{{- end }}
{{- if hasKey $c "runAsGroup" }}
runAsGroup: {{ $c.runAsGroup }}
{{- end }}
{{- if hasKey $c "runAsNonRoot" }}
runAsNonRoot: {{ $c.runAsNonRoot }}
{{- end }}
{{- if hasKey $c "readOnlyRootFilesystem" }}
readOnlyRootFilesystem: {{ $c.readOnlyRootFilesystem }}
{{- end }}
{{- if or $c.capabilitiesDrop $c.capabilitiesAdd }}
capabilities:
  {{- with $c.capabilitiesDrop }}
  drop:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $c.capabilitiesAdd }}
  add:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
FQDN of a service in the shared infra namespace. Never used for this chart's
own objects — those use bare service names in .Release.Namespace.
Usage: {{ include "zzaia-workspace.infraFqdn" (dict "root" . "service" "vault-data-engine") }}
*/}}
{{- define "zzaia-workspace.infraFqdn" -}}
{{- printf "%s.%s.svc.cluster.local" .service .root.Values.sharedInfraNamespace -}}
{{- end }}

{{/*
FQDN of a service in THIS release namespace.
Usage: {{ include "zzaia-workspace.localFqdn" (dict "root" . "service" "ml-server") }}
*/}}
{{- define "zzaia-workspace.localFqdn" -}}
{{- printf "%s.%s.svc.cluster.local" .service .root.Release.Namespace -}}
{{- end }}

{{/*
Cluster-scoped object name, namespace-prefixed to avoid colliding with the
infra chart. MANDATORY for every ClusterRole/ClusterRoleBinding this chart owns.
Usage: name: {{ include "zzaia-workspace.clusterScopedName" (dict "root" . "name" "dind-privileged") }}
*/}}
{{- define "zzaia-workspace.clusterScopedName" -}}
{{- printf "%s-%s" .root.Release.Namespace .name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Cluster Vault address (VAULT_ADDR). Honours an explicit .Values.vault.addr.
Usage: value: {{ include "zzaia-workspace.vaultAddr" . | quote }}
*/}}
{{- define "zzaia-workspace.vaultAddr" -}}
{{- if .Values.vault.addr -}}
{{- .Values.vault.addr -}}
{{- else -}}
{{- printf "http://%s:%v" (include "zzaia-workspace.infraFqdn" (dict "root" . "service" .Values.vault.serviceName)) .Values.vault.port -}}
{{- end -}}
{{- end }}

{{/*
OTLP HTTP endpoint in the shared infra namespace.
Usage: value: {{ include "zzaia-workspace.otlpEndpoint" . | quote }}
*/}}
{{- define "zzaia-workspace.otlpEndpoint" -}}
{{- if .Values.observability.otlpEndpoint -}}
{{- .Values.observability.otlpEndpoint -}}
{{- else -}}
{{- printf "http://%s:%v" (include "zzaia-workspace.infraFqdn" (dict "root" . "service" .Values.observability.otlpService)) .Values.observability.otlpHttpPort -}}
{{- end -}}
{{- end }}

{{/*
OTLP gRPC endpoint in the shared infra namespace.
*/}}
{{- define "zzaia-workspace.otlpGrpcEndpoint" -}}
{{- printf "http://%s:%v" (include "zzaia-workspace.infraFqdn" (dict "root" . "service" .Values.observability.otlpService)) .Values.observability.otlpGrpcPort -}}
{{- end }}

{{/*
Standard OTEL env vars. Emits nothing when observability.enabled is false.
MAY RENDER EMPTY -> call it wrapped:
  {{- with (include "zzaia-workspace.otelEnv" (dict "root" . "component" "ml-server")) }}{{ . | nindent 8 }}{{- end }}
*/}}
{{- define "zzaia-workspace.otelEnv" -}}
{{- if .root.Values.observability.enabled -}}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ include "zzaia-workspace.otlpEndpoint" .root | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: {{ .root.Values.observability.otlpProtocol | quote }}
- name: OTEL_SERVICE_NAME
  value: {{ .component | quote }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ printf "service.name=%s,service.namespace=%s,deployment.environment=%s" .component .root.Values.observability.serviceNamespace .root.Release.Namespace | quote }}
- name: OTEL_TRACES_EXPORTER
  value: {{ .root.Values.observability.tracesExporter | quote }}
- name: OTEL_METRICS_EXPORTER
  value: {{ .root.Values.observability.metricsExporter | quote }}
- name: OTEL_LOGS_EXPORTER
  value: {{ .root.Values.observability.logsExporter | quote }}
{{- end }}
{{- end }}

{{/*
LLM proxy env shared by workspace-server, vscode, jupyter, containers-dev and
tunnel sidecars — the ANTHROPIC, OPENAI and GEMINI env block from compose.
Usage: {{- include "zzaia-workspace.llmProxyEnv" . | nindent 8 }}
*/}}
{{- define "zzaia-workspace.llmProxyEnv" -}}
{{- $p := .Values.llmProxy }}
{{- $ml := printf "http://%s:%v" $p.mlServerService $p.mlServerPort -}}
- name: ANTHROPIC_BASE_URL
  value: {{ $ml | quote }}
- name: ANTHROPIC_API_KEY
  value: {{ $p.anthropicVirtualKey | quote }}
- name: ANTHROPIC_API_KEY_AGENTS
  value: {{ $p.agentsVirtualKey | quote }}
- name: OPENAI_BASE_URL
  value: {{ $ml | quote }}
- name: OPENAI_API_KEY
  value: {{ $p.openaiPlaceholderKey | quote }}
- name: GOOGLE_GEMINI_BASE_URL
  value: {{ $ml | quote }}
- name: GEMINI_API_BASE
  value: {{ $ml | quote }}
- name: GEMINI_API_KEY
  value: {{ $p.geminiPlaceholderKey | quote }}
{{- end }}

{{/*
Toolchain / agent-CLI feature flag env — compose's *_ENABLED variables consumed
by the workspace-server Ansible bootstrap.
Usage: {{- include "zzaia-workspace.featureEnv" . | nindent 8 }}
*/}}
{{- define "zzaia-workspace.featureEnv" -}}
- name: WORKSPACE_NAME
  value: {{ .Values.workspaceName | quote }}
- name: GPU_ENABLED
  value: {{ .Values.gpu.enabled | quote }}
- name: NODE_ENABLED
  value: {{ .Values.toolchains.node | quote }}
- name: NODE_FRONTEND_ENABLED
  value: {{ .Values.toolchains.nodeFrontend | quote }}
- name: JAVA_ENABLED
  value: {{ .Values.toolchains.java | quote }}
- name: RUST_ENABLED
  value: {{ .Values.toolchains.rust | quote }}
- name: LUA_ENABLED
  value: {{ .Values.toolchains.lua | quote }}
- name: CPP_ENABLED
  value: {{ .Values.toolchains.cpp | quote }}
- name: CLOJURE_ENABLED
  value: {{ .Values.toolchains.clojure | quote }}
- name: GO_ENABLED
  value: {{ .Values.toolchains.go | quote }}
- name: KOTLIN_ENABLED
  value: {{ .Values.toolchains.kotlin | quote }}
- name: RUBY_ENABLED
  value: {{ .Values.toolchains.ruby | quote }}
- name: PHP_ENABLED
  value: {{ .Values.toolchains.php | quote }}
- name: SWIFT_ENABLED
  value: {{ .Values.toolchains.swift | quote }}
- name: OPENCODE_ENABLED
  value: {{ .Values.agentClis.opencode | quote }}
- name: CODEX_ENABLED
  value: {{ .Values.agentClis.codex | quote }}
- name: GEMINI_ENABLED
  value: {{ .Values.agentClis.gemini | quote }}
- name: COPILOT_ENABLED
  value: {{ .Values.agentClis.copilot | quote }}
{{- end }}

{{/*
DOCKER_HOST pointing at the in-namespace dind service.
Usage: value: {{ include "zzaia-workspace.dockerHost" . | quote }}
*/}}
{{- define "zzaia-workspace.dockerHost" -}}
{{- printf "tcp://%s:%v" .Values.dind.name .Values.dind.ports.tcp -}}
{{- end }}

{{/*
Neo4j bolt URI for in-namespace consumers.
*/}}
{{- define "zzaia-workspace.neo4jUri" -}}
{{- printf "bolt://%s:%v" .Values.neo4j.name .Values.neo4j.ports.bolt -}}
{{- end }}

{{/*
Qdrant HTTP URL for in-namespace consumers.
*/}}
{{- define "zzaia-workspace.qdrantUrl" -}}
{{- printf "http://%s:%v" .Values.qdrant.name .Values.qdrant.ports.http -}}
{{- end }}

{{/*
Name of the ESO-materialised Secret holding every credential.
*/}}
{{- define "zzaia-workspace.secretName" -}}
{{- .Values.externalSecrets.targetSecretName -}}
{{- end }}

{{/*
Name of the per-Key-Vault-group Secret that externalsecrets.yaml materialises
for one group (e.g. "ai", "mcp-github", "admin"). One ExternalSecret + Secret
pair per group in .Values.externalSecrets.groupNames, instead of one monolithic
Secret carrying all 23 keys — so a consumer's envFrom only injects the group(s)
it actually needs.
Usage: {{ include "zzaia-workspace.groupSecretName" (dict "root" . "group" "ai") }}
*/}}
{{- define "zzaia-workspace.groupSecretName" -}}
{{- printf "%s-%s" (include "zzaia-workspace.secretName" .root) .group -}}
{{- end }}

{{/*
envFrom entries for one or more credential groups. Optional so `helm template`
renders before ESO has created the Secrets. Each consumer lists ONLY the
groups its entrypoint actually reads (verified against each container's
entrypoint.sh under docker/containers/) — replaces the old blanket
single-Secret envFrom that injected all 23 keys into every consumer regardless
of need.
Usage: {{- include "zzaia-workspace.credentialsEnvFrom" (dict "root" . "groups" (list "ai" "mcp-github")) | nindent 8 }}
*/}}
{{- define "zzaia-workspace.credentialsEnvFrom" -}}
{{- range .groups }}
- secretRef:
    name: {{ include "zzaia-workspace.groupSecretName" (dict "root" $.root "group" .) }}
    optional: true
{{- end }}
{{- end }}

{{/*
PVC name for a .Values.volumes.<key> entry. Release-name prefixed so two
releases can coexist in different namespaces.
Usage: claimName: {{ include "zzaia-workspace.pvcName" (dict "root" . "volume" "workspaceHome") }}
*/}}
{{- define "zzaia-workspace.pvcName" -}}
{{- printf "%s-%s" .root.Release.Name (.volume | kebabcase) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
StorageClass for a .Values.volumes.<key> entry, with inheritance.
Usage: storageClassName: {{ include "zzaia-workspace.volumeStorageClass" (dict "root" . "volume" .Values.volumes.workspaceHome) | quote }}
*/}}
{{- define "zzaia-workspace.volumeStorageClass" -}}
{{- default .root.Values.storageClass .volume.storageClass -}}
{{- end }}

{{/*
Common pod scheduling block: priorityClass, nodeSelector, tolerations, affinity.
Usage: {{- include "zzaia-workspace.scheduling" . | nindent 6 }}
*/}}
{{- define "zzaia-workspace.scheduling" -}}
{{- if .Values.priorityClassName -}}
priorityClassName: {{ .Values.priorityClassName }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Merge an mcpServers entry over mcpDefaults. Returns the effective config as
YAML — re-parse with fromYaml at the call site.
Usage: {{- $cfg := fromYaml (include "zzaia-workspace.mcpConfig" (dict "root" $ "mcp" $mcp)) }}
*/}}
{{- define "zzaia-workspace.mcpConfig" -}}
{{- /* mergeOverwrite(dst, src): src wins. dst = defaults, src = the entry.
       Sprig/mergo will NOT override with an "empty" value (false, 0, "", []),
       so every boolean and numeric knob is declared explicitly on each
       mcpServers entry and re-asserted below rather than being inherited. */ -}}
{{- $merged := mergeOverwrite (deepCopy .root.Values.mcpDefaults) (deepCopy .mcp) -}}
{{- range $k, $v := .mcp -}}
{{- if kindIs "bool" $v -}}
{{- $_ := set $merged $k $v -}}
{{- end -}}
{{- end -}}
{{- if hasKey .mcp "shmSizeMi" -}}
{{- $_ := set $merged "shmSizeMi" .mcp.shmSizeMi -}}
{{- end -}}
{{- if hasKey .mcp "securityContext" -}}
{{- $sc := index $merged "securityContext" -}}
{{- range $k, $v := .mcp.securityContext -}}
{{- if or (kindIs "bool" $v) (kindIs "slice" $v) -}}
{{- $_ := set $sc $k $v -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $merged -}}
{{- end }}

{{/*
Ingress host for a subdomain: <subdomain>.<domain>.
Usage: host: {{ include "zzaia-workspace.ingressHost" (dict "root" . "subdomain" "vscode") }}
*/}}
{{- define "zzaia-workspace.ingressHost" -}}
{{- printf "%s.%s" .subdomain .root.Values.domain -}}
{{- end }}

{{/*
Full browsable HTTPS URL for a subdomain, INCLUDING the Kong LoadBalancer
port when it isn't 443 (it defaults to 8443 — see .Values.ingress.httpsPort).
Ingress `host:` fields can't carry a port, so use ingressHost (above) inside
actual Ingress objects; use this helper anywhere a human-facing URL is
printed (NOTES.txt, README, QUICKSTART) so it's actually reachable as shown.
Usage: {{ include "zzaia-workspace.ingressUrl" (dict "root" . "subdomain" "vscode") }}
*/}}
{{- define "zzaia-workspace.ingressUrl" -}}
{{- $host := include "zzaia-workspace.ingressHost" . -}}
{{- if eq (.root.Values.ingress.httpsPort | int) 443 -}}
{{- printf "https://%s" $host -}}
{{- else -}}
{{- printf "https://%s:%v" $host .root.Values.ingress.httpsPort -}}
{{- end -}}
{{- end }}

{{/*
TLS secret name for Ingress, with inheritance.
*/}}
{{- define "zzaia-workspace.tlsSecretName" -}}
{{- default .Values.tlsSecretName .Values.ingress.tls.secretName -}}
{{- end }}

{{/*
Ingress annotations, including the Kong long-read-timeout that replaces
nginx-proxy's proxy_read_timeout 3600s.
Usage: {{- include "zzaia-workspace.ingressAnnotations" . | nindent 4 }}
*/}}
{{- define "zzaia-workspace.ingressAnnotations" -}}
{{- with .Values.ingress.annotations }}
{{- toYaml . }}
{{- end }}
konghq.com/read-timeout: {{ mul .Values.ingress.readTimeoutSeconds 1000 | quote }}
konghq.com/write-timeout: {{ mul .Values.ingress.readTimeoutSeconds 1000 | quote }}
{{- end }}

{{/*
GPU resource fragment. Emits nothing when gpu.enabled is false.
MAY RENDER EMPTY -> call it wrapped, inside a resources.limits block:
  {{- with (include "zzaia-workspace.gpuLimits" .) }}{{ . | nindent 12 }}{{- end }}
*/}}
{{- define "zzaia-workspace.gpuLimits" -}}
{{- if .Values.gpu.enabled -}}
{{ .Values.gpu.resourceName }}: {{ .Values.gpu.count }}
{{- end }}
{{- end }}

{{/*
busybox initContainer that chowns a PVC mount to the workload's uid/gid.
Mirrors the infra chart's postgres fix-permissions pattern.
Usage:
  initContainers:
    {{- include "zzaia-workspace.fixPermissions" (dict "root" . "volumeName" "database-qdrant" "mountPath" "/qdrant/storage" "ctx" .Values.qdrant.securityContext) | nindent 6 }}
*/}}
{{- define "zzaia-workspace.fixPermissions" -}}
{{- $uid := .ctx.runAsUser | default 0 }}
{{- $gid := .ctx.runAsGroup | default $uid -}}
- name: fix-permissions
  image: {{ include "zzaia-workspace.image" (dict "root" .root "image" .root.Values.images.busybox) | quote }}
  imagePullPolicy: {{ include "zzaia-workspace.imagePullPolicy" (dict "root" .root "image" .root.Values.images.busybox) }}
  command:
    - sh
    - -c
    - chown -R {{ $uid }}:{{ $gid }} {{ .mountPath }} && chmod 0750 {{ .mountPath }}
  securityContext:
    runAsUser: 0
    runAsNonRoot: false
    allowPrivilegeEscalation: true
    capabilities:
      drop:
        - ALL
      add:
        - CHOWN
        - FOWNER
        - DAC_OVERRIDE
  resources:
    requests:
      cpu: 10m
      memory: 16Mi
    limits:
      cpu: 100m
      memory: 64Mi
  volumeMounts:
    - name: {{ .volumeName }}
      mountPath: {{ .mountPath }}
{{- end }}

{{/*
Probe body builder. Renders exactly one probe stanza.
Usage:
  livenessProbe:
    {{- include "zzaia-workspace.probe" (dict "kind" "http" "port" 8080 "path" "/health" "cfg" .Values.bifrost.probes.liveness) | nindent 10 }}

kind: "http" | "tcp" | "exec"
  http -> requires port + path
  tcp  -> requires port
  exec -> requires command (a list)
*/}}
{{- define "zzaia-workspace.probe" -}}
{{- $cfg := .cfg | default dict -}}
{{- if eq .kind "http" -}}
httpGet:
  path: {{ .path }}
  port: {{ .port }}
{{- else if eq .kind "tcp" -}}
tcpSocket:
  port: {{ .port }}
{{- else if eq .kind "exec" -}}
exec:
  command:
    {{- toYaml .command | nindent 4 }}
{{- else }}
{{- fail (printf "zzaia-workspace.probe: unknown kind %q (want http|tcp|exec)" .kind) }}
{{- end }}
{{- if hasKey $cfg "initialDelaySeconds" }}
initialDelaySeconds: {{ $cfg.initialDelaySeconds }}
{{- end }}
periodSeconds: {{ $cfg.periodSeconds | default 10 }}
timeoutSeconds: {{ $cfg.timeoutSeconds | default 5 }}
failureThreshold: {{ $cfg.failureThreshold | default 3 }}
successThreshold: {{ $cfg.successThreshold | default 1 }}
{{- end }}
