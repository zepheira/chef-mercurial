#
# Author:: Panagiotis Papadomitsos (<pj@ezgr.net>)
#
# Copyright:: Copyright (c) 2012 Panagiotis Papadomitsos
# License:: Apache License, Version 2.0
#
# Based on Opscode's original Git SCM library
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef/resource/scm"

class Chef
    class Resource
        class Mercurial < Chef::Resource::Scm

            def initialize(name, run_context=nil)
                super(name, run_context)
                @resource_name = :mercurial
                @ssh_ignore = false
                @ssh_key = ''
                @branch = true
                @revision = 'default'
                @provider = Chef::Provider::Mercurial
            end

            def ssh_ignore(arg=nil)
                set_or_return(:ssh_ignore, arg, :kind_of => [ FalseClass, TrueClass ])                
            end

            def ssh_key(arg=nil)
                set_or_return(:ssh_key, arg, :kind_of => String) 
            end

            def branch(arg=nil)
                set_or_return(:branch, arg, :kind_of => [ FalseClass, TrueClass ])                
            end

            alias :reference :revision
            alias :repo :repository

        end
    end
end
