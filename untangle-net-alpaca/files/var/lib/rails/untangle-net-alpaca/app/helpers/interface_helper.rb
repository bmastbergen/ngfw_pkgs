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
require "ipaddr"

module InterfaceHelper
  ExternalIndex = 1
  InternalIndex = 2
  DmzIndex = 3

  ## DDD These are subject to internationalization DDD
  ## REVIEW : These are also linux specific.
  DefaultInterfaceMapping = {
    # default Display name plus the index
    "eth0" => [ "External", ExternalIndex ],
    "eth1" => [ "Internal", InternalIndex ],
    "eth2" => [ "DMZ", DmzIndex ]
  }

  ## REVIEW :: These Strings need to be internationalized.
  class ConfigType
    STATIC="static"
    DYNAMIC="dynamic"
    BRIDGE="bridge"
    PPPOE="pppoe"
  end

  ## Array of all of the available config types
  CONFIGTYPES = [ ConfigType::STATIC, ConfigType::DYNAMIC, ConfigType::BRIDGE, ConfigType::PPPOE ].freeze

  ## An array of the config types that you can bridge with
  BRIDGEABLE_CONFIGTYPES = [ ConfigType::STATIC, ConfigType::DYNAMIC, ConfigType::PPPOE ].freeze

  ## A hash of all of the various ethernet medias
  ETHERNET_MEDIA = { "autoauto" => { :name => "Auto", :speed => "auto", :duplex => "auto" },
    "100full" => { :name => "100 Mbps, Full Duplex", :speed => "100", :duplex => "full" },
    "100half" => { :name => "100 Mbps, Half Duplex", :speed => "100", :duplex => "half" },
    "10full" => { :name => "10 Mbps, Full Duplex", :speed => "10", :duplex => "full" },
    "10half" => { :name => "10 Mbps, Half Duplex", :speed => "10", :duplex => "half" } }.freeze

  ETHERNET_MEDIA_ORDER = [ "autoauto", "100full", "100half", "10full", "10half" ]

  ## Load the new interfaces and return two arrays.
  ## first the array of new interfaces to delete.
  ## Second is the array of interfaces that should be deleted.
  ## REVIEW : this will not work if the mac address has a different case.
  def self.load_new_interfaces
    delete_interfaces = []
    new_interfaces = []

    physical_interfaces = self.loadInterfaces
    mac_addresses = {}
    existing_mac_addresses = {}
    physical_interfaces.each do |interface|
      mac_addresses[interface.mac_address] = true unless ApplicationHelper.null? interface.mac_address
    end
    
    Interface.find( :all ).each do |interface|
      ## Delete any items that are not in the list of current mac addresses.
      delete_interfaces << interface unless mac_addresses[interface.mac_address] == true

      ## Build the list of mac_addresses
      existing_mac_addresses[interface.mac_address] = true
    end

    physical_interfaces.each do |interface|
      new_interfaces << interface unless existing_mac_addresses[interface.mac_address] == true
    end

    [ new_interfaces, delete_interfaces ]
  end

  ## DDD some of this code may be debian specific DDD
  def self.loadInterfaces
    ## Create an empty array
    interfaceArray = []

    ## Find all of the physical interfaces
    currentIndex = DefaultInterfaceMapping.size

    ia = networkManager.interfaces

    raise "Unable to detect any interfaces" if ia.nil?
    
    ## True iff the list found a WAN interface.
    foundWAN = false

    ia.each do |i| 
      interface = Interface.new

      ## Save the parameters from the physical interface.
      interface.os_name, interface.mac_address, interface.bus, interface.vendor = 
        i.os_name, i.mac_address, i.bus_id, i.vendor

      parameters = DefaultInterfaceMapping[i.os_name]
      ## Use the os name if it doesn't have a predefined virtual name
      parameters = [ i.os_name, currentIndex += 1 ] if parameters.nil?
      interface.name, interface.index  = parameters

      ## default it to a static config
      interface.config_type = InterfaceHelper::ConfigType::STATIC

      if ( interface.index == 1 )
        interface.wan = true
        foundWAN = true
      else
        interface.wan = false
      end
      
      ## Add the interface.
      interfaceArray << interface
    end

    ## If it hasn't found the WAN interface, set the one with the lowest index
    ## to the WAN interface.
    interfaceArray.min { |a,b| a.index <=> b }.wan = true unless foundWAN

    interfaceArray
  end

  def self.networkManager
    Alpaca::OS.current_os["network_manager"]
  end

  class IPNetworkTableModel < Alpaca::Table::TableModel
    def initialize( table_name="IP Addresses" )
      if table_name.nil?
        table_name = "IP Addresses"
      end
      columns = []
      columns << Alpaca::Table::Column.new( "ip-network", "Address and Netmask".t ) do |ip_network,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "networkIndices[]", row_id )}
        #{view.text_field( "networks", options[:row_id], { :value => "#{ip_network.ip} / #{ip_network.netmask}" } )}
EOF
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  table_name, "ip_networks", "", "ip_network", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_ip_network, :list_id => table_data.css_id } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def ip_network_table_model(table_name="IP Addresses")
    IPNetworkTableModel.new(table_name)
  end

  class NatTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "ip-address", "Address and Netmask".t ) do |nat,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "natIndices[]", row_id )}
        #{view.text_field( "natNetworks", options[:row_id], { :value => "#{nat.ip} / #{nat.netmask}" } )}
EOF
      end
      
      columns << Alpaca::Table::Column.new( "new-source", "Source Address".t ) do |nat,options| 
        options[:view].text_field( "natNewSources", options[:row_id], { :value => "#{nat.new_source}" } )
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "NAT Policies", "nats", "", "nat", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_nat_policy, :list_id => table_data.css_id } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def nat_table_model
    NatTableModel.instance
  end

  def ethernet_media_select( interface )
    media = "#{interface.speed}#{interface.duplex}"
    media = "autoauto" if ETHERNET_MEDIA[media].nil?

    ## this is to enforce order, yes it is kind of shady.
    options = ETHERNET_MEDIA_ORDER.map { |m| [ ETHERNET_MEDIA[m][:name], m ] }

    select_tag( "ethernet_media", options_for_select( options, media ))
  end

  ## Given a ethernet media string, this will return the speed and duplex setting
  def self.get_speed_duplex( media )
    v = ETHERNET_MEDIA[media]
    v = ETHERNET_MEDIA["autoauto"] if v.nil?
    [ v[:speed], v[:duplex]]
  end
end
