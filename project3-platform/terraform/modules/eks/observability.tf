resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "cloudwatch" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "amazon-cloudwatch-observability"
  depends_on   = [aws_eks_node_group.this, aws_iam_role_policy_attachment.cw_agent]
}
