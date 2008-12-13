#!/usr/bin/ruby

require 'treasury'

# == Synopsis 
#	This application is for managing the East Dorm treasury
# 
# == Usage 
#   cli_ui.rb treasury_file
# 
# For help use: ruby_cl_skeleton -h
# 
# == Options
#   -h, --help          Displays help message
#   TO DO - add additional options
# 
#  == Author
#	James Brown <jbrown@cs.hmc.edu>
# 
# == Copyright
#	Copyright (c) 2008 James Brown. All Rights Reserved.
#
class CLIInterface
	def initialize(args, stdin)
		@args = args
		@stdin = stdin
		process_args
	end

	# Print a prompt and catch input
	def prompt
		print "> "
		begin
			return get_input
		rescue EOFError
			Kernel.exit(0)
		end
	end

	# Get a line of input. Throws :abort if we should abort
	def get_input
		input = @stdin.readline.strip
		if (input =~ /ZRT/)
			throw :abort
		else
			return input
		end
	end
	
	def process_args
		@treasury = Treasury.new(ARGV[0])
	end

	def handle(input)
		case input
		when /^help/
			print_help
		when /^allocat/
			add_allocation
		when /^expend *(\d*)/
			if ($1.nil? || $1 == "")
				n = nil
			else
				n = $1.to_i
			end
			add_expenditure(n)
		when /^print/
			print_allocations
		when /^quit/
			Kernel.exit(0)
		when /^exit/
			Kernel.exit(0)
		when /^unallocat/
			unallocate
		when /^unexpend/
			unexpend
		when /^info *(\d*)/
			if ($1.nil? || $1 == "")
				n = nil
			else
				n = $1.to_i
			end
			info(n)
		when /^summar/
			summarize
		when /^check/
			print_checks
		when /^cash/
			cash_check
		when /^ocheck/
			other_check
		when /^delcheck/
			delete_check
		when /^close *(\d*)/
			if ($1.nil? || $1 == "")
				n = nil
			else
				n = $1.to_i
			end
			close_allocation(n)
		else
			puts "Unrecognized command. Type help for a list of commands."
		end
	end

	def info(allocid=nil)
		catch :abort do
			if (allocid.nil?)
				print_allocations 
				print "Allocation ID: "
				allocid = get_input
				if (allocid.nil? || allocid == "")
					return
				end
			end
			print_expenditures(allocid)
			puts summary(allocid)
		end
	end

	def summarize
		spent = 0
		@treasury.each_allocation { |a|
			if (a.closed)
				puts "\tAllocation " + "%04d" % a.allocid + " --- (closed)"
				next
			end
			s = spent(a.allocid)
			spent += s
			puts "\tAllocation " + "%04d" % a.allocid + " --- " + " Summary: Spent $" + "%.2f" % s + " out of $" + "%.2f" % a.amount + " allocated."
		}
		puts "Total allocated: $" + "%.2f" % @treasury.total_allocations
		puts "Total open allocations: $" + "%.2f" % @treasury.total_open_allocations
		puts "Total spent: $#{spent}"
		puts "Open allocated but unspent: $#{@treasury.total_open_allocations - spent}"
		puts "Current balance: $#{@treasury.balance}"
	end

	def spent(allocid)
		spent=0
		@treasury.expenditures_for(allocid) { |e| spent += e.amount }
		return spent
	end

	def summary(allocid)
		spent = 0
		@treasury.expenditures_for(allocid) { |e| spent += e.amount }
		a = @treasury.allocation(allocid)
		if (a.closed)
			return "Summary: (closed), spent $" + "%.2f" % spent + "/$" + "%.2f" % a.amount + " allocated"
		else
			return "Summary: Spent $" + "%.2f" % spent + " out of $" "%.2f" % @treasury.allocation(allocid).amount + " allocated."
		end
	end

	def print_help
		puts "Commands:"
		puts "\thelp\t\t\tPrint this help"
		puts "\tallocation\t\tAdd an allocation"
		puts "\texpenditure\t\tAdd an expense"
		puts "\tocheck\t\t\tAdd a non-expense check"
		puts "\tsummarize\t\tPrint summaries for all allocations"
		puts "\tprint\t\t\tPrint allocations"
		puts "\tchecks\t\t\tPrint all checks"
		puts "\tcash\t\t\tMark a check as cashed"
		puts "\tinfo allocationid\tPrint information about [allocationid]"
		puts "\tunallocate\t\tDelete an allocation"
		puts "\tunexpend\t\tDelete an expenditure"
		puts "\tdelcheck\t\tDelete a check"
		puts "\tclose\t\t\tClose an allocation"
		puts "\texit\t\t\tExit the application"
		puts
		puts "Enter `ZRT` at any prompt to cancel"
	end

	def print_checks
		print "|-----------------------------------------------------------------------------------------|\n"
		print "| Check |   Date     |             To                                  |  Amount  |Cashed?|\n"
		print "|-----------------------------------------------------------------------------------------|\n"
		@treasury.each_check { |check|
			print "| " + "%5d" % check.check_no + " "
			print "| " + check.expenditure.date.to_s + " "
			print "| " + check.expenditure.name.to_s[0..47]
			if (check.expenditure.name.to_s.size < 48)
				print " " * (48 - check.expenditure.name.to_s.size)
			end
			print "| "
			print "%8.2f" % check.expenditure.amount
			print " |"
			if (check.cashed)
				print " True "
			else
				print " False"
			end
			print " |\n"
		}
		print "|-----------------------------------------------------------------------------------------|\n"
		balance = "$%8.2f" % @treasury.balance  
		print "|                                                              Balance: #{balance}         |\n"
		print "|-----------------------------------------------------------------------------------------|\n"
	end


	def print_allocations
		print "|"
		print "-"*78
		print "|\n"
		print "|"
		print "  ID   |"
		print "    Date     |"
		print "  Amount   |"
		print "     Title                                |C"
		print "|\n"
		print "|"
		print "-"*78
		print "|\n"
		@treasury.each_allocation { |a|
			print "| "
			print "%04d" % a.allocid
			print "  | "
			print a.date.to_s
			print "  | "
			print "%8.2f" % a.amount
			print "  | "
			print a.name[0..40].to_s
			diff = 41 - a.name.to_s.size
			if (diff > 0)
				print " "*diff
			end
			if (a.closed)
				b = "t"
			else
				b = "F"
			end
			print "|" + b
			print "|\n"
		}
		print "|"
		print "-"*78
		print "|\n"
	end

	def print_expenditures(allocid)
		print "|"
		print "-"*86
		print "|\n"
		print "|"
		print "  ID   |"
		print "    Date     |"
		print "  Amount   |"
		print "     Title                                  "
		print "| Check "
		print "|\n"
		print "|"
		print "-"*86
		print "|\n"
		@treasury.expenditures_for(allocid) { |e|
			print "| "
			print "%04d" % e.expid
			print "  | "
			print e.date.to_s
			print "  | "
			print "%8.2f" % e.amount
			print "  | "
			print e.name[0..41].to_s
			diff = 42 - e.name.to_s.size
			if (diff > 0) 
				print " "*diff 
			end
			if (e.check_no.nil?)
				print " | " + "%5s" % "cash"
			else
				print " | " + "%5d" % e.check_no
			end
			print " |\n"
		}
		print "|" + "-"*86 + "|\n"
	end

	def cash_check
		catch :abort do
			print_checks
			print "Check # (q to abort): "
			input = get_input
			@treasury.cash_check(input)
		end
	end

	def add_allocation
		catch :abort do
			print "Input Date   : "
			date = get_input
			if (date == "today" || date == "")
				date = Date.today
			end
			print "Input Title  : "
			title = get_input
			print "Input Amount : "
			amount = get_input
			print "Add entry? (Y/n) "
			confirm = get_input
			if (confirm.size == 0 || confirm[0,1].upcase == 'Y')
				allocation = @treasury.add_allocation(date, name, amount)
				puts "Allocation #{allocation.allocid} added"
			else
				puts "Allocation aborted"
			end
		end
	end

	def add_expenditure(allocid=nil)
		catch :abort do
			if (allocid.nil? || allocid == "")
				print_allocations
				print "Allocation ID                           : "
				allocid = get_input
			end
			puts "Adding expenditure to allocation #{@treasury.allocation(allocid)}"
			print "Input Date                              : "
			date = get_input
			if (date == "today" || date == "")
				date = Date.today
			end
			print "Input Amount                            : "
			amount = get_input
			print "Input Title                             : "
			title = get_input
			print "Check number (leave blank if not check) : "
			check_no = get_input
			if (check_no == "" || check_no == nil)
				check_no = "NULL"
			end
			print "Add entry? (Y/n) "
			confirm = get_input
			if (confirm.size == 0 || confirm[0, 1].upcase == 'Y')
				e = @treasury.add_expenditure(allocid, date, title, amount, check_no)
				puts "Expenditure #{e.expid} added"
			else
				puts "Expenditure aborted"
			end
		end
	end

	def other_check
		catch :abort do
			print "Input Date (q to abort)        : "
			date = get_input
			if (date[0,1] == "q")
				return
			end
			print "Input Amount (neg for deposit) : "
			amount = get_input
			print "Input Title                    : "
			name = get_input
			print "Check # (blank for deposit)    : "
			check_no = get_input
			if (check_no == "" || check_no == "")
				check_no = -1
			end
			print "Add entry (Y/n) "
			confirm = get_input
			if (confirm.size == 0 || confirm =~ /^y/i)
				e = @treasury.add_expenditure(-1, date, name, amount, check_no)
				if(check_no == -1)
					@treasury.cash_check(-1)
				end
				puts "Check added" 
			end
		end
	end

	def unallocate
		catch :abort do
			print_allocations
			print "Allocation ID  : "
			allocid = get_input
			e = @treasury.allocation(allocid)
			print "Delete #{e}? (y/n) "
			confirm = get_input
			if (confirm[0, 1].upcase == 'Y')
				@treasury.delete_allocation(allocid)
			end
		end
	end

	def close_allocation(allocid=nil)
		catch :abort do
			if (allocid.nil? || allocid == "")
				print_allocations
				print "Allocation ID : "
				allocid = get_input
			end
			e = @treasury.allocation(allocid)
			print "Close #{e}? (y/n) "
			confirm = get_input
			if (confirm[0, 1].upcase == 'Y')
				@treasury.close_allocation(allocid)
			end
		end
	end

	def unexpend
		catch :abort do
			print_allocations
			print "Allocation ID  : "
			allocid = get_input
			print_expenditures(allocid)
			print "Expenditure ID : "
			expid = get_input
			e = @treasury.expenditure(expid)
			print "Delete #{e}? (y/n) "
			confirm = get_input
			if (confirm[0, 1].upcase == 'Y')
				@treasury.delete_expenditure(expid)
			end
		end
	end

	def delete_check
		catch :abort do
			print_checks
			print "Check: "
			checkno = get_input
			@treasury.delete_check(checkno)
		end
	end

	# Main loop
	def main
		catch :abort do
			while true
				input = prompt
				handle(input)
			end
		end
		Kernel.exit(0)
	end

	def at_exit
		@treasury.close
	end

	private :get_input
end

c = CLIInterface.new(ARGV, STDIN)
c.main
