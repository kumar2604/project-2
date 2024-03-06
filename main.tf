
# Configure the AWS Provider
  provider "aws" {
    region = var.aws_region
}


# create iam role and attach policy
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks-cluster-role-1" {
  name               = "eks-cluster-role-1"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks-cluster-role-1-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster-role-1.name
}


#get vpc data
data "aws_vpc" "default" {
     default = true 
}
#get public subnets for cluster
data "aws_subnets" "example-1" {
    filter {
      name = "vpc-id"
      values = [ data.aws_vpc.default.id ]
    }
  
}


#provisioning for cluster
resource "aws_eks_cluster" "EKS-CLUSTER" {
  name     = "EKS-CLUSTER"
  role_arn = aws_iam_role.eks-cluster-role-1.arn

  vpc_config {
    subnet_ids = data.aws_subnets.example-1.ids
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-role-1-AmazonEKSClusterPolicy,
  ]
}

resource "aws_iam_role" "eks-node-role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-node-role-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-role-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-role-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-node-role.name
}

#provisioning node-group
resource "aws_eks_node_group" "EKS-worker" {
  cluster_name    = aws_eks_cluster.EKS-CLUSTER.name
  node_group_name = "EKS-NODE"
  node_role_arn   = aws_iam_role.eks-node-role.arn
  subnet_ids      = data.aws_subnets.example-1.ids

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
   
   instance_types = ["t2.small"]

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks-node-role-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.eks-node-role-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-node-role-AmazonEC2ContainerRegistryReadOnly,
  ]
}