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
module QosHelper
  class QosTableModel < Alpaca::Table::TableModel
    include Singleton
    Priorities = [[ "High", "30" ],
                  [ "Normal", "20" ],
                  [ "Low", "10" ]]
    PRIORITY = { 10 => "LOWPRIO", 20 => "MIDPRIO", 30 => "HIGHPRIO" }


    def initialize
      columns = []

      columns << Alpaca::Table::DragColumn.new

      columns << Alpaca::Table::Column.new( "enabled", "On".t ) do |qos,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "qoss[]", row_id )}
        #{view.table_checkbox( row_id, "enabled", qos.enabled )}
EOF
      end

      columns << Alpaca::Table::Column.new( "priority", "Priority".t ) do |qos,options| 
        options[:view].select( "priority", options[:row_id], Priorities, { :selected => qos.priority } )
      end
      
      columns << Alpaca::Table::Column.new( "description", "Description".t ) do |qos,options| 
        options[:view].text_field( "description", options[:row_id], { :value => qos.description } )
      end
      
      ## This gets complicated.
      ## html_options = { "onlick" => "RuleBuilder.edit( '#{row_id}' )" }
      columns << Alpaca::Table::EditColumn.new do |qos,options|
        row_id = options[:row_id]
        filter = qos.filter
        filter = "" if filter.nil?
        view = options[:view]
<<EOF
    #{view.hidden_field( "filters", row_id, { :value => filter } )}
    &nbsp;
EOF
      end

      columns << Alpaca::Table::DeleteColumn.new

      super(  "QoS Rules", "qoss", "", "qos", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="if (isClickingEnabled()) { disableClickingFor(clickTimeout); #{view.remote_function( :url => { :action => :create_qos } )} }" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def qos_table_model
    QosTableModel.instance
  end
end
