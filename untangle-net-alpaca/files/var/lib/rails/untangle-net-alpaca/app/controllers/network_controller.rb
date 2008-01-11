class NetworkController < ApplicationController
  UpdateInterfaces = "update_interfaces"
  def index
    ## Cannot use this panel in advanced mode.
    if ( @config_level > AlpacaSettings::Level::Basic )
      return redirect_to( :controller => 'interface', :action => 'list' )
    end

    manage
    render :action => 'manage'
  end

  ## Basic mode networking configuration
  def manage
    ## Cannot use this panel in advanced mode.
    if ( @config_level > AlpacaSettings::Level::Basic )
      return redirect_to( :controller => 'interface', :action => 'list' )
    end
    
    @interface_list = Interface.find( :all )

    if ( @interface_list.nil? || @interface_list.empty? )
      @interface_list = InterfaceHelper.loadInterfaces
      ## Save all of the new interfaces
      @interface_list.each { |interface| interface.save }      
    end
    
    @interface_list.sort! { |a,b| a.index <=> b.index }
    
    @config_list = @interface_list.map do |interface|
      @dhcp_status = os["dhcp_manager"].get_dhcp_status( interface ) if interface.wan
      NetworkHelper.build_interface_config( interface, @interface_list )
    end

    ## This should be in a global place
    @cidr_options = OSLibrary::NetworkManager::CIDR.map { |k,v| [ format( "%-3s %s", k, v ) , k ] }
    @cidr_options.sort! { |a,b| a[1].to_i <=> b[1].to_i }    
  end

  def save
    return redirect_to( :action => 'manage' ) unless ( params[:commit] == "Save" )
    
    ## Retrieve all of the interfaces
    interface_list = params[:interface_list]

    interface_id_list = params[:interface_id_list]

    ## Convert the interface ids to numbers
    interface_id_list = interface_id_list.map do |interface_id|
      i = interface_id.to_i
      return redirect_to( :action => 'fail_0' ) if i.to_s != interface_id
      i
    end

    ## Verify the list exists.
      return redirect_to( :action => 'fail_1' ) if interface_list.nil?
    
    ## Verify the list lines up with the existing interfaces
    interfaces = Interface.find( :all )

    ## Verify the list matches.
    return redirect_to( :action => 'fail_2' ) if ( interfaces.size != interface_list.size )

    interface_map = {}
    interfaces = interfaces.each{ |interface| interface_map[interface.id] = interface }
    
    ## Verify every id is represented
    interface_id_list.each do |interface_id|
      return redirect_to( :action => 'fail_4' ) if interface_map[interface_id].nil?
    end

    ## This is where it gets a little hairy, because it should verify all
    ## interfaces, and then save, for now it is saving interfaces as it goes.
    [ interface_list, interface_id_list ].transpose.each do |panel_id, interface_id| 
      config_type = params["config_type_#{panel_id}"]

      interface = interface_map[interface_id]

      case config_type
      when InterfaceHelper::ConfigType::STATIC then static( interface, panel_id )
      when InterfaceHelper::ConfigType::DYNAMIC then dynamic( interface, panel_id )
      when InterfaceHelper::ConfigType::BRIDGE then bridge( interface, panel_id )
      when InterfaceHelper::ConfigType::PPPOE then pppoe( interface, panel_id )
      ## REVIEW : Move this into the validation part
      else raise "Unknown configuration type #{config_type}"  
      end
    end

    spawn do
      os["network_manager"].commit
    end
    
    return redirect_to( :action => 'manage' )
  end

  ## These are the aliases for the external interface.
  def aliases
    ## Index is a reserved word, so the column name must be quoted.
    conditions = [ "\"index\" = ?", InterfaceHelper::ExternalIndex ]
    external_interface = Interface.find( :first, :conditions => conditions )
    
    if external_interface
      @external_aliases, @msg = external_interface.visit_config( AliasVisitor.new )
    else 
      @external_aliases = []
      @msg = "There presently isn't an external interface."
    end
    
    logger.debug( "Found the aliases: '#{@external_aliases}'" )
    @external_aliases.each { |a| logger.debug( "Found the aliases: '#{a}'" ) }
  end

  def create_ip_network
    @list_id = params[:list_id]
    raise "no row id" if @list_id.nil?
    raise "invalid list id  #{@list_id} syntax" if @list_id != "external-aliases"

    ## Review : How to set defaults
    @ip_network = IpNetwork.new
    @ip_network.ip = "1.2.3.4"
    @ip_network.netmask = "24"
    @ip_network.allow_ping = true
  end

  def save_aliases
    return redirect_to( :action => 'aliases' ) unless ( params[:commit] == "Save" )

    ## Index is a reserved word, so the column name must be quoted.
    conditions = [ "\"index\" = ?", InterfaceHelper::ExternalIndex ]
    external_interface = Interface.find( :first, :conditions => conditions )
    
    @msg = nil
    if external_interface
      current_config = external_interface.current_config

      static = external_interface.intf_static
      if static.nil?
        static = IntfStatic.new 
        external_interface.intf_static = static
      end      

      dynamic = external_interface.intf_dynamic
      if dynamic.nil?
        dynamic = IntfDynamic.new 
        external_interface.intf_dynamic = dynamic
      end

      pppoe = external_interface.intf_pppoe
      if pppoe.nil?
        pppoe = IntfPppoe.new 
        external_interface.intf_pppoe = pppoe
      end
      
      aliasVisitor = SaveAliasesVisitor.new( params )
      [ static, dynamic, pppoe ].each do |config|
        msg = config.accept( external_interface, aliasVisitor )
        @msg = msg if ( current_config == config )
      end
    else 
      @msg = "There presently isn't an external interface."
    end
    
    ## Show the error page unless the message is non-nil.
    return unless @msg.nil?
    
    spawn do
      os["network_manager"].commit
    end

    return redirect_to( :action => 'aliases' )
  end

  def refresh_interfaces
    @new_interfaces, @deleted_interfaces = InterfaceHelper.load_new_interfaces
  end

  def commit_interfaces
    ## Ignore if they hit cancel
    return redirect_to( :action => 'manage' ) unless ( params[:commit] == "Save" )
    
    new_interfaces, deleted_interfaces = InterfaceHelper.load_new_interfaces

    new_interface_list = params[:new_interfaces]
    deleted_interface_list = params[:deleted_interfaces]

    new_interface_list = [] if new_interface_list.nil?
    deleted_interface_list = [] if deleted_interface_list.nil?

    if ( new_interface_list.size != new_interfaces.size || 
         deleted_interface_list.size != deleted_interfaces.size )
      return redirect_to( :action => 'refresh_interfaces' ) 
    end

    ## Verify that the new and deleted interfaces line up.
    ma = {}
    new_interface_list.each { |i| ma[i] = true }
    logger.debug( "ma : #{ma}" )
    new_interfaces.each do |i|
      return redirect_to( :action => 'refresh_interfaces' )  unless ma[i.mac_address] == true
    end

    ma = {}
    logger.debug( "ma : #{ma}" )
    deleted_interface_list.each { |i| ma[i] = true }
    deleted_interfaces.each do |i|
      return redirect_to( :action => 'refresh_interfaces' )  unless ma[i.mac_address] == true
    end
    
    ## Destroy the interfaces to be deleted.
    deleted_interfaces.each { |i| i.destroy }
    
    ## Save the interfaces that are 
    new_interfaces.each{ |i| i.save }
    
    ## Iterate all of the helpers telling them about the new interfaces
    iterate_components do |component|
      next unless component.respond_to?( UpdateInterfaces )
      component.send( UpdateInterfaces, Interface.find( :all ))
    end

    ## Redirect them to the manage page.
    return redirect_to( :action => 'manage' )
  end

  def scripts
    [ "network" ]
  end

  #def stylesheets
  #  [ "borax/list-table", "borax/network" ]
  #end

  private

  class AliasVisitor < Interface::ConfigVisitor
    def intf_static( interface, config )
      ## Create a copy of the array.
      aliases = [ config.ip_networks ].flatten

      ## Delete the alias at the first position from the list
      aliases.delete_if { |a| a.position == 1 }
      [ aliases, nil ]
    end

    def intf_dynamic( interface, config )
      [ config.ip_networks, nil ]
    end

    def intf_bridge( interface, config )
      [ nil, "External Interface is presently configured as a bridge" ]
    end

    def intf_pppoe( interface, config )
      ## Review : We currently support this.
      [ nil, "External Interface is presently configured for PPPoE" ]
    end
  end

  class SaveAliasesVisitor < Interface::ConfigVisitor
    def initialize( params )
      @params = params
    end

    def intf_static( interface, config )
      ## Create the ip_network list, starting with position 2
      ip_networks = ip_network_list( 2 )
      external = config.ip_networks[0]
      if external.nil?
        config.ip_networks = ip_networks
      else
        ## Put it at the beginning
        config.ip_networks = [ external ] + ip_networks 
      end
      
      nil
    end

    def intf_dynamic( interface, config )
      config.ip_networks = ip_network_list( 1 )

      nil
    end

    def intf_bridge( interface, config )
      "External Interface is presently configured as a bridge"
    end

    def intf_pppoe( interface, config )
      ## Review : We currently support this.
      "External Interface is presently configured for PPPoE"
    end

    private
    def ip_network_list( position )
      ## save the networks
      networkStringHash = @params[:networks]
      ## indices is used to guarantee they are done in proper order.
      indices = @params[:networkIndices]
      
      ip_networks = []
      unless indices.nil?
        indices.each do |key,value|
          network = IpNetwork.new
          network.parseNetwork( networkStringHash[key] )
          network.position, position = position, position + 1
          ip_networks << network
        end
      end
      
      ip_networks
    end
  end

  def static( interface, panel_id )
    static = interface.intf_static
    static = IntfStatic.new if static.nil?
    
    network = static.ip_networks[0]

    ## There isn't a first one, need to create a new one
    if network.nil?
      network = IpNetwork.new( :allow_ping => true, :position => 1 )
      network.parseNetwork( "#{params["#{panel_id}_static_ip"]}/#{params["#{panel_id}_static_netmask"]}" )
      static.ip_networks = [ network ]
    elsif ( network.position == 1 )
      ## Replace the one that is there
      network.ip = params["#{panel_id}_static_ip"]
      network.netmask = params["#{panel_id}_static_netmask"]
      network.allow_ping = true
      network.save
    else
      ## The first one doesn't exist, need to insert one at the beginning
      network = IpNetwork.new( :allow_ping => true, :position => 1 )
      network.parseNetwork( "#{params["#{panel_id}_static_ip"]}/#{params["#{panel_id}_static_netmask"]}" )
      static.ip_networks << network
    end
    
    if interface.wan
      ## Set the default gateway and dns
      static.default_gateway = params["#{panel_id}_static_default_gateway"]
      static.dns_1 = params["#{panel_id}_static_dns_1"]
      static.dns_2 = params["#{panel_id}_static_dns_2"]
    else
      ## Add a NAT policy (this not the external interface)
      natPolicy = NatPolicy.new
      natPolicy.ip = "0.0.0.0"
      natPolicy.netmask = "0"
      natPolicy.new_source = "auto"
      static.nat_policies = [ natPolicy ]
    end

    static.save
    interface.config_type = InterfaceHelper::ConfigType::STATIC
    interface.intf_static = static
    interface.save
  end

  def bridge( interface, panel_id )
    bridge = interface.intf_bridge
    bridge = IntfBridge.new if bridge.nil?

    bridge_id = params["#{panel_id}_bridge_interface"]
    return logger.warn( "Bridge interface is not specified" ) if bridge_id.nil?

    bridge_interface = Interface.find( bridge_id )
    return logger.warn( "Unable to find the interface '#{bridge_id}'" ) if bridge_interface.nil?

    bridge.bridge_interface = bridge_interface
    bridge_interface.bridged_interfaces << bridge
    
    interface.intf_bridge = bridge
    interface.config_type = InterfaceHelper::ConfigType::BRIDGE
    interface.save
  end

  def dynamic( interface, panel_id )
    dynamic = interface.intf_dynamic
    dynamic = IntfDynamic.new if dynamic.nil?
    dynamic.allow_ping = true

    dynamic.ip = nil
    dynamic.netmask = nil
    dynamic.default_gateway = nil
    dynamic.dns_1 = nil
    dynamic.dns_2 = nil

    dynamic.save
    interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
    interface.intf_dynamic = dynamic
    interface.save    
  end

  def pppoe( interface, panel_id )
    pppoe = interface.intf_pppoe
    pppoe = IntfPppoe.new if pppoe.nil?
    pppoe.username = params["#{panel_id}_pppoe_username"]
    pppoe.password = params["#{panel_id}_pppoe_password"]
    pppoe.use_peer_dns = params["#{panel_id}_pppoe_use_peer_dns"]
    pppoe.dns_1 = params["#{panel_id}_dns_1"]
    pppoe.dns_2 = params["#{panel_id}_dns_2"]
    pppoe.save
    interface.config_type = InterfaceHelper::ConfigType::PPPOE
    interface.intf_pppoe = pppoe
    interface.save
  end
end
