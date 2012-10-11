#
# Author:: Panagiotis Papadomitsos (<pj@ezgr.net>)
# Copyright:: Copyright (c) 2012 Panagiotis Papadomitsos
# License:: Apache License, Version 2.0
#
# Copied and modified from Opscode's Git SCM library
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/log'
require 'chef/provider'
require 'chef/mixin/shell_out'
require 'fileutils'
require 'shellwords'

class Chef
    class Provider
        class Mercurial < Chef::Provider

            include Chef::Mixin::ShellOut
            
            def whyrun_supported?
                true
            end

            def load_current_resource
                @is_branch = @new_resource.branch                
                @current_revision = find_current_revision
                @current_branch = find_current_branch
                @target_revision = find_target_revision
            end

            def define_resource_requirements
                super

                # Parent directory of the target must exist.
                requirements.assert(:checkout, :sync) do |a|
                    dirname = ::File.dirname(@new_resource.destination)
                    a.assertion { ::File.directory?(dirname) }
                    a.whyrun("Directory #{dirname} does not exist, this run will fail unless it has been previously created. Assuming it would have been created.")
                    a.failure_message(Chef::Exceptions::MissingParentDirectory,
                        "Cannot clone #{@new_resource} to #{@new_resource.destination}, the enclosing directory #{dirname} does not exist")
                end

                # If specified, the SSH key must exist
                requirements.assert(:checkout, :sync) do |a|
                    a.assertion { (! @new_resource.ssh_key.empty?) && (::File.exists?(@new_resource.ssh_key)) }
                    a.whyrun("The SSH key file you have specified (#{@new_resource.ssh_key}) does not exist! Please specifiy a valid SSH private key file.")
                    a.failure_message(Chef::Exceptions::MissingParentDirectory,
                        "The SSH key file you have specified (#{@new_resource.ssh_key}) does not exist! Please specifiy a valid SSH private key file.")
                end

                # If you don't provide a named branch, you must provide a valid revision
                requirements.assert(:checkout, :sync) do |a|
                    a.assertion { find_target_revision }
                    a.whyrun("You have specified an invalid Mercurial revision. A valid Mercurial revision should be in the form of a SHA-1 hash, tip, named branch or empty.")
                    a.failure_message(Chef::Exceptions::InvalidMercurialRevision,
                         "You have specified an invalid Mercurial revision. A valid Mercurial revision should be in the form of a SHA-1 hash, tip, named branch or empty.")
                end

                # Mercurial supports http, https and SSH transports
                requirements.assert(:all_actions) do |a|
                    a.assertion { @new_resource.repository.match(/^(ssh|https?):\/\/.+$/) }
                    a.whyrun("You have specified an invalid Mercurial repository. Currently supported repositories must begin with either ssh://, http:// or https://")
                    a.failure_message(Chef::Exceptions::InvalidMercurialRepository,
                        "You have specified an invalid Mercurial repository. Currently supported repositories must begin with either ssh://, http:// or https://")
                end
            end 

            # Sync Action
            def action_sync
                if existing_mercurial_clone?                    
                    Chef::Log.debug "Found an existing #{@new_resource.name} tree. current branch/revision: #{@current_branch}/#{@current_revision} :: target revision: #{@target_revision}#{@is_branch ? ' (named branch)' : ''}"
                    pull
                    select_branch_or_revision
                else
                    action_checkout
                end
            end

            # Clone or Checkout       
            def action_checkout
                if ((target_dir_non_existent_or_empty?) && (! existing_mercurial_clone?))
                    Chef::Log.debug "Cloning #{@new_resource} on #{@new_resource.destination}"
                    clone
                    select_branch_or_revision
                else
                    Chef::Log.debug "#{@new_resource} checkout destination #{@new_resource.destination} already exists or is a non-empty directory"
                end
            end

            alias :action_clone :action_checkout

            # Export action
            def action_export
                if (::File.exists?(::File.join(@new_resource.destination,".hg")) ||
                                ::File.exists?(::File.join(@new_resource.destination,".hgignore")))
                    converge_by("complete the export by removing HG metadata from #{@new_resource.destination} after checkout") do                    
                        FileUtils.rm_rf(::File.join(@new_resource.destination,".hg"))
                        FileUtils.rm_rf(::File.join(@new_resource.destination,".hgignore"))
                    end
                end
            end

            def clone
                Chef::Log.info "#{@new_resource} cloning repo #{@new_resource.repository} to #{@new_resource.destination}"                  
                args = []
                ssh_wrapper = 'ssh'
                ssh_wrapper = @new_resource.ssh_wrapper if @new_resource.ssh_wrapper
                ssh_wrapper += ' -o StrictHostKeyChecking=no' if @new_resource.ssh_ignore
                ssh_wrapper += " -i #{@new_resource.ssh_key}" unless @new_resource.ssh_key.empty?

                args << "-e '#{ssh_wrapper}'" unless ssh_wrapper == 'ssh'
                args << "--insecure" if (@new_resource.ssh_ignore && hg_version?.to_f >= 2.0)

                clone_cmd = "hg clone #{args.join(' ')} #{@new_resource.repository} #{Shellwords.escape @new_resource.destination}"
                shell_out!(clone_cmd, run_options(:log_level => :info))
                converge_by("clone from #{@new_resource.repository} into #{@new_resource.destination}") {}
            end

            def pull
                Chef::Log.info "#{@new_resource} fetching updates" 
                args = []
                ssh_wrapper = 'ssh'
                ssh_wrapper = @new_resource.ssh_wrapper if @new_resource.ssh_wrapper
                ssh_wrapper += ' -o StrictHostKeyChecking=no' if @new_resource.ssh_ignore
                ssh_wrapper += " -i #{@new_resource.ssh_key}" unless @new_resource.ssh_key.empty?

                args << "-e '#{ssh_wrapper}'" unless ssh_wrapper == 'ssh'
                args << "--insecure" if (@new_resource.ssh_ignore && hg_version?.to_f >= 2.0)

                fetch_command = "hg pull #{args.join(' ')} && hg revert -a -C #{@new_resource.destination}"
                shell_out!(fetch_command, run_options(:cwd => cwd))
            end

            def select_branch_or_revision
                Chef::Log.info "#{@new_resource} checked out branch/revision: #{@target_revision}"
                if @is_branch
                    shell_out!("hg checkout -C #{@target_revision}", run_options(:cwd => cwd))
                else
                    shell_out!("hg checkout -C -r #{@target_revision}", run_options(:cwd => cwd))
                end
                converge_by("#{@new_resource} checkout branch/revision: #{@target_revision}") {} if (find_target_revision(true) != @current_revision)
            end


            # Helper functions

            def existing_mercurial_clone?
                ::File.directory?(::File.join(@new_resource.destination, ".hg"))
            end

            def target_dir_non_existent_or_empty?
                !::File.directory?(@new_resource.destination) || Dir.entries(@new_resource.destination).sort == ['.','..']
            end

            def find_current_revision
                Chef::Log.debug("#{@new_resource} finding current mercurial revision")
                if ::File.directory?(::File.join(cwd, ".hg"))
                    # 255 is returned when we're not in a mercurial repo. this is fine
                    result = shell_out!('hg id -i', :cwd => cwd, :returns => [0,255]).stdout.strip.gsub('+','')
                    hg_hash?(result) ? result : nil
                else
                    nil
                end
            end

            def find_current_branch
                Chef::Log.debug("#{@new_resource} finding current mercurial branch")
                if ::File.directory?(::File.join(cwd, ".hg"))
                    # 255 is returned when we're not in a mercurial repo. this is fine
                    result = shell_out!('hg id -b', :cwd => cwd, :returns => [0,255]).stdout.strip
                end
                (result.nil? || result.empty?) ? nil : result
            end

            def find_target_revision(from_file = false)
                Chef::Log.debug("#{@new_resource} finding target mercurial revision#{' (from file)' if from_file}")  
                if from_file
                    if ::File.directory?(::File.join(cwd, ".hg"))
                        # 255 is returned when we're not in a mercurial repo. this is fine
                        result = shell_out!('hg id -i', :cwd => cwd, :returns => [0,255]).stdout.strip.gsub('+','')
                        Chef::Log.debug("#{@new_resource} found target mercurial revision#{' (from file)' if from_file} with value #{result}")
                        hg_hash?(result) ? result : nil
                    else
                        nil
                    end
                else
                    unless @is_branch
                        Chef::Log.debug("#{@new_resource} finding target mercurial revision as a normal revision")  
                        hg_hash?(@new_resource.revision) ? @new_resource.revision : 'tip'
                    else
                        Chef::Log.debug("#{@new_resource} finding target mercurial revision as a named branch")  
                        @new_resource.revision
                    end
                end
            end

            alias :revision_slug :find_target_revision

            private

            def run_options(run_opts={})
                run_opts[:user] = @new_resource.user if @new_resource.user
                run_opts[:group] = @new_resource.group if @new_resource.group
                run_opts[:log_tag] = @new_resource.to_s
                run_opts[:log_level] ||= :debug
                if run_opts[:log_level] == :info
                    if STDOUT.tty? && !Chef::Config[:daemon] && Chef::Log.info?
                        run_opts[:live_stream] = STDOUT
                    end
                end
                run_opts
            end

            def cwd
                @new_resource.destination
            end

            def hg_version?
                    version_cmd = "hg --version | head -1 | sed -re 's/.*version ([0-9\\.]+).+/\\1/g'"
                    hg_ver = shell_out!(version_cmd, run_options(:log_level => :info)).stdout.strip     
                    Chef::Log.info "Detected Mercurial version: #{hg_ver}"
                    hg_ver
            end

            def hg_hash?(string)
                (string == 'HEAD' || string == 'default' || string.match(/^[0-9a-f]{6,40}$/)) && (! string.nil?)
            end

        end
    end
end
