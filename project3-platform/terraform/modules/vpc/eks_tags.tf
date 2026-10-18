resource "aws_ec2_tag" "elb" {
  count       = length(var.azs)
  resource_id = aws_subnet.public[count.index].id
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
