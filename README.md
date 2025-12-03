# Backups Automation Package

Automation package `Backups` consists of:

 - Automation Code
 - Service Dialog
 - Custom Buttons (with attached Service Dialog)
 - GenericObject Definition

# HowTo: Import automation package to DEV environment

### Automation Code

```bash
cd /var/www/miq/vmdb
rake evm:automate:import DOMAIN=Backups IMPORT_DIR=/opt/manageiq/automation/backups OVERWRITE=true ENABLED=true PREVIEW=false
```



# HowTo: Export automation package from DEV environment into repository

### Automation Code

```bash
# Remove old template provisioning, as export leaves old files for renamed instances and methods in repository.
cd /opt/manageiq/automation/backups
rm -rf Backups

# Import new
cd /var/www/miq/vmdb
rake evm:automate:export DOMAIN=Backups EXPORT_DIR=/opt/manageiq/automation/backups
```

### Service dialogs

```bash
rake evm:export:service_dialogs -- --directory=/opt/manageiq/automation/backups/service_dialogs
```

As it exports all dialogs DO NOT `git add` all dialogs:

1. DO NOT USE `git add .`
2. add and commit only required dialogs
3. remove not related files: `rm -rf service_dialogs/*`
4. git restore required files: `git restore sevice_dialogs`


### GenericObject Definition

```bash
rake evm:export:generic_object_definitions -- --directory=/opt/manageiq/automation/backups/generic_object_definitions
```

As it exports all definitions:

1. DO NOT USE `git add .`
2. add and commit only required definitions
3. remove not related files: `rm -rf generic_object_definitions/*`
4. git restore required files: `git restore generic_object_definitions`

