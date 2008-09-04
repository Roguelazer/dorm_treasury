#!/usr/bin/env ruby

require 'libglade2'
require 'treasury'

class GtkUiGlade
	include GetText

	attr :glade
  
	def initialize(treasury, path_or_data, root = nil, domain = nil, localedir = nil, flag = GladeXML::FILE)
		@treasury = treasury
		bindtextdomain(domain, localedir, nil, "UTF-8")
		@glade = GladeXML.new(path_or_data, root, domain, localedir, flag) {|handler| method(handler)}
		@listmodel = Gtk::ListStore.new(Integer, String, String, Float)
		populate_list_box
		@allocationslist = @glade.get_widget("allocationsTV")
		@allocationslist.model = @listmodel
		initialize_columns
	end

	def on_quit
		Gtk::main_quit
	end

	def on_btnNewAllocation_clicked

	end

	def populate_list_box
		@treasury.allocations {|a|
			newrow = @listmodel.append
			newrow[0] = a.allocid
			newrow[1] = a.date.to_s
			newrow[2] = a.name
			newrow[3] = a.amount
		}
	end

	def initialize_columns
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Allocation ID", renderer, :text => 0)
		@allocationslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Date", renderer, :text => 1)
		@allocationslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Title", renderer, :text => 2)
		@allocationslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Amount", renderer, :text => 3)
		@allocationslist.append_column(col)
	end
end

# Main program
if __FILE__ == $0
	# Set values as your own application. 
	PROG_PATH = "gtk_ui.glade"
	PROG_NAME = "YOUR_APPLICATION_NAME"
	treasury = Treasury.new(ARGV[0])
	GtkUiGlade.new(treasury, PROG_PATH, nil, PROG_NAME)
	Gtk.main
end
