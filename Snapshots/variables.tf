variable "principals" {
  type = map(string)
  default = {
    292230061137  = "arn:aws:iam::292230061137:role/CrowdStrikeCustomerSnapshotAssessmentRole"
    142028973013  = "arn:aws-us-gov:iam::142028973013:role/CrowdStrikeCustomerSnapshotAssessmentRole"
    358431324613 = "arn:aws-us-gov:iam::358431324613:role/CrowdStrikeCustomerSnapshotAssessmentRole"
  }
}

variable "CrowdstrikeAccountID" {
    type = string
    description = "the crowdstrike AWS account id"
    default = "292230061137"
}
variable "Regions" {
    type = string
    description = "comma separated list of regions to enable"
}
variable "ExternalID" {
    type = string
    description = "The random string to use for role-assumption external id condition"
}
variable "ScannerContainer" {
    type = string
    description = "the ecr container url to use for the batch job"
}
variable "LambdaVersion" {
    type = string
    description = "version of the custom resource lambda to deploy"
    default = "v2"
}
variable "CrowdstrikeClientID" {
    type = string
    description = "The crowdstrike API client id. Must have the snapshot scope"
}
variable "CrowdstrikeClientSecret" {
    type = string
    description = "The crowdstrike API client secret. Must have the snapshot scope"
}
variable "CrowdstrikeAPIUrl" {
    type = string
    description = "Crowdstrike api base url, no trailing slash"
}
variable "VPC" {
    type = bool
    description = "set to true if VPCRegions and SubnetRegions are set"
    default = false
}
variable "VPCRegions" {
    type = string
    description = "key-value pairs for tying regions to vpcs. e.g. us-east-1=vpc-abcdef,us-east-2=vpc-12354. must have the same length as regions."
    default = ""
}
variable "SubnetRegions" {
    type = string
    description = "key-value pairs for associating subnets to vpcs in a region. these subnets must be part of the respective vpc defined in VPCRegions. values must be bracketed []. e.g. us-east-1=[subnet-abc,subnet-def],us-east-2=[subnet-123,subnet-456]. must have the same length as regions. subnets must have internet access"
    default = ""
}