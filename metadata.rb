name              "mercurial"
maintainer        "Opscode, Inc."
maintainer_email  "cookbooks@opscode.com"
license           "Apache 2.0"
description       "Installs mercurial"
version           "1.0.1"

recipe "mercurial", "Installs mercurial"

%w{ debian ubuntu centos redhat fedora }.each do |os|
  supports os
end
