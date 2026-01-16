resource "aws_ecr_repository" "gdanca-ecr" {
  name                 = "gdanca-ecr-3tier"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  image_tag_mutability_exclusion_filter {
    filter      = "latest*"
    filter_type = "WILDCARD"
  }

  tags = {
    Name  = "gdanca_ecr"
    Owner = "gdanca"
  }
}