CrowdstrikeAccountID = "292230061137"
//description = "the crowdstrike AWS account id"

Regions = ""
//description = "comma separated list of regions to enable"

ExternalID = ""
//description = "The random string to use for role-assumption external id condition"

ScannerContainer = ""
//description = "the ecr container url to use for the batch job"

LambdaVersion = "v2"
//description = "version of the custom resource lambda to deploy"

CrowdstrikeClientID = ""
//"The crowdstrike API client id. Must have the snapshot scope"

CrowdstrikeClientSecret = ""
//description = "The crowdstrike API client secret. Must have the snapshot scope"

CrowdstrikeAPIUrl = ""
//"Crowdstrike api base url, no trailing slash"
//"eg. https://api.crowdstrike.com"

VPC = false
//description = "set to true if VPCRegions and SubnetRegions are set"

VPCRegions = ""
//description = "key-value pairs for tying regions to vpcs. e.g. us-east-1=vpc-abcdef,us-east-2=vpc-12354. must have the same length as regions."

SubnetRegions = ""
//description = "key-value pairs for associating subnets to vpcs in a region. these subnets must be part of the respective vpc defined in VPCRegions. values must be bracketed []. e.g. us-east-1=[subnet-abc,subnet-def],us-east-2=[subnet-123,subnet-456]. must have the same length as regions. subnets must have internet access"
