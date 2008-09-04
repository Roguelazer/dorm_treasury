#!/usr/bin/env ruby

require 'libglade2'
require 'treasury'

class GtkUiGlade
	include GetText

	attr :glade
  
	def initialize(treasury, path_or_data, root = nil, domain = nil, localedir = nil, flag = GladeXML::FILE)
		@path = path_or_data
		@treasury = treasury
		bindtextdomain(domain, localedir, nil, "UTF-8")
		@glade = GladeXML.new(path_or_data, root, domain, localedir, flag) {|handler| method(handler)}
		@expglade = @glade
		@listmodel = Gtk::ListStore.new(Integer, String, String, Float, Float)
		populate_list_box
		@allocationslist = @glade.get_widget("allocationsTV")
		@allocationslist.selection.mode = Gtk::SELECTION_SINGLE
		@allocationslist.model = @listmodel
		initialize_columns
	end

	def on_quit
		@treasury.close
		Gtk::main_quit
	end

	def on_btnNewAllocation_clicked
		dialog = @glade.get_widget("addAllocation")
		dialog.run do |response|
			if (response == Gtk::Dialog::RESPONSE_ACCEPT)
				title = @glade.get_widget("title").text.to_s
				amount = @glade.get_widget("amount").text.to_f
				dateargs = @glade.get_widget("date").date
				date = Date.civil(dateargs[0], dateargs[1], dateargs[2])
				allocation = @treasury.add_allocation(date, title, amount)
				add_alloc_to_listmodel(allocation)
			end 
			dialog.destroy
		end
	end


	def on_btnNewExpenditure_clicked
		selection = @allocationslist.selection.selected
		if (selection.nil?)
			errordailog = Gtk::MessageDialog.new(@glade.get_widget("MainWindow"),
												 Gtk::Dialog::MODAL,
												 Gtk::MessageDialog::ERROR,
												 Gtk::MessageDialog::BUTTONS_CLOSE,
												 "No allocation selected")
			return
		else
			allocid = selection[0]
		end
		dialog = @glade.get_widget("addExpenditure")
		@glade.get_widget("AEallocid").text=allocid.to_s
		dialog.run do |response|
			if (response == Gtk::Dialog::RESPONSE_ACCEPT)
				name = @glade.get_widget("AEname").text.to_s
				amount = @glade.get_widget("AEamount").text.to_f
				dateargs = @glade.get_widget("AEdate").date
				date = Date.civil(dateargs[0], dateargs[1], dateargs[2])
				expenditure = @treasury.add_expenditure(allocid, date, name, amount)
				spent = 0
				@treasury.expenditures_for(allocid) { |e|
					spent += e.amount
				}
				@allocationslist.selection.selected[4] = spent
			end
			dialog.destroy
		end
	end

	def show_expenditures
		selection = @glade.get_widget("allocationsTV").selection.selected
		if (selection.nil?)
			errordialog = Gtk::MessageDialog.new(@glade.get_widget("MainWindow"),
												 Gtk::Dialog::MODAL,
												 Gtk::MessageDialog::ERROR,
												 Gtk::MessageDialog::BUTTONS_CLOSE,
												 "No allocation selected")
			return
		else
			allocid = selection[0].to_i
			@currallocid = allocid
		end
		allocation = @treasury.allocation(allocid)
		@expXML = GladeXML.new(@path, "allocationInfo") {|handler| method(handler) }
		expenditures = @expXML.get_widget("allocationInfo")
		ev = @expXML.get_widget("expendituresView")
		emodel = Gtk::ListStore.new(Integer,String,String,Float)
		ev.model = emodel
		@treasury.expenditures_for(allocid) { |e|
			row = emodel.append
			row[0] = e.expid
			row[1] = e.date.to_s
			row[2] = e.name
			row[3] = e.amount
		}
		update_exp_summary
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Expenditure ID", renderer, :text => 0)
		ev.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Date", renderer, :text=>1)
		ev.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Title", renderer, :text=>2)
		ev.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Amount", renderer, :text=>3)
		ev.append_column(col)
		expenditures.title = "Allocation Info for ##{allocid}"
		expenditures.run do |response|
			expenditures.destroy
			spent = 0
			@treasury.expenditures_for(allocid) { |e|
				spent += e.amount
			}
			@allocationslist.selection.selected[4] = spent
		end
	end

	def update_exp_summary
		total_spent = 0
		allocation = @treasury.allocation(@currallocid)
		@treasury.expenditures_for(@currallocid) { |e| total_spent += e.amount }
		@expXML.get_widget("AIlblsummary").text = "Summary: $#{total_spent} spent out of $#{allocation.amount} allocated"
	end

	def AIbtnCloseAllocation_clicked_cb
		@expXML.get_widget("allocationInfo").response(Gtk::Dialog::RESPONSE_ACCEPT)
	end

	def on_AIbtnDelExpenditure_clicked
		selection = @expXML.get_widget("expendituresView").selection.selected
		if (selection.nil?)
			errordialog = Gtk::MessageDialog.new(@expXML.get_widget("allocationInfo"),
												 Gtk::Dialog::MODAL,
												 Gtk::MessageDialog::ERROR,
												 Gtk::MessageDialog::BUTTONS_CLOSE,
												 "No expenditure selected")
			return
		else
			@treasury.delete_expenditure(selection[0])
			@expXML.get_widget("expendituresView").model.remove(selection)
			update_exp_summary()
		end
	end

	def on_AIbtnAddExpenditure_clicked
		addExpDialog = GladeXML.new(@path, "addExpenditure")
		@expglade = addExpDialog
		dialog = addExpDialog.get_widget("addExpenditure")
		addExpDialog.get_widget("AEallocid").text=@currallocid.to_s
		dialog.run do |response|
			if (response == Gtk::Dialog::RESPONSE_ACCEPT)
				name = addExpDialog.get_widget("AEname").text.to_s
				amount = addExpDialog.get_widget("AEamount").text.to_f
				dateargs = addExpDialog.get_widget("AEdate").date
				date = Date.civil(dateargs[0], dateargs[1], dateargs[2])
				expenditure = @treasury.add_expenditure(@currallocid, date, name, amount)
				row = @expXML.get_widget("expendituresView").model.append
				row[0] = expenditure.expid
				row[1] = expenditure.date.to_s
				row[2] = expenditure.name
				row[3] = expenditure.amount
				update_exp_summary()
			end
			dialog.destroy
		end
		@expglade = @glade
	end

	def on_btnAddExpenditure_clicked
		@expglade.get_widget("addExpenditure").response(Gtk::Dialog::RESPONSE_ACCEPT)
	end

	def add_alloc_to_listmodel(allocation)
		row = @listmodel.append
		row[0] = allocation.allocid
		row[1] = allocation.date.to_s
		row[2] = allocation.name
		row[3] = allocation.amount
		spent = 0
		@treasury.expenditures_for(allocation.allocid) { |e| spent += e.amount }
		row[4] = spent
	end

	def dialog_btnAdd_clicked
		dialog = @glade.get_widget("addAllocation")
		dialog.response(Gtk::Dialog::RESPONSE_ACCEPT)
	end

	def populate_list_box
		@treasury.each_allocation {|a|
			add_alloc_to_listmodel(a)
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
		col = Gtk::TreeViewColumn.new("Amount Allocated", renderer, :text => 3)
		@allocationslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Amount Spent", renderer, :text => 4)
		@allocationslist.append_column(col)
	end
end

# Main program
if __FILE__ == $0
	# Set values as your own application. 
	PROG_PATH = "gtk_ui.glade"
	PROG_NAME = "EastDormTreasury"
	treasury = Treasury.new(ARGV[0])
	GtkUiGlade.new(treasury, PROG_PATH, nil, PROG_NAME)
	Gtk.main
end
