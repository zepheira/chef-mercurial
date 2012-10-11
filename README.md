chef-mercurial
==============

Installs the Mercurial source control system and provides a provider and a resource fully compatible with the Deploy resource.

Requirements
============

A package named "mercurial" must exist in the platform package management system. Currently supports special flags for Mercurial > 2.0

Usage
=====

Install mercurial to make sure it is available to check out code from mercurial repositories.

Resource/Provider
=================

This cookbook includes a resource and a provider class, 100% compatible with the Deploy resource, so that you can use it in your CI deployment scenarios with Chef.

## Actions

- `checkout`: This will simply issue a clone of the repository at the revision specified (default tip). You can specify a named branch by setting branch(true)
- `sync`: This will issue a clone of the repository if there is nothing at the path specified, otherwise a pull and update will be issued to bring the directory up-to-date.
- `export`:  This is remove any Mercurial medata present in the codebase for various purposes (code shipping etc). The codebase will then no longer be a valid Mercurial tree.

## Attributes

- `path`: Path where the repository is checked out. This is the **name attribute** 
- `repository`: The repository to check out. Currently supported are: ssh, http and https
- `revision`: The revision you want checked out
- `branch`: True if the revision you specified refers to a named branch
- `owner`: Local user that the clone is run as
- `group`: Local group that the clone is run as
- `ssh_key`: Path to a private key on disk to use, for private repositories. The key file must already exist
- `ssh_ignore`: Sets the --insecure flag on mercurial in order to ignore SSH key inconsistencies while checking out. Available only on recent Mercurial versions
- `ssh_wrapper`: Sets the ssh wrapper (-e command line option) for the SSH commands of Mercurial. Provide a full SSH command, if applicable (i.e. ssh -o Compression=true)

## Example

	mercurial "/home/deploy/project" do
		repository "ssh://hg@bitbucket.org/deploy/project"
		ssh_key "/home/deploy/.ssh/id_rsa"
		ssh_ignore true
		branch true
		revision "production"
		user "deploy"
		group "deploy"
		action :sync
	end

License and Author
==================

Author:: Joshua Timberman <joshua@opscode.com>
Author:: Panagiotis Papadomitsos <pj@ezgr.net>

Copyright:: 2009, Opscode, Inc
Copyright:: 2012, Panagiotis Papadomitsos

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
