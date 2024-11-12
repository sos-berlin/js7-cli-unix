# js7-cli-unix
Unix Shell CLI for JS7 REST Web Service API

* The JS7 offers the [JS7 - Unix Shell Command Line Interface](https://kb.sos-berlin.com/display/JS7/JS7+-+Unix+Shell+Command+Line+Interface).
* The JS7 offers to perform operations on Controllers and Agents, orders, workflows, jobs and related objects by the [JS7 - REST Web Service API](https://kb.sos-berlin.com/display/JS7/JS7+-+REST+Web+Service+API).
    * For detailed information see the [Technical Documentation of the REST Web Service API](https://www.sos-berlin.com/JOC/latest/raml-doc/JOC-API/index.html).
* Controller Deployment
    * Initial Operation: register, unregister
    * Agent Management: store, delete, deploy, revoke
* Controller Status Operations
    * Controller Operations: terminate, restart, cancel
    * Agent Operations: enable, disable, reset
    * Cluster Operations on Controller and Agents: switch-over
* Workflow Deployment
    * Objects: export, import, deploy, release, store, remove
    * Trash: restore, delete
* Workflow Status Operations
    * Orders: add, cancel, suspend, resume, let run, transfer
    * Workflows: suspend, resume
    * Jobs and Instructions: stop, unstop, skip, unskip
    * Notices: post, get, delete
* JOC Cockpit Status Operations
    * status, status-agent, health-check, version
    * switch-over, restart service, run service
    * check license, get settings, store settings
* Identity Service Deployment
    * Identity Services: store, rename, remove
    * Roles: store, rename, remove
    * Permissions: set, rename, remove
    * Folder Permissions: set, rename, remove
    * Accounts: store, remove, set/reset password, enable, disable, block, unblock
