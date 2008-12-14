#!/usr/bin/ruby

require 'treasury'
require 'readline'

UI_VERSION=0.6

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
		catch :abort do
			begin
				line = get_input("> ")
				Readline::HISTORY.push(line)
				return line
			rescue EOFError
				puts
				Kernel.exit(0)
			end
		end
		Kernel.exit(0)
	end

	# Get a line of input. Throws :abort if we should abort
	def get_input(prompt="::")
		input = Readline::readline(prompt)
		if (input.nil? || input =~ /ZRT/)
			throw :abort
		else
			return input.strip
		end
	end
	
	def process_args
		if (ARGV.size == 0)
			print_usage
		end
		case (ARGV[0])
		when '-h': print_usage(true)
		when '--help': print_usage(true)
		when '-v': print_version; Kernel.exit(0)
		when '--version': print_version; Kernel.exit(0)
		else
			print_usage(false) if !File.file?(ARGV[0])
			@treasury = Treasury.new(ARGV[0])
		end
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
		when /^print ?(.*)/
			if ($1 == "open")
				print_allocations(true)
			else
				print_allocations(false)
			end
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
		when /^summary? ?(.*)/
			if ($1 == "open")
				summarize(true)
			else
				summarize(false)
			end
		when /^checks? ?(.*)/
			if ($1 == "open" || $1 == "uncashed")
				print_checks(true)
			else
				print_checks(false)
			end
		when /^cash ?(\d*)/
			if ($1.nil? || $1 == "")
				cash_check(nil)
			else
				cash_check($1.to_i)
			end
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
				allocid = get_input("Allocation ID: ")
				if (allocid.nil? || allocid == "")
					return
				end
			end
			a = @treasury.allocation(allocid)
			if (a.nil?)
				return
			end
			puts "** Allocation ##{a.allocid} **"
			puts "   Date: #{a.date}"
			puts "   Title: #{a.name}"
			print "   Status: "
			if (a.closed)
				puts "Closed"
			else
				puts "Open"
			end
			print_expenditures(allocid)
			puts summary(allocid)
		end
	end

	def summarize(open_only=false)
		spent = 0
		@treasury.each_allocation(open_only) { |a|
			if (a.closed)
				puts "\tAllocation " + "%3d" % a.allocid + " --- (closed)"
				next
			end
			s = spent(a.allocid)
			spent += s
			puts "\tAllocation " + "%3d" % a.allocid + " --- " + " Spent $" + "%.2f" % s + " out of $" + "%.2f" % a.amount + " allocated."
		}
		puts
		if (!open_only)
			puts "Total allocated: $" + "%.2f" % @treasury.total_allocations
		end
		puts "Total open allocations: $" + "%.2f" % @treasury.total_open_allocations
		puts "Total spent: $#{spent}"
		puts "Total promised: $#{@treasury.total_open_allocations - spent}"
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
		return "Summary: Spent $" + "%.2f" % spent + "/$" "%.2f" % @treasury.allocation(allocid).amount + " allocated."
	end

	def print_help
		puts "Commands:"
		puts "\thelp\t\t\tPrint this help"
		puts "\tallocation\t\tAdd an allocation"
		puts "\texpenditure\t\tAdd an expense"
		puts "\tocheck\t\t\tAdd a non-expense check"
		puts "\tsummary [open]\t\tPrint summaries for all [open] allocations"
		puts "\tprint [open]\t\tPrint allocations (optionally, only open allocations)"
		puts "\tchecks [open]\t\tPrint all [open] checks"
		puts "\tcash [check #]\t\tMark a check [check #] as cashed"
		puts "\tinfo [allocationid]\tPrint information [about allocationid]"
		puts "\tunallocate\t\tDelete an allocation"
		puts "\tunexpend\t\tDelete an expenditure"
		puts "\tdelcheck\t\tDelete a check"
		puts "\tclose\t\t\tClose an allocation"
		puts "\texit\t\t\tExit the application"
		puts
		puts "Enter `ZRT` at any prompt to cancel"
	end

	def print_checks(open=false)
		sum = 0
		print "|-----------------------------------------------------------------------------------------|\n"
		print "| Check |   Date     |             To                                  |  Amount  |Cashed?|\n"
		print "|-----------------------------------------------------------------------------------------|\n"
		@treasury.each_check { |check|
			if (open && check.cashed)
				next
			end
			sum += check.expenditure.amount
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
		if (open)
			puts "\t\tTotal outstanding checks: $" + "%.2f" % sum
		end
	end


	def print_allocations(open_only=false)
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
		@treasury.each_allocation(open_only) { |a|
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

	def cash_check(check_no=nil)
		catch :abort do
			if (check_no.nil?)
				print_checks
				check_no = get_input("Check #: ")
			end
			confirm = get_input "Mark check #{check_no} as cashed? (y/N) "
			if (confirm[0,1].upcase == 'Y')
				@treasury.cash_check(check_no)
			end
		end
	end

	def add_allocation
		catch :abort do
			date = get_input("Date   : ")
			if (date == "today" || date == "")
				date = Date.today
			end
			title = get_input("Title  : ")
			amount = get_input("Amount : ")
			confirm = get_input("Add entry? (Y/n) ")
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
				allocid = get_input("Allocation ID                           : ")
			end
			puts "Adding expenditure to allocation #{@treasury.allocation(allocid)}"
			date = get_input("Input Date                              : ")
			if (date == "today" || date == "")
				date = Date.today
			end
			amount = get_input("Input Amount                            : ")
			title = get_input("Input Title                             : ")
			check_no = get_input("Check number (leave blank if not check) : ")
			if (check_no == "" || check_no == nil)
				check_no = "NULL"
			end
			confirm = get_input("Add entry? (Y/n) ")
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
			date = get_input("Input Date (q to abort)        : ")
			if (date[0,1] == "q")
				return
			end
			amount = get_input("Input Amount (neg for deposit) : ")
			name = get_input("Input Title                    : ")
			check_no = get_input("Check # (blank for deposit)    : ")
			if (check_no == "" || check_no == "")
				check_no = -1
			end
			confirm = get_input("Add entry (Y/n) ")
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
			allocid = get_input("Allocation ID: ")
			e = @treasury.allocation(allocid)
			confirm = get_input("Delete #{e}? (y/N) ")
			if (confirm[0, 1].upcase == 'Y')
				@treasury.delete_allocation(allocid)
			end
		end
	end

	def close_allocation(allocid=nil)
		catch :abort do
			if (allocid.nil? || allocid == "")
				print_allocations
				allocid = get_input("Allocation ID: ")
			end
			e = @treasury.allocation(allocid)
			confirm = get_input("Close #{e}? (y/N) ")
			if (confirm[0, 1].upcase == 'Y')
				puts "Closing"
				@treasury.close_allocation(allocid)
			end
		end
	end

	def unexpend
		catch :abort do
			print_allocations
			allocid = get_input("Allocation ID: ")
			print_expenditures(allocid)
			expid = get_input("Expenditure ID: ")
			e = @treasury.expenditure(expid)
			confirm = get_input("Delete #{e}? (y/N) ")
			if (confirm[0, 1].upcase == 'Y')
				@treasury.delete_expenditure(expid)
			end
		end
	end

	def delete_check
		catch :abort do
			print_checks
			checkno = get_input("Check #: ")
			@treasury.delete_check(checkno)
		end
	end

	# Main loop
	def main
		puts "Welcome to East Dorm Treasury v#{UI_VERSION}"
		puts "Current balance: " + "$%.2f" % @treasury.balance
		catch :abort do
			loop do
				input = prompt
				handle(input)
			end
		end
		Kernel.exit(0)
	end

	def at_exit
		@treasury.close
	end

	def print_version
		puts "East Dorm Treasury CLI v#{UI_VERSION}"
	end

	def print_usage(full=false)
		print_version
		puts "Usage:"
		puts "\tcli.rb sqlite_db_file"
		if(full)
			puts "Arguments:"
			puts "\t-h, --help\t\tPrint this help"
			puts "\t-v, --version\t\tPrint version information"
		end
		Kernel.exit(0)
	end

	private :get_input, :at_exit, :print_usage, :print_version
end

c = CLIInterface.new(ARGV, STDIN)
c.main
