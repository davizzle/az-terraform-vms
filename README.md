Web Infrastructure Setup with Azure Application Gateway and Backup
This repository contains Terraform code to deploy a web infrastructure in Azure. The setup includes the following components:
   � A Virtual Network with subnets for Web and Database tiers.
   � Virtual Machines (Windows) for the Web and Database tiers.
   � A Load Balancer to distribute traffic across the Web tier VMs.
   � An Application Gateway for HTTP/HTTPS traffic routing.
   � Azure Backup for VM protection and recovery.
   � Supporting resources like public IPs, NSGs, and a storage account for diagnostic logs.
________________________________________

Features
1.	Networking:
        o Virtual Network (10.0.0.0/16) with subnets for Web Tier (10.0.1.0/24) and Database Tier (10.0.2.0/24).
	o Network Security Groups (NSGs) for Web Tier with rules for HTTP and HTTPS traffic.
2.	Compute:
	o Two Web Tier VMs in an Availability Set for high availability.
	o One Database Tier VM with system-assigned identity for future enhancements.
3.	Load Balancing:
	o A Load Balancer for the Web Tier with a health probe and load balancing rules.
4.	Application Gateway:
	o HTTP-based routing for frontend traffic to Web Tier backend.
5.	Backup:
	o Daily Azure Backup with a 7-day retention policy for Web Tier VMs.
________________________________________

Prerequisites
Before deploying, ensure you have the following:
    � Terraform installed on your machine.
    � An Azure account with the necessary permissions to create resources.
    � Set up an Azure Service Principal for authentication.
    � Set the following Terraform variables in a variables.tf file:
	admin_username = "your_admin_username"
	admin_password = "your_admin_password"
________________________________________

Deployment Steps
Follow these steps to deploy the infrastructure:
1. Clone the Repository
git clone git clone https://github.com/davizzle/az-terraform-vms
cd cd az-terraform-vms/
2. Initialize Terraform
Run the following command to initialize Terraform and download required providers:
terraform init
3. Validate the Configuration
Ensure the configuration is syntactically correct:
terraform validate
4. Plan the Deployment
Review the resources that will be created:
terraform plan
5. Apply the Configuration
Deploy the resources to Azure:
terraform apply
When prompted, type yes to confirm the deployment.
6. Monitor the Deployment
After deployment, you can verify the resources in the Azure Portal under the WebInfraResourceGroup.
________________________________________


Directory Structure.
+-- main.tf                   # Main Terraform configuration file
+-- variables.tf              # Variable definitions
+-- outputs.tf                # Outputs for the deployment
+-- README.md                 # Project documentation
________________________________________

Cleanup
To remove all deployed resources, run:
bash
Copy code
terraform destroy
Type yes to confirm the destruction.
________________________________________

