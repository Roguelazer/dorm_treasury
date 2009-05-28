# East Dorm Treasury Treasury Model
#
# Copyright (C) 2008-2009 James Brown <jbrown@cs.hmc.edu>
#
# This file is part of East Dorm Treasury.
#
# East Dorm Treasury is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# East Dorm Treasury is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with East Dorm Treasury.  If not, see <http://www.gnu.org/licenses/>.
#
require 'sqlite3'
require 'primitives'
require 'exceptions'

class Treasury
	def initialize(filename)
		@db = SQLite3::Database.new(filename)
		@expenditures = []
		@dirty_expenditures = Hash.new
		@added_expenditures = []
		@deleted_expenditures = []
		@allocations = []
		@dirty_allocations = Hash.new
		@added_allocations = []
		@deleted_allocations = []
		@checks = []
		@dirty_checks = Hash.new
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
		@dirty_allocations.each { |a,val|
			@db.execute("UPDATE allocations SET date=?,name=?,amount=?,closed=? WHERE ROWID=?", a.date, a.name,
					   a.amount, a.closed ? "1" : "0", a.allocid)
		}
		@dirty_allocations = Hash.new
		@dirty_expenditures.each { |e,val|
			@db.execute("UPDATE expenditures SET allocid=?,date=?,name=?,amount=? WHERE ROWID=?",
					   e.allocid,e.date,e.name,e.amount,e.expid) 
		}
		@dirty_expenditures = Hash.new
		@dirty_checks.each { |c,val|
			@db.execute("UPDATE checks SET cashed=? WHERE ROWID=?",
						c.cashed ? "1" : "0", c.cid)
		}
		@dirty_checks = Hash.new
		@added_allocations.each { |a|
			@db.execute("INSERT INTO allocations (date, name, amount, closed, ROWID) VALUES(?,?,?,?,?)",
						a.date, a.name, a.amount, a.closed ? "1" : "0", a.allocid)
		}
		@added_allocations = []
		@added_expenditures.each { |e|
			if (!e.check_no.nil?)
				@db.execute("INSERT INTO expenditures (allocid, date, name, amount,check_no,ROWID) VALUES(?,?,?,?,?,?)", e.allocid, e.date, e.name, e.amount, e.cid, e.expid)
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
			a = Allocation.new(allocation[0], allocation[1], allocation[2], allocation[3], allocation[4]) { |a|
				@dirty_allocations[a] = true
			}
			@allocations.push(a)
		}
		@db.execute("SELECT checks.check_no,checks.cashed,checks.ROWID FROM expenditures,checks WHERE expenditures.check_no IS NOT NULL AND expenditures.check_no=checks.ROWID") { |e|
			c = Check.new(e[0],e[1],e[2]) { |c|
				@dirty_checks[c] = true
			}
			@checks.push(c)
		}
		@db.execute("SELECT ROWID,date,name,amount,allocid,check_no FROM expenditures") { |expenditure|
			if (expenditure[5].nil?)
				e = Expenditure.new(expenditure[0],expenditure[4],expenditure[1],expenditure[2],expenditure[3], nil) { |e|
					@dirty_expenditures[e] = true
				}
				@expenditures.push(e)
			else
				e = Expenditure.new(expenditure[0],expenditure[4],expenditure[1],expenditure[2],expenditure[3], check_by_cid(expenditure[5])) { |e|
					@dirty_expenditures[e] = true
				}
				@expenditures.push(e)
			end
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
	end

	def expenditure(expid)
		e = @expenditures.select { |item| item.expid == expid.to_i }
		if (e.size == 0)
			raise ExpenditureNotFoundError.new()
		elsif (e.size > 1)
			raise DuplicateExpenditureError.new()
		end
		return e[0]
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
	end

	def expenditure_with(check)
		c = @expenditures.select { |e| e.check == check }
		if (c.size == 0)
			raise ExpenditureNotFoundError.new()
		elsif (c.size > 1)
			raise DuplicateExpenditureError.new()
		else
			return c[0]
		end
	end

	def expenditure_for(cid)
		c = @expenditures.select { |e| e.cid == cid }
		if (c.size == 0)
			raise ExpenditureNotFoundError.new()
		elsif (c.size > 1)
			raise DuplicateExpenditureError.new()
		else
			return c[0]
		end
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

	def check_by_cid(cid)
		c = @checks.select { |i| i.cid == cid.to_i }
		if (c.size == 0)
			raise CheckNotFoundError.new(cid)
		elsif (c.size > 1)
			raise DuplicateCheckError.new(cid)
		end
		return c[0]
	end

	def each_check
		@checks.each { |c| yield c }
	end

	def each_check_with_expenditure
		@checks.each { |c|
			yield c,expenditure_with(c)
		}
	end

	def add_allocation(date, name, amount, closed=false)
		allocid = next_allocid()
		allocation = Allocation.new(allocid, date, name, amount, closed) { |a|
			@dirty_allocations[a] = true
		}
		@allocations.push(allocation)
		@added_allocations.push(allocation)
		return allocation
	end

	def add_expenditure(allocid, date, name, amount, check_no = "NULL")
		expid = next_expid()
		if (check_no == "NULL")
			expenditure = Expenditure.new(expid, allocid, date, name, amount,nil,nil) { |e|
				@dirty_expenditures[e] = true
			}
		else
			cid = next_cid()
			c = Check.new(check_no, allocid.to_i == -1 ? 1 : 0, cid) { |c|
				@dirty_checks[c] = true
			}
			expenditure = Expenditure.new(expid,allocid,date,name,amount,c) { |e|
				@dirty_expenditures[e] = true
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
	end

	def delete_allocation(allocid)
		if (!allocid.nil?)
			ret = []
			alloc = allocation(allocid)
			expenditures_for(allocid) { |e|
				ret += delete_expenditure(e.expid)
			}
			@deleted_allocations.push(alloc)
			@allocations.delete(alloc)
			ret.push(alloc)
			return ret
		end
	end

	def delete_expenditure(expid)
		if (!expid.nil?)
			ret = []
			exp = expenditure(expid)
			if (!exp.check_no.nil?)
				begin
					c = check(exp.check_no)
					@deleted_checks.push(c)
					@checks.delete(c)
					ret.push(c)
				rescue DuplicateCheckError => e
				end
			end
			@deleted_expenditures.push(exp)
			@expenditures.delete(exp)
			ret.push(exp)
			return ret
		end
	end

	def delete_check(check_no)
		if (!check_no.nil?)
			ret = []
			c = check(check_no)
			e = expenditure_for(c.cid)
			if (!e.nil?)
				@deleted_expenditures.push(e)
				@expenditures.delete(e)
				ret.push(e)
			end
			@deleted_checks.push(c)
			@checks.delete(c)
			ret.push(c)
			return ret
		end
	end

	def delete_check_by_cid(cid)
		if (!cid.nil?)
			ret = []
			c = check_by_cid(cid)
			e = expenditure_for(c.cid)
			if (!e.nil?)
				@deleted_expenditures.push(e)
				@expenditures.delete(e)
				ret.push(e)
			end
			@deleted_checks.push(c)
			@checks.delete(c)
			ret.push(c)
			return ret
		end
	end

	def balance
		s = 0
		@expenditures.each do |e|
			s -= e.amount
		end
		return s
	end

	def checks_uncashed
		accum = 0.0
		@expenditures.each { |e|
			if (!e.check.nil?)
				if (!e.check.cashed)
					accum += e.amount
				end
			end
		}
		return accum
	end

	def checks_cashed
		accum = 0.0
		@expenditures.each { |e|
			if (!e.check.nil?)
				if (e.check.cashed)
					accum += e.amount
				end
			end
		}
		return accum
	end

	def total_allocations(active_only=false)
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
	end

	private :read_db
end

