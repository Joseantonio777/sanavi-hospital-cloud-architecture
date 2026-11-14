# ============================================================================
# Grupo Hospitalario SanaVI - Clúster Amazon EKS y Node Groups Auto-Escalables
# Microservicios: HCE, Citas, Inventarios, Facturación y Legacy Adapter
# ============================================================================

resource "aws_eks_cluster" "sanavi_eks" {
  name     = "sanavi-eks-cluster"
  role_arn = "arn:aws:iam::486923200363:role/LabEksClusterRole"
  version  = "1.37"

  vpc_config {
    subnet_ids              = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Encriptación de Kubernetes Secrets en Etcd mediante clave maestra AWS KMS (Requisito HIPAA)
  encryption_config {
    provider {
      key_arn = aws_kms_key.sanavi_hipaa_key.arn
    }
    resources = ["secrets"]
  }

  # Logs de auditoría del Control Plane para cumplimiento normativo HIPAA
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

resource "aws_eks_node_group" "sanavi_microservices_nodes" {
  cluster_name    = aws_eks_cluster.sanavi_eks.name
  node_group_name = "sanavi-clinical-nodegroup"
  node_role_arn   = "arn:aws:iam::486923200363:role/LabEksNodeRole"
  subnet_ids      = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 6
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload    = "clinical-microservices"
    compliance  = "hipaa"
    environment = "production"
  }
}
