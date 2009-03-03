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
class OSLibrary::DdclientManager < Alpaca::OS::ManagerBase
  include Singleton

  ConfigFile = "/etc/ddclient.conf"

  ConfigDaemon = "daemon_interval"
  ConfigRunDaemon = "run_daemon"
  ConfigProtocol = "protocol"
  ConfigLogin = "login"
  ConfigPassword = "password"
  ConfigServer = "server"
  ConfigPid = "pid"
  ConfigUse = "use"

  ConfigDaemonInterval = "300"

  ConfigService = {
    "ZoneEdit" => [ "zoneedit1", "dynamic.zoneedit.com" ],
    "EasyDNS" => [ "easydns", "members.easydns.com" ],
    "DSL-Reports" => [ "dslreports1", "www.dslreports.com" ],
    "DNSPark" => [ "dnspark", "www.dnspark.com" ],
    "Namecheap" => [ "namecheap", "dynamicdns.park-your-domain.com" ],
    "DynDNS" => [ "dyndns2", "members.dyndns.org" ]
  }

  DdclientRcdDefaults = "/usr/sbin/update-rc.d ddclient defaults"
  DdclientRcdRemove   = "/usr/sbin/update-rc.d -f ddclient remove"
  DdclientCmd         = "/etc/init.d/ddclient "
  DdclientCmdStop     = DdclientCmd + " stop"
  DdclientCmdRestart  = DdclientCmd + " restart"
  DdclientConfFile    = "/etc/ddclient.conf"
  DdclientDefaultFile = "/etc/default/ddclient"
  DdclientPidFile     = "/var/run/ddclient.pid"

  DdclientPackage = "ddclient"

  def register_hooks
    os["network_manager"].register_hook( -100, "ddclient_manager", "write_files", :hook_commit )
    os["hostname_manager"].register_hook( 100, "ddclient_manager", "commit", :hook_commit )
  end
  
  def hook_commit
    settings = DdclientSettings.find( :first )

    if ( !settings.nil? && settings.enabled )
        commit_ddclient( settings )
    else
      disable_ddclient
    end
  end

  def commit_ddclient( settings )
    cfg = []
    defaults = []
    
    if ( settings.enabled )
      ## Guard against the NULL Pointer exception
      service = ConfigService[settings.service]

      if service.nil?
        logger.warn( "The service: #{settings.service} is not valid." )
        return
      end

      protocol = service[0]
      server = service[1]
      key = os["uvm_manager"].activation_key()
      use = "web, web=www.untangle.com/ddclient/ip.php?activation=#{key}, web-skip=''"
      if server.include?( 'dyndns.org' )
	use = "web, web=checkip.dyndns.com/, web-skip='IP Address'"  
      end
      [ [ ConfigPid, DdclientPidFile ],
        [ ConfigUse, use ],
        [ ConfigProtocol, protocol ],
        [ ConfigLogin, settings.login ],
        [ ConfigPassword, settings.password ],
        [ ConfigServer, server + ' ' +settings.hostname ]
      ].each do |var,val|
        next if ( val.nil? || val == "null" )
        cfg << "#{var}=#{val}"
      end

      [ [ ConfigDaemon, ConfigDaemonInterval ],
        [ ConfigRunDaemon, settings.enabled ]
        ].each do |var,val|
        next if ( val.nil? || val == "null" )
        defaults << "#{var}=\"#{val}\""
      end
    end
    
    
    #logger.debug( "running: " + DdclientCmdStop )
    run_command( DdclientCmdStop  )
    os["override_manager"].write_file( ConfigFile, header, "\n", cfg.join( "\n" ), "\n" )
    os["override_manager"].write_file( DdclientDefaultFile, header, "\n", defaults.join( "\n" ), "\n" )
    if ( settings.enabled )
      #logger.debug( "running: " + DdclientRcdDefaults )
      run_command( DdclientRcdDefaults )
      #logger.debug( "running: " + DdclientCmdRestart )
      run_command( DdclientCmdRestart )
    end

    #run_command( "hostname #{settings.hostname}" )
  end

  def disable_ddclient
    run_command( DdclientRcdRemove )
    run_command( DdclientCmdStop )
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
