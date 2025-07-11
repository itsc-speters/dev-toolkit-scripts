# Developer Toolkit Scripts

A collection of useful shell scripts for Git and Terraform repository management.

## 🛠️ Scripts

### 🧹 `terraform_cleanup_advanced.sh`

Advanced Terraform cleanup utility with preview and batch processing.

### 🔄 `git_ssh_converter.sh`

Convert Git repositories from HTTPS to SSH authentication.

### 🔍 `check_git_config.sh`

Scan and display Git configuration across multiple repositories.

### 🌐 `ovh_allowlist.sh`

Automatically update your current public IP in OVH allowlist.

## 📋 Quick Start

```bash
# Make scripts executable
chmod +x *.sh

# Preview Terraform cleanup
./terraform_cleanup_advanced.sh -d ../

# Convert Git repos to SSH
./git_ssh_converter.sh ../

# Check Git configurations
./check_git_config.sh ../

# Update OVH IP allowlist
cd ovh_allowlist && ./ovh_allowlist.sh
```

## 🌐 OVH Allowlist Setup

The `ovh_allowlist/ovh_allowlist.sh` script automatically updates your current public IP in OVH's allowlist.

### Prerequisites

1. **Get OVH API Credentials** from [OVH API Console](https://eu.api.ovh.com/createToken/)
   - Set permissions for:
     - **GET** `/dedicatedCloud/*`
     - **PUT** `/dedicatedCloud/*/allowedNetwork/*`

2. **Set Environment Variables** (choose one method):

   **Option A: Environment Variables**

   ```bash
   export OVH_APPLICATION_KEY='your_application_key'
   export OVH_APPLICATION_SECRET='your_application_secret'
   export OVH_CONSUMER_KEY='your_consumer_key'
   export SERVICE_NAME='pcc-xxx-xx-xx-xx'
   export NETWORK_ACCESS_ID='1234'
   export DESCRIPTION='Your Public IP'
   ```

   **Option B: .env File** (recommended)

   ```bash
   # Copy the example file and edit with your values
   cd ovh_allowlist
   cp .env.example .env
   vim .env
   ```

### Configuration

All configuration is now handled through environment variables or the `.env` file. No script editing required!

**Required variables:**

- `SERVICE_NAME` - Your OVH service name (e.g., pcc-xxx-xx-xx-xx)
- `NETWORK_ACCESS_ID` - Existing allowlist entry ID to update
- `DESCRIPTION` - Description for the allowlist entry

The easiest way is to copy `ovh_allowlist/.env.example` to `ovh_allowlist/.env` and fill in your values.

### Usage

```bash
# Run the script
cd ovh_allowlist && ./ovh_allowlist.sh
```

The script will:

1. Get your current public IP automatically
2. Update the existing OVH allowlist entry
3. Show success confirmation or error details

### API Details

- **Endpoint**: `/dedicatedCloud/{serviceName}/allowedNetwork/{networkAccessId}`
- **Method**: PUT
- **Authentication**: OVH 3-key system (Application Key + Secret + Consumer Key)
- **Body**: Updates network field with current IP in CIDR notation (/32)

## 📄 License

MIT License - feel free to use and modify!
