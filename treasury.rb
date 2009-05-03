#!/usr/bin/ruby

require 'sqlite3'
require 'primitives'
require 'exceptions'

class Treasury
	def initialize(filename)
		@db = SQLite3::Database.new(filename)
		@expenditures = []
		@dirty_expenditures = []
		@added_expenditures = []
		@deleted_expenditures = []
		@allocations = []
		@dirty_allocations = []
		@added_allocations = []
		@deleted_allocations = []
		@checks = []
		@dirty_checks = []
		@added_checks = []
		@deleted_checks = []
		read_db()
	end

	def dirty?
		return !(@dirty_expenditures.empty? && @added_expenditures.empty? && 
				@deleted_expenditures.empty? && @dirty_allocations.empty? &&
				@added_allocations.empty? && @deleted_allocations.empty? &&
				@dirty_checks.empty? && @added_checks.empty? && @deleted_checks.empty?)
	end

	def close
		@db.close
	end

	def next_allocid
		@next_allocid += 1
		return @next_allocid
	end

	def next_expid
		@next_expid += 1
		return @next_expid
	end

	def next_cid
		@next_cid += 1
		return @next_cid
	end

	def save
		@dirty_allocations.each { |a|
			@db.execute("UPDATE allocations SET date=?,name=?,amount=?,closed=? WHERE ROWID=?", a.date, a.name,
					   a.amount, a.closed ? "1" : "0", a.allocid)
		}
		@dirty_allocations = []
		@dirty_expenditures.each { |e|
			@db.execute("UPDATE expenditures SET allocid=?,date=?,name=?,amount=? WHERE ROWID=?",
					   e.allocid,e.date,e.name,e.amount,e.expid) 
		}
		@dirty_expenditures = []
		@dirty_checks.each { |c|
			@db.execute("UPDATE checks SET cashed=? WHERE check_no=?",
						c.cashed, c.check_no)
		}
		@dirty_checks = []
		@added_allocations.each { |a|
			@db.execute("INSERT INTO allocations (date, name, amount, closed, ROWID) VALUES(?,?,?,?,?)",
						a.date, a.name, a.amount, a.closed ? "1" : "0", a.allocid)
		}
		@added_allocations = []
		@added_expenditures.each { |e|
			if (!e.check_no.nil?)
				@db.execute("INSERT INTO expenditures (allocid, date, name, amount,check_no,ROWID) VALUES(?,?,?,?,?,?)", e.allocid, e.date, e.name, e.amount, checkid, e.expid)
			else
				@db.execute("INSERT INTO expenditures (allocid, date, name, amount, ROWID) VALUES(?,?,?,?,?)", e.allocid, e.date, e.name, e.amount)
			end
		}
		@added_expenditures = []
		@added_checks.each { |c|
			@db.execute("INSERT INTO checks(check_no, cashed, ROWID) VALUES(?,?,?)",
						c.check_no, c.cashed, c.cid)
		}
		@added_checks = []
		@deleted_allocations.each { |a|
			@db.execute("DELETE FROM allocations WHERE ROWID=#{a.allocid}")
		}
		@deleted_allocations = []
		@deleted_expenditures.each { |e|
			@db.execute("DELETE FROM expenditures WHERE ROWID=#{e.expid}")
		}
		@deleted_expenditures = []
		@deleted_checks.each { |c|
			@db.execute("DELETE FROM checks WHERE ROWID=#{c.cid}")
		}
		@deleted_checks = []
	end

	def read_db
		@db.execute("SELECT ROWID,date,name,amount,closed from allocations") { |allocation|
			a = Allocation.new(allocation[0], allocation[1], allocation[2], allocation[3], allocation[4]) { 
				@dirty_allocations.push(a)
			}
			@allocations.push(a)
		}
		@db.execute("SELECT ROWID,date,name,amount,allocid,check_no FROM expenditures") { |expenditure|
			if (expenditure[5].nil?)
				e = Expenditure.new(expenditure[0],expenditure[4],expenditure[1],expenditure[2],expenditure[3], nil) {
					@dirty_expenditures.push(e)
				}
				@expenditures.push(e)
			else
				cno = @db.get_first_row("SELECT check_no FROM checks WHERE ROWID=#{expenditure[5]}")[0]
				e = Expenditure.new(expenditure[0],expenditure[4],expenditure[1],expenditure[2],expenditure[3],cno) {
					@dirty_expenditures.push(e)
				}
				@expenditures.push(e)
			end
		}
		@db.execute("SELECT expenditures.ROWID,checks.check_no,checks.cashed,checks.ROWID FROM expenditures,checks WHERE expenditures.check_no IS NOT NULL AND expenditures.check_no=checks.ROWID") { |e|
			expenditure = @expenditures.select{|item| item.expid==e[0].to_i }
			c = Check.new(e[1],expenditure[0],e[2],e[3]) {
				@dirty_checks.push(c)
			}
			@checks.push(c)
		}
		@next_allocid = 0
		@db.execute("SELECT max(ROWID) from allocations") { |r|
			if (r.nil?)
				break
			end
			@next_allocid += r[0].to_i
		}
		@next_expid = 0
		@db.execute("SELECT max(ROWID) from expenditures") { |r|
			if (r.nil?)
				break
			end
			@next_expid += r[0].to_i
		}
		@next_cid = 0
		@db.execute("SELECT max(ROWID) from checks") { |r|
			if (r.nil?)
				break
			end
			@next_cid += r[0].to_i
		}
	end

	def allocation(allocid)
		a = @allocations.select { |item| item.allocid == allocid.to_i }
		if (a.size == 0)
			puts "No such allocation (#{allocid}) found"
			return nil
		elsif (a.size > 1)
			STDERR.puts "Error! Multiple identically-numbered allocations detected!"
			Kernel.exit(1)
		end
		return a[0]
		#@db.execute("SELECT date,name,amount,closed FROM allocations WHERE ROWID=#{allocid}") { |allocation|
		#	return Allocation.new(allocid, allocation[0], allocation[1], allocation[2], allocation[3])
		#}
	end

	def expenditure(expid)
		e = @expenditures.select { |item| item.expid == expid.to_i }
		if (e.size == 0)
			puts "No such expenditure (##{expid}) found"
			return nil
		elsif (e.size > 1)
			STDERR.puts "Error! Multiple identically-numbered expenditures detected!"
			Kernel.exit(1)
		end
		return e[0]
		#@db.execute("SELECT expenditures.allocid,expenditures.date,expenditures.name,expenditures.amount,expenditures.check_no,checks.check_no FROM expenditures,checks WHERE expenditures.ROWID=#{expid} AND checks.ROWID=expenditures.check_no") { |e|
		#	return Expenditure.new(expid, e[0], e[1], e[2], e[3],e[4])
		#}
	end

	def each_allocation(open_only=false)
		@allocations.sort_by { |alloc| alloc.date }
		if (open_only)
			@allocations.each { |a|
				if (!a.closed)
					yield a
				end
			}
		else
			@allocations.each { |a| yield a }
		end
	end

	def each_expenditure
		@expenditures.each { |e| yield e }
	end

	def expenditures_for(allocid)
		@expenditures.each { |e|
			if (e.allocid == allocid.to_i)
				yield e
			end
		}
		#@db.execute("SELECT expenditures.ROWID,date,name,amount,expenditures.check_no FROM expenditures WHERE allocid=#{allocid}") { |expenditure|
		#
		#	if (expenditure[4].nil?)
		#		yield Expenditure.new(expenditure[0], allocid, expenditure[1], expenditure[2], expenditure[3], nil)
		#	else
		#		cno = @db.get_first_row("SELECT check_no FROM checks WHERE ROWID=#{expenditure[4]}")[0]
		#		yield Expenditure.new(expenditure[0],allocid,expenditure[1],expenditure[2],expenditure[3], cno)
		#	end
		#}
	end

	def check(check_no)
		c = @checks.select {|item| item.check_no == check_no.to_i }
		if (c.size == 0)
			raise CheckNotFoundError.new(check_no)
		elsif (c.size > 1)
			raise DuplicateCheckError.new(check_no)
		end
		return c[0]
	end

	def each_check
		@checks.each { |c| yield c }
		#@db.execute("SELECT expenditures.ROWID,checks.check_no,checks.cashed,checks.ROWID,expenditures.date FROM expenditures,checks WHERE expenditures.check_no IS NOT NULL AND expenditures.check_no=checks.ROWID ORDER BY checks.check_no, date") { |e|
		#	expenditure = @expenditures.select{|item| item.expid==e[0].to_i }
		#	if (expenditure.size != 1)
		#		STDERR.puts "Error; expenditures to checks is not 1-to-1"
		#	else
		#		yield Check.new(e[1], expenditure[0], e[2],e[3])
		#	end
		#}
	end

	def add_allocation(date, name, amount, closed=false)
		allocid = next_allocid()
		allocation = Allocation.new(allocid, date, name, amount, closed) { |a|
			@dirty_allocations.push(a)
		}
		@allocations.push(allocation)
		@added_allocations.push(allocation)
		return allocation
	end

	def add_expenditure(allocid, date, name, amount, check_no = "NULL")
		expid = next_expid()
		if (check_no == "NULL")
			expenditure = Expenditure.new(expid, allocid, date, name, amount,nil) { |e|
				@dirty_expenditures.push(e)
			}
		else
			expenditure = Expenditure.new(expid,allocid,date,name,amount,check_no) { |e|
				@dirty_expenditures.push(e)
			}
			cid = next_cid()
			c = Check.new(check_no, expid, allocid.to_i == -1 ? 1 : 0, cid) { |c|
				@dirty_checks.push(c)
			}
			@checks.push(c)
			@added_checks.push(c)
		end
		@expenditures.push(expenditure)
		@added_expenditures.push(expenditure)
		return expenditure
	end

	def cash_check(check_no)
		check(check_no).cashed = true
		#@db.execute("UPDATE checks SET cashed=1 WHERE check_no=#{check_no}")
	end

	def delete_allocation(allocid)
		if (!allocid.nil?)
			alloc = allocation(allocid)
			@deleted_allocations.push(alloc)
			@allocations.delete(alloc)
		end
	end

	def delete_expenditure(expid)
		if (!expid.nil?)
			exp = expenditure(expid)
			if (!exp.check_no.nil?)
				c = check(check_no)
				@deleted_checks.push(c)
				@checks.delete(c)
			end
			@deleted_expenditures.push(exp)
			@expenditures.delete(exp)
		end
	end

	def delete_check(check_no)
		if (!check_no.nil?)
			c = check(check_no)
			(@expenditures.select { |e| e.check_no == check_no }).each { |e|
				@deleted_expenditures.push(e)
				@expenditures.delete(e)
			}
			@deleted_checks.push(c)
			@checks.delete(c)
		end
	end

	def balance
		#return @db.get_first_row("SELECT sum(-amount) FROM expenditures")[0]
		s = 0
		@expenditures.each do |e|
			s -= e.amount
		end
		return s
	end

	def checks_uncashed
		#return @db.get_first_row("SELECT
		#						 SUM(expenditures.amount),expenditures.ROWID,checks.check_no,checks.cashed,checks.ROWID
		#						 FROM expenditures,checks WHERE
		#						 expenditures.check_no IS NOT NULL AND
		#						 expenditures.check_no=checks.ROWID AND
		#						 checks.cashed=0")[0].to_f
		accum = 0.0
		@expenditures.each { |e|
			if (!e.check_no.nil?)
				c = check(e.check_no)
				if (!c.cashed)
					accum += e.amount
				end
			end
		}
		return accum
	end

	def checks_cashed
		accum = 0.0
		@expenditures.each { |e|
			if (!e.check_no.nil?)
				c = check(e.check_no)
				if (c.cashed)
					accum += e.amount
				end
			end
		}
		return accum
		#return @db.get_first_row("SELECT SUM(expenditures.amount),expenditures.ROWID,checks.check_no,checks.cashed,checks.ROWID FROM expenditures,checks WHERE expenditures.check_no IS NOT NULL AND expenditures.check_no=checks.ROWID AND checks.cashed=1")[0].to_f
	end

	def total_allocations(active_only=false)
		#return @db.get_first_row("SELECT sum(amount) FROM allocations")[0].to_f
		s = 0
		@allocations.each do |a|
			if (!active_only || !a.closed)
				s += a.amount
			end
		end
		return s
	end

	def total_open_allocations
		total_allocations(true)
	end

	def total_spent_for_allocations(active_only = false)
		#return @db.get_first_row("SELECT SUM(expenditures.amount) FROM
		#expenditures,allocations WHERE
		#allocations.ROWID=expenditures.allocid")[0]
		accum = 0.0
		@expenditures.each { |e|
			if (e.allocid > 0 && (!active_only || !allocation(e.allocid).closed))
				accum += e.amount
			end
		}
		return accum
	end

	def close_allocation(allocid)
		if (allocation(allocid).closed)
			return
		end
		allocation(allocid).closed = true
		#@db.execute("UPDATE allocations SET closed=1 WHERE ROWID=#{allocid}")
	end

	private :read_db
end

