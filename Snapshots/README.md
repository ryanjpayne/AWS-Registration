# Provision Snapshot Management with Terraform

**Note**: This repo only provides guidance to provision Snapshot Management resources with terraform, for more information about the CrowdStrike Snapshot Management service, see our [official documentation](https://falcon.crowdstrike.com/documentation/page/bcc0606d/get-started-with-snapshot)
  
## Step 1 - Enable Snapshot Management
1. Navigate to Falcon Console Cloud Security > Accounts Registration
2. For the account you wish to enable, click Set-Up or Inactive under the Snapshot column
3. Select the regions you wish to enable and click Apply

## Step 2 - Retrieve Required Values
1. Click Copy CloudFormation Link and paste into a text editor
2. It will look like the following:
```
https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?
templateURL=path/to/snapshot/cloudformation/template.yaml
&stackName=stack-name
&param_CrowdstrikeAccountID=123456789123
&param_Regions=us-east-1,us-east-2
&param_ExternalID=myexternalid123456789
&param_ScannerContainer=
&param_CrowdstrikeAPIUrl=https://my.api.url.com
```
3. Retrieve the values for CrowdstrikeAccountID, Regions, ExternalID and CrowdStrikeAPIUrl

## Step 3 - Download and Update config.tfvars
1. Download the contents of this repository
2. Edit the config.tfvars file  
**When applicable, please use the values generated in Step 2**  
3. Review the provider configuration and your tfvars values

## Step 4 - Create
1. run ```terraform init``` to install providers
2. run ```terraform plan``` to review the configuration
3. run ```terraform apply``` to deploy the configuration 