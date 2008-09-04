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
		@stdin.readline
	end

	def process_args
		@treasury = Treasury.new(ARGV[0])
	end

	def handle(input)
		case (input.split(" ")[0])
		when "help"
			print_help
		when "allocation"
			add_allocation
		when "expenditure"
			add_expenditure
		when "print"
			print_allocations()
		when "quit"
			Kernel.exit(0)
		when "unallocate"
			unallocate
		when "unexpend"
			unexpend
		when "info"
			info
		when "summarize"
			summarize
		else
			puts "Unrecognized command. Type help for a list of commands."
		end
	end

	def info
		print_allocations
		print "Allocation ID: "
		allocid = @stdin.readline.chomp
		print_expenditures(allocid)
		puts summary(allocid)
	end

	def summarize
		@treasury.each_allocation { |a|
			puts "Allocation " + "%04d" % a.allocid + " --- " + summary(a.allocid)
		}
	end

	def summary(allocid)
		spent = 0
		@treasury.expenditures_for(allocid) { |e| spent += e.amount }
		"Summary: Spent $" + "%.2f" % spent + " out of $" "%.2f" % @treasury.allocation(allocid).amount + " allocated."
	end

	def print_help
		puts "Commands:"
		puts "\thelp\t\t\tPrint this help"
		puts "\tallocation\t\tAdd an allocation"
		puts "\texpenditure\t\tAdd an expense"
		puts "\tsummarize\t\tPrint summaries for all allocations"
		puts "\tprint\t\t\tPrint allocations"
		puts "\tinfo allocationid\tPrint information about [allocationid]"
		puts "\tunallocate\t\tDelete an allocation"
		puts "\tunexpend\t\tDelete an expenditure"
		puts "\texit\t\t\tExit the application"
	end

	def print_allocations
		print "|"
		print "-"*78
		print "|\n"
		print "|"
		print "  ID   |"
		print "    Date     |"
		print "  Amount   |"
		print "     Title                                  "
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
			print "%08.2f" % a.amount
			print "  | "
			print a.name[0..41].to_s
			diff = 42 - a.name.to_s.size
			if (diff > 0)
				print " "*diff
			end
			print " |\n"
		}
		print "|"
		print "-"*78
		print "|\n"
	end

	def print_expenditures(allocid)
		print "|"
		print "-"*78
		print "|\n"
		print "|"
		print "  ID   |"
		print "    Date     |"
		print "  Amount   |"
		print "     Title                                  "
		print "|\n"
		print "|"
		print "-"*78
		print "|\n"
		@treasury.expenditures_for(allocid) { |e|
			print "| "
			print "%04d" % e.expid
			print "  | "
			print e.date.to_s
			print "  | "
			print "%08.2f" % e.amount
			print "  | "
			print e.name[0..41].to_s
			diff = 42 - e.name.to_s.size
			if (diff > 0) 
				print " "*diff 
			end
			print " |\n"
		}
		print "|" + "-"*78 + "|\n"
	end
	
	def add_allocation
		print "Input Date   : "
		date = @stdin.readline.chomp
		if (date == "today" || date == "")
			date = Date.today
		end
		print "Input Title  : "
		title = @stdin.readline.chomp
		print "Input Amount : "
		amount = @stdin.readline.chomp
		print "Add entry? (Y/n) "
		confirm = @stdin.readline.chomp
		if (confirm.size == 0 || confirm[0,1].upcase == 'Y')
			allocation = @treasury.add_allocation(date, name, amount)
			puts "Allocation #{allocation.allocid} added"
		else
			puts "Allocation aborted"
		end
	end

	def add_expenditure
		print_allocations
		print "Allocation ID  : "
		allocid = @stdin.readline.chomp.to_i
		print "Input Date     : "
		date = @stdin.readline.chomp
		if (date == "today" || date == "")
			date = Date.today
		end
		print "Input Amount   : "
		amount = @stdin.readline.chomp
		print "Input Title    : "
		title = @stdin.readline.chomp
		print "Add entry? (Y/n) "
		confirm = @stdin.readline.chomp
		if (confirm.size == 0 || confirm[0, 1].upcase == 'Y')
			e = @treasury.add_expenditure(allocid, date, title, amount)
			puts "Expenditure #{e.expid} added"
		else
			puts "Expenditure aborted"
		end
	end

	def unallocate
		print_allocations
		print "Allocation ID  : "
		allocid = @stdin.readline.chomp.to_i
		e = @treasury.allocation(allocid)
		print "Delete #{e}? (y/n) "
		confirm = @stdin.readline.chomp
		if (confirm[0, 1].upcase == 'Y')
			@treasury.delete_allocation(allocid)
		end
	end

	def unexpend
		print_allocations
		print "Allocation ID  : "
		allocid = @stdin.readline.chomp.to_i
		print_expenditures(allocid)
		print "Expenditure ID : "
		expid = @stdin.readline.chomp.to_i
		e = @treasury.expenditure(expid)
		print "Delete #{e}? (y/n) "
		confirm = @stdin.readline.chomp
		if (confirm[0, 1].upcase == 'Y')
			@treasury.delete_expenditure(expid)
		end
	end

	# Main loop
	def main
		while true
			input = prompt
			handle(input)
		end
	end

	def at_exit
		@treasury.close
	end
end

c = CLIInterface.new(ARGV, STDIN)
c.main
