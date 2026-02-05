
terraform {
  backend "s3" {
    bucket       = "finops-aws-terraform-state-bucket" 
    region       = "us-east-1"
    key          = "cloud-sentinel/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true             
   
  }
}
