resource "aws_iam_role" "AmazonEKSLoadBalancerControllerRole" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${var.oidc_url}:aud": "sts.amazonaws.com",
          "${var.oidc_url}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Federated": "${var.oidc_arn}"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns  = ["arn:aws:iam::${var.account_id}:policy/${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"]
  max_session_duration = "3600"
  name                 = "${var.cluster_name}-AmazonEKSLoadBalancerControllerRole"
  path                 = "/"

  tags = {
    project = "${var.cluster_name}"
  }

  tags_all = {
    project = "${var.cluster_name}"
  }
}
