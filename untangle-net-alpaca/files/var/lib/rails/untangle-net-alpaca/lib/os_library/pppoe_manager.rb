#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
class OSLibrary::PppoeManager < Alpaca::OS::ManagerBase
  include Singleton

  ## xxx presently only support one connection xxx
  ProviderName = "connection0"
  PeersFile = "/etc/ppp/peers/#{ProviderName}"
  PapSecretsFile = "/etc/ppp/pap-secrets"


  def register_hooks
    os["network_manager"].register_hook( -100, "pppoe_manager", "write_files", :hook_write_files )
  end
  
  def hook_write_files
    ## Find the WAN interface that is configured for PPPoE.
    ## xxx presently PPPoE is only supported on the WAN interface xxx
    conditions = [ "wan=? and config_type=?", true, InterfaceHelper::ConfigType::PPPOE ]
    wan_interface = Interface.find( :first, :conditions => conditions )
    
    ## No PPPoE interface is available.
    return if wan_interface.nil?

    ## Retrieve the pppoe settings from the wan interface
    settings = wan_interface.current_config

    ## Verify that the settings are actually available.
    return if settings.nil? || !settings.is_a?( IntfPppoe )
    
    cfg = []
    secrets = []

    cfg << <<EOF
#{header}
noipdefault
hide-password
noauth
persist
EOF

    cfg << "defaultroute"
    cfg << "replacedefaultroute"
    cfg << "usepeerdns" if ( settings.use_peer_dns )

    os_name = wan_interface.os_name
    ## xxxx refactor this code because it is duplicated in the network manager. xxx #
    os_name = "br.#{os_name}" if wan_interface.is_bridge?

    ## Use the PPPoE daemon and the corrent interface.
    cfg << "plugin rp-pppoe.so #{os_name}"

    ## Append the username
    cfg << "user \"#{settings.username}\""

    ## Append anything that is inside of the secret field for the PPPoE Configuration
    cfg << settings.secret_field

    secrets << "\"#{settings.username}\" *  \"#{settings.password}\""   
  
    ## This limits us to one connection, hardcoding to 0 for now.
    os["override_manager"].write_file( PeersFile, cfg.join( "\n" ), "\n" )
    os["override_manager"].write_file( PapSecretsFile, header, "\n", secrets.join( "\n" ), "\n" )
  end
  
  def header
    <<EOF
## #{Time.new}
## Auto Generated by the Untangle Net Alpaca
## If you modify this file manually, your changes
## may be overriden
EOF
  end
end
