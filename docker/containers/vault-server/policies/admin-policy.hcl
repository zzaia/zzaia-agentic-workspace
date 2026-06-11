path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/*" {
  capabilities = ["list", "read"]
}
path "auth/*" {
  capabilities = ["read", "list"]
}
path "sys/policies/*" {
  capabilities = ["read", "list"]
}
