
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket" 
    region       = "us-west-1"
    key          = "cloud-sentinel/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true             
   
  }
}
