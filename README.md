# 💾 Backups — ManageIQ Automate Domain

The **Backups** repository contains a ManageIQ **Automate domain** and related artifacts for backup and restore workflows. The content is maintained as code and can be synchronized with a ManageIQ environment using `rake` tasks.

---

## 🚀 Overview

### 📦 What's included
- 🧩 **Automate code** — `Backups/`
- 🗂️ **Service dialogs** — `service_dialogs/`
- 🧷 **Custom buttons** — `custom_buttons/`
- 🧱 **Generic objects** — `generic_object_definitions/`
- 🕒 **Schedules** — `schedules/`

---

## ✅ Requirements

- A running **ManageIQ** environment.
- Access to the ManageIQ Rails app directory (typically `vmdb`) with `rake` available.
- Repository content present on the target system (copied or mounted).
- The filesystem paths in commands below are **examples** and may differ in your environment.

---

## ⚙️ Import to environment

Import the **Automate domain** from this repository into ManageIQ:

```bash
cd /var/www/miq/vmdb
rake evm:automate:import DOMAIN=Backups IMPORT_DIR=/opt/manageiq/automation/backups OVERWRITE=true ENABLED=true PREVIEW=false
```

> `PREVIEW=false` applies the import (ManageIQ defaults to preview-only import when `PREVIEW` is not set). This command imports only the Automate domain (`Backups/`). Import related artifacts as needed:

### 🗂️ Service dialogs

```bash
cd /var/www/miq/vmdb
rake evm:import:service_dialogs -- --source=/opt/manageiq/automation/backups/service_dialogs
```

### 🧷 Custom buttons

```bash
cd /var/www/miq/vmdb
rake evm:import:custom_buttons -- --source=/opt/manageiq/automation/backups/custom_buttons
```

### 🧱 Generic object definitions

```bash
cd /var/www/miq/vmdb
rake evm:import:generic_object_definitions -- --source=/opt/manageiq/automation/backups/generic_object_definitions
```

### 🕒 Schedules

```bash
cd /var/www/miq/vmdb
rake evm:import:schedules -- --source=/opt/manageiq/automation/backups/schedules
```

---

## 📤 Export from environment back to repository

Export the **Automate domain** from ManageIQ back into this repository:

```bash
# Export may leave old files for renamed instances/methods — clean the domain folder first.
cd /opt/manageiq/automation/backups
rm -rf Backups

cd /var/www/miq/vmdb
rake evm:automate:export DOMAIN=Backups EXPORT_DIR=/opt/manageiq/automation/backups
```

> The sections below show how to export related artifacts into this repository. Review and commit changes carefully.

### 🗂️ Service dialogs

```bash
rake evm:export:service_dialogs -- --directory=/opt/manageiq/automation/backups/service_dialogs
```

> Note: this task may export dialogs not related to this domain. Review changes and commit only what is intended.

### 🧷 Custom buttons

```bash
cd /var/www/miq/vmdb
rake evm:export:custom_buttons -- --directory=/opt/manageiq/automation/backups/custom_buttons
```

### 🧱 Generic object definitions

```bash
cd /var/www/miq/vmdb
rake evm:export:generic_object_definitions -- --directory=/opt/manageiq/automation/backups/generic_object_definitions
```

> Note: this task exports **all** generic object definitions from the environment. Commit only what belongs in this repository.

### 🕒 Schedules

```bash
cd /var/www/miq/vmdb
rake evm:export:schedules -- --directory=/opt/manageiq/automation/backups/schedules
```

#### ⚠️ Important note

Several export tasks can dump **many or all** definitions from your ManageIQ environment (not only objects for this domain). Recommended workflow:

1. Do not run `git add .`
2. Stage and commit only the files you intend to keep
3. If needed, delete unrelated files under the export directory, then restore tracked files: `git restore <path>`

---

## 📄 License

This project is licensed under the MIT License. See [`LICENSE`](./LICENSE).
