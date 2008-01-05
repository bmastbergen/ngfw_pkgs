class HostnameController < ApplicationController
  def manage
    @hostname_settings = HostnameSettings.find( :first )

    @hostname_settings = HostnameSettings.new if @hostname_settings.nil?
    
    if ApplicationHelper.null?( @hostname_settings.hostname )
      @hostname_settings.hostname = os["hostname_manager"].current
    end

    @ddclient_settings = DdclientSettings.find( :first )
    @ddclient_settings = DdclientSettings.new if @ddclient_settings.nil?


    ## this allows this method to be aliased.
    render :action => 'manage'
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    hostname_settings = HostnameSettings.find( :first )
    hostname_settings = HostnameSettings.new if hostname_settings.nil?
    hostname_settings.update_attributes( params[:hostname_settings] )
    hostname_settings.save
    
    ddclient_settings = DdclientSettings.find( :first )
    ddclient_settings = DdclientSettings.new if ddclient_settings.nil?
    ddclient_settings.update_attributes( params[:ddclient_settings] )
    ddclient_settings.save

    os["hostname_manager"].commit    
    os["ddclient_manager"].commit

    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end

  alias :index :manage
end
