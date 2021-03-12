# HelloID-Conn-Prov-Source-PowerSchool-SIS-Students
<p align="center">
  <img src="Assets/Logo.png">
</p>
HelloID Provisioning Source Connector for PowerSchool SIS


<!-- TABLE OF CONTENTS -->
## Table of Contents
* [Getting Started](#getting-started)
* [Setting up the API access](#setting-up-the-api-access)
* [Configuration](#configuration)

<!-- GETTING STARTED -->
## Getting Started
By using this connector you will have the ability to import powerschool data into HelloID:

* Student Demographics
* Student School Enrollments

## Setting up the API Access
- Click System Settings. The System Settings page appears.
- Click Plugin Management Configuration. The Plugin Management Dashboard page appears.
- Click Install. The Plugin Install page appears.
- For the Plugin Installation File, see  [Tools4ever_plugin.zip](Assets/Tools4ever_plugin.zip)
- Click Install. A confirmation message appears. The plugin appears in the Installed Plugins section on the Plugin Management Dashboard page.
- Retrieve Client ID and Secret

## Setup the PowerShell connector
1. Add a new 'Source System' to HelloID and make sure to import all the necessary files.

    - [ ] configuration.json
    - [ ] person.ps1
    - [ ] department.ps1

2. Fill in the required fields on the 'Configuration' tab. See also, [Setting up the API access](#setting-up-the-api-access)

![image](Assets/config.png)
* Base URI
* Client Key
* Client Secret
* Expansion
* Extensions
* Filter

_For more information about our HelloID PowerShell connectors, please refer to our general [Documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) page_