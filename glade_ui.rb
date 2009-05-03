#!/usr/bin/env ruby

require 'libglade2'
require 'treasury'

class AddAllocation
	include GetText

	def initialize(treasury, path)
		@path = path
		@treasury = treasury
		bindtextdomain(nil, nil, nil, "UTF-8")
		@glade =GladeXML.new(@path, "addAllocation") { |h| method(h) }
		today = Date.today()
		dw = @glade.get_widget("date")
		dw.year = today.year 
		dw.month = today.month - 1
		dw.day = today.day
	end

	def show
		dialog = @glade.get_widget("addAllocation")
		dialog.run do |response|
			if (response == Gtk::Dialog::RESPONSE_ACCEPT)
				name = @glade.get_widget("title").text.to_s
				amount = @glade.get_widget("amount").text.to_s
				dateargs = @glade.get_widget("date").date
				date = Date.civil(dateargs[0], dateargs[1], dateargs[2])
				allocation = @treasury.add_allocation(date, name, amount)
				dialog.destroy
				return allocation
			end
			dialog.destroy
			return nil
		end
	end
	
	def dialog_btnAdd_clicked
		dialog = @glade.get_widget("addAllocation")
		dialog.response(Gtk::Dialog::RESPONSE_ACCEPT)
	end
end

class AddExpenditure
	include GetText

	def initialize(treasury, path_or_data)
		@path = path_or_data
		@treasury= treasury
		bindtextdomain(nil, nil, nil, "UTF-8")
		@glade = GladeXML.new(path_or_data, "addExpenditure") { |h| method(h) }
		today = Date.today()
		dw = @glade.get_widget("AEdate")
		dw.year = today.year 
		dw.month = today.month - 1
		dw.day = today.day
	end

	# Returns the added expenditure if one was added, else nil
	def show(allocid)
		dialog = @glade.get_widget("addExpenditure")
		@glade.get_widget("AEallocid").text = allocid.to_s
		dialog.run do |response|
			if (response == Gtk::Dialog::RESPONSE_ACCEPT)
				name = @glade.get_widget("AEname").text.to_s
				amount = @glade.get_widget("AEamount").text.to_s
				dateargs = @glade.get_widget("AEdate").date
				date = Date.civil(dateargs[0], dateargs[1], dateargs[2])
				if (@glade.get_widget("checkCheck").active?)
					check_no = @glade.get_widget("check_no").text.to_s.strip
				else
					check_no = "NULL"
				end
				expenditure = @treasury.add_expenditure(allocid,date, name, amount, check_no)
				dialog.destroy
				return expenditure
			end
			dialog.destroy
			return nil
		end
	end
	
	def on_add
		@glade.get_widget("addExpenditure").response(Gtk::Dialog::RESPONSE_ACCEPT)
	end

	def on_checkCheck_toggled
		checker = @glade.get_widget("checkCheck")
		if (checker.active?)
			@glade.get_widget("check_no").visible = true
		else
			@glade.get_widget("check_no").visible = false
		end
	end
end

class AboutDialog
	include GetText

	def initialize(path, parent)
		@path = path
		bindtextdomain(nil, nil, nil, "UTF-8")
		@glade = GladeXML.new(@path, "aboutDT") { |h| method(h) }
		@parent = parent
	end

	def show
		dialog = @glade.get_widget("aboutDT")
		dialog.signal_connect("response") {
			dialog.destroy()
		}
		dialog.show
	end
end


class AddCheck
	include GetText

	def initialize(treasury, path)
		@path = path
		@treasury = treasury
		bindtextdomain(nil, nil, nil, "UTF-8")
		@glade = GladeXML.new(@path, "addCheck") { |h| method(h) }
		today = Date.today()
		dw = @glade.get_widget("calDate")
		dw.year = today.year
		dw.month = today.month - 1
		dw.day = today.day
	end

	def on_add
		@glade.get_widget("addCheck").response(Gtk::Dialog::RESPONSE_ACCEPT)
	end

	def show
		dialog = @glade.get_widget("addCheck")
		dialog.run do |response|
			if (response == Gtk::Dialog::RESPONSE_ACCEPT)
				name = @glade.get_widget("txtName").text.to_s
				amount = @glade.get_widget("txtAmount").text.to_f
				dateargs = @glade.get_widget("calDate").date
				date = Date.civil(dateargs[0], dateargs[1], dateargs[2])
				check_no = @glade.get_widget("txtCheckNo").text.to_i
				expenditure = @treasury.add_expenditure(-1, date, name, amount, check_no)
				dialog.destroy
				return @treasury.check(expenditure.check_no)
			else
				puts "Aborted"
			end
			dialog.destroy
			return nil
		end
	end
end

class AllocationInfo
	include GetText

	def initialize(treasury, path_or_data)
		@path = path_or_data
		@treasury = treasury
		bindtextdomain(nil, nil, nil, "UTF-8")
		@glade = GladeXML.new(@path, "allocationInfo") { |h| method(h) }
	end

	def show(allocid)
		@allocid = allocid
		allocation = @treasury.allocation(allocid)
		expenditures = @glade.get_widget("allocationInfo")
		ev = @glade.get_widget("expendituresView")
		emodel = Gtk::ListStore.new(Integer,String,String,Float,String)
		ev.model = emodel
		@treasury.expenditures_for(allocid) { |e|
			row = emodel.append
			row[0] = e.expid
			row[1] = e.date.to_s
			row[2] = e.name
			row[3] = e.amount.to_f
			if (e.check_no == nil)
				row[4] = "Cash"
			else
				row[4] = e.check_no.to_s
			end
		}
		update_exp_summary(allocid)
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
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Check #", renderer, :text => 4)
		ev.append_column(col)
		expenditures.title = "Allocation Info for ##{allocid}"
		expenditures.run do |response|
			expenditures.destroy
		end
	end

	def update_exp_summary(allocid)
		total_spent = 0
		allocation = @treasury.allocation(allocid)
		@treasury.expenditures_for(allocid) { |e| total_spent += e.amount }
		@glade.get_widget("AIlblsummary").text = "Summary: $#{total_spent} spent out of $#{allocation.amount} allocated"
	end

	def AIbtnCloseAllocation_clicked_cb
		@glade.get_widget("allocationInfo").response(Gtk::Dialog::RESPONSE_ACCEPT)
	end

	def on_AIbtnDelExpenditure_clicked
		selection = @glade.get_widget("expendituresView").selection.selected
		if (selection.nil?)
			errordialog = Gtk::MessageDialog.new(@glade.get_widget("allocationInfo"),
												 Gtk::Dialog::MODAL,
												 Gtk::MessageDialog::ERROR,
												 Gtk::MessageDialog::BUTTONS_CLOSE,
												 "No expenditure selected")
			return
		else
			@treasury.delete_expenditure(selection[0])
			@glade.get_widget("expendituresView").model.remove(selection)
			update_exp_summary(@allocid)
		end
	end

	def on_AIbtnAddExpenditure_clicked
		a = AddExpenditure.new(@treasury, @path)
		expenditure = a.show(@allocid)
		if (!expenditure.nil?)
			row = @glade.get_widget("expendituresView").model.append
			row[0] = expenditure.expid
			row[1] = expenditure.date.to_s
			row[2] = expenditure.name
			row[3] = expenditure.amount
			update_exp_summary(@allocid)
		end
	end
end

class GtkUiGlade
	include GetText

	attr :glade
  
	def initialize(treasury, path_or_data, root = nil, domain = nil, localedir = nil, flag = GladeXML::FILE)
		@path = path_or_data
		@treasury = treasury
		bindtextdomain(domain, localedir, nil, "UTF-8")
		@glade = GladeXML.new(path_or_data, "MainWindow", domain, localedir, flag) {|handler| method(handler)}
		@window = @glade.get_widget("MainWindow")
		@expglade = @glade
		@listmodel = Gtk::ListStore.new(Integer, String, String, String, String, Integer, Pango::FontDescription::Style)
		populate_list_box
		@allocationslist = @glade.get_widget("allocationsTV")
		@allocationslist.selection.mode = Gtk::SELECTION_SINGLE
		@allocationslist.model = @listmodel
		initialize_columns

		@checkslistmodel = Gtk::ListStore.new(String, String, String, String, Integer, Integer, Integer)
		add_checks
		@checkslist = @glade.get_widget("checksTV")
		@checkslist.selection.mode = Gtk::SELECTION_SINGLE
		@checkslist.model = @checkslistmodel
		initialize_check_columns
		update_checking_total
		update_alloc_summary
	end

	def on_quit
		if (@treasury.dirty?)
			querydialog = Gtk::MessageDialog.new(@window,
												 Gtk::Dialog::DESTROY_WITH_PARENT,
												 Gtk::MessageDialog::QUESTION,
												 Gtk::MessageDialog::BUTTONS_NONE,
												 "Unsaved changes found")
			querydialog.add_buttons([Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
									[Gtk::Stock::DISCARD, Gtk::Dialog::RESPONSE_NO],
									[Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_YES])
			querydialog.run do |response|
				case response
				when Gtk::Dialog::RESPONSE_CANCEL
					querydialog.destroy
					return
				when Gtk::Dialog::RESPONSE_NO
					break
				when Gtk::Dialog::RESPONSE_YES
					@treasury.save
				else
					puts "Unknown response detected?"
				end
			end
			querydialog.destroy
		end
		@treasury.close
		Gtk::main_quit
	end

	def on_btnNewAllocation_clicked
		a = AddAllocation.new(@treasury, @path)
		allocation = a.show
		if (!allocation.nil?)
			add_alloc_to_listmodel(allocation)
			update_alloc_summary
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
		a = AddExpenditure.new(@treasury, @path)
		expenditure = a.show(allocid)
		if (expenditure.nil?)
			return
		end
		spent = 0
		@treasury.expenditures_for(allocid) { |e|
			spent += e.amount
		}
		update_alloc_summary
		@allocationslist.selection.selected[4] = spent.to_s
		if (!expenditure.check_no.nil?)
			add_check(@treasury.check(expenditure.check_no))
			update_checking_total
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
			errordialog.show
			return
		else
			allocid = selection[0].to_i
		end
		a = AllocationInfo.new(@treasury, @path)
		a.show(allocid)
		spent = 0
		@treasury.expenditures_for(allocid) { |e| spent += e.amount }
		selection[4] = "%8.2f" % spent
		add_checks
	end

	def add_alloc_to_listmodel(allocation)
		row = @listmodel.append
		row[0] = allocation.allocid
		row[1] = allocation.date.to_s
		row[2] = allocation.name
		row[3] = "%8.2f" % allocation.amount.to_f
		spent = 0
		@treasury.expenditures_for(allocation.allocid) { |e| spent += e.amount }
		row[4] = "%8.2f" % spent.to_f
		if (allocation.closed)
			row[5] = 1
			row[6] = Pango::FontDescription::Style::ITALIC
		else
			row[5] = 0
			row[6] = Pango::FontDescription::Style::NORMAL
		end
	end

	def populate_list_box(active_only = false)
		@listmodel.clear
		@treasury.each_allocation {|a|
			if (!active_only || !a.closed)
				add_alloc_to_listmodel(a)
			end
		}
	end

	def add_check(c)
		row = @checkslistmodel.append
		row[0] = c.check_no.to_s
		if (row[0] == "-1")
			row[0] = "deposit"
			row[5] = 0
			row[6] = 1
		else
			row[5] = 1
			row[6] = 0
		end
		row[1] = c.expenditure.date.to_s
		row[2] = c.expenditure.name.to_s
		row[3] = "$%8.2f" % c.expenditure.amount.to_s
		if (c.cashed)
			row[4] = 1
		else
			row[4] = 0
		end
	end
	
	def add_checks(active_only=false)
		@checkslistmodel.clear
		@treasury.each_check { |c|
			if (!active_only || !c.cashed)
				add_check(c)
			end
		}
	end

	def toggle_active(box)
		a = box.active?
		add_checks(a)
		populate_list_box(a)
		update_alloc_summary(a)
	end

	def initialize_columns
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Allocation ID", renderer, :text => 0)
		@allocationslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Date", renderer, :text => 1, :style=>6)
		@allocationslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Title", renderer, :text => 2, :style=>6)
		@allocationslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Amount Allocated", renderer, :text => 3)
		@allocationslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Amount Spent", renderer, :text => 4)
		@allocationslist.append_column(col)
		renderer = Gtk::CellRendererToggle.new
		renderer.signal_connect("toggled") { |it, path|
			allocid = @listmodel.get_iter(path).get_value(0)
			closed = @listmodel.get_iter(path).get_value(5)
			if (closed == 1)
				@treasury.allocation(allocid).closed = false
				@listmodel.get_iter(path).set_value(5, 0)
				@listmodel.get_iter(path).set_value(6, Pango::FontDescription::Style::NORMAL)
			else
				@treasury.allocation(allocid).closed = true
				@listmodel.get_iter(path).set_value(5, 1)
				@listmodel.get_iter(path).set_value(6, Pango::FontDescription::Style::ITALIC)
			end
		}
		col = Gtk::TreeViewColumn.new("Open", renderer, :active => 5)
		@allocationslist.append_column(col)
	end

	def initialize_check_columns
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Check #", renderer, :text=>0)
		@checkslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Date", renderer, :text=>1)
		@checkslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Name", renderer, :text => 2)
		@checkslist.append_column(col)
		renderer = Gtk::CellRendererText.new
		col = Gtk::TreeViewColumn.new("Amount", renderer, :text => 3)
		@checkslist.append_column(col)
		renderer = Gtk::CellRendererToggle.new
		renderer.signal_connect("toggled") { |it,path|
			cno=@checkslistmodel.get_iter(path).get_value(0)
			cashed=@checkslistmodel.get_iter(path).get_value(4)
			if (cno != "deposit")
				if (cashed == 1)
					@treasury.check(cno).cashed = false
					@checkslistmodel.get_iter(path).set_value(4, 0)
				else
					@treasury.check(cno).cashed = true
					@checkslistmodel.get_iter(path).set_value(4, 1)
				end
			end
		}
		col = Gtk::TreeViewColumn.new("Cashed", renderer, :active => 4, :activatable => 5, :inconsistent => 6)
		@checkslist.append_column(col)
	end

	def btnDeleteClicked
		selection = @glade.get_widget("allocationsTV").selection.selected
		if (!selection.nil?)
			allocid = selection[0].to_i
			@treasury.delete_allocation(allocid)
			@listmodel.remove(selection)
		end
	end

	def btnNewCheckClicked
		c = AddCheck.new(@treasury, @path)
		check = c.show
		if (check)
			add_check(check)
			update_checking_total
		end
	end

	def btnDeleteCheckClicked
		selection = @glade.get_widget("checksTV").selection.selected
		if (!selection.nil?)
			check_no = selection[0].to_i
			@treasury.delete_check(check_no)
			@checkslistmodel.remove(selection)
		end
	end

	def update_checking_total
		balance = @treasury.balance
		@glade.get_widget("lblChecksSummary").text = ("Current Available Balance: $%.2f" % balance)
		balance
	end

	def update_alloc_summary(active_only = false)
		alloc = @treasury.total_allocations(active_only).to_f
		spent = @treasury.total_spent_for_allocations(active_only).to_f
		@glade.get_widget("lblAllocSummary").text = ("Summary: $%.2f spent/$%.2f allocated" % [spent, alloc])
		spent / alloc
	end

	def on_menu_allocations_activate
		@glade.get_widget("notebookMain").page=0
	end

	def on_menu_checks_activate
		@glade.get_widget("notebookMain").page=1
	end

	# Called whenever the page is switched in the main view
	def page_switched(widget, page, page_num)
		a = @glade.get_widget("menu_active").active?
		case page_num
		when 0:
			update_alloc_summary(a)
		when 1:
			update_checking_total
		end
	end

	def show_about
		AboutDialog.new(@path, @window).show()
	end

	def save
		@treasury.save
	end
end

# Main program
if __FILE__ == $0
	# Set values as your own application. 
	PROG_PATH = "gtk_ui.glade"
	PROG_NAME = "EastDormTreasury"
	if(ARGV.length == 0)
		puts "Usage:"
		puts "\tprogram DB_FILE"
		exit 1
	end
	treasury = Treasury.new(ARGV[0])
	GtkUiGlade.new(treasury, PROG_PATH, nil, PROG_NAME)
	Gtk.main
end
