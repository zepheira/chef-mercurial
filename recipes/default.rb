#
# Cookbook Name:: mercurial
# Recipe:: default
#
# Copyright 2009, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

platform = node["platform"]
version = node["platform_version"].split(".")

# Give 10.04 access to more modern Mercurial.  Get rid of all but 'package'
# line when 10.04 is no longer an issue.
if platform.eql?("ubuntu") && version[0].eql?("10") && version[1].eql?("04")
  apt_repository "mercurial-ppa" do
    uri "http://ppa.launchpad.net/mercurial-ppa/releases/ubuntu"
    distribution node["lsb"]["codename"]
    components ["main"]
    keyserver "keyserver.ubuntu.com"
    key "323293EE"
    action :add
  end
end

if platform.eql?("ubuntu")
  package "mercurial" do
    not_if "dpkg -l mercurial | grep '^ii'"
    action :install
  end

  package "mercurial" do
    only_if "dpkg -l mercurial | grep '^ii'"
    action :upgrade
  end
else
  package "mercurial"
end
