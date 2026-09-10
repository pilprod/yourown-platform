# runtime

Status: planned unless explicitly stated otherwise.

Planned: Kubernetes charts/add-ons and narrowly scoped edge runtimes. Keep product workloads out. Cluster bootstrap and add-on ownership must not compete with a second reconciler.

Azure Container Apps and AKS are explicit planned runtime profiles alongside Cloud Run/ECS and GKE/EKS. Their ingress, revisions, workload identity, network isolation and scaling require their own acceptance tests; shared contracts do not promise identical behavior or cost.
