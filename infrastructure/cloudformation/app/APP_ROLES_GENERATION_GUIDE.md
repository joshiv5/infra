# Application Roles Generation Guide

## Pattern

Each application template follows this naming convention:
- Template file: `app_{appname}_roles.yaml`
- S3 Role: `cf-{appname}-s3-roles-{env}`
- EC2 Role: `cf-{appname}-ec2-roles-{env}`
- S3 Instance Profile: `cf-{appname}-s3-instance-profile-{env}`
- EC2 Instance Profile: `cf-{appname}-ec2-instance-profile-{env}`

## Current Applications (Testing)

✅ **Cumulus** - [app_cumulus_roles.yaml](app_cumulus_roles.yaml)
- `cf-cumulus-s3-roles`
- `cf-cumulus-ec2-roles`

## Next Applications to Create

You can use the cumulus template as a base. Simply:

1. Copy `app_cumulus_roles.yaml` to `app_{appname}_roles.yaml`
2. Replace all occurrences of:
   - `Cumulus` → `{AppName}` (PascalCase)
   - `cumulus` → `{appname}` (lowercase)
   - `CUMULUS` → `{APPNAME}` (if used)

## Example Applications Ready to Create

- **Retina** - `app_retina_roles.yaml`
  - `cf-retina-s3-roles`
  - `cf-retina-ec2-roles`

- **DataAPI** - `app_dataapi_roles.yaml`
  - `cf-dataapi-s3-roles`
  - `cf-dataapi-ec2-roles`

- **LeanRetina** - `app_leanretina_roles.yaml`
  - `cf-leanretina-s3-roles`
  - `cf-leanretina-ec2-roles`

## Script to Generate All Templates (Optional)

You could create a PowerShell script to generate these automatically:

```powershell
$apps = @("cumulus", "retina", "dataapi", "leanretina")
$sourceFile = "app_cumulus_roles.yaml"
$templateContent = Get-Content $sourceFile -Raw

foreach ($app in $apps) {
    $appPascal = (Get-Culture).TextInfo.ToTitleCase($app)
    $newContent = $templateContent `
        -replace "Cumulus", $appPascal `
        -replace "cumulus", $app
    
    $newFile = "app_$($app)_roles.yaml"
    Set-Content -Path $newFile -Value $newContent
    Write-Host "Created $newFile"
}
```

## Scaling to 100+ Roles

Each new application role template follows the exact same structure. The only changes needed are:
1. Application name (in 3 places: description, role names, tags)
2. File name for organization

This means you can:
- Automate generation with a script or template
- Easily maintain consistency across all roles
- Scale to any number of applications without manual effort

## Deployment

Deploy each application template independently:

```bash
aws cloudformation create-stack \
  --stack-name cf-cumulus-roles-{env} \
  --template-body file://cloudformation/app/app_cumulus_roles.yaml \
  --parameters file://configs/{env}/app_cumulus_parameters.json
```

Each template exports its outputs for reference by other stacks:
- `cf-{appname}-s3-role-arn-{env}`
- `cf-{appname}-s3-role-name-{env}`
- `cf-{appname}-ec2-role-arn-{env}`
- `cf-{appname}-ec2-role-name-{env}`
