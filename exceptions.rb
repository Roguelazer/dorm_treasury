# East Dorm Treasury Exceptions
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

class CheckNotFoundError < RuntimeError
	def initialize(check_no)
		@check_no = check_no
	end

	def to_s
		"Check ##{@check_no} not found!"
	end
end

class DuplicateCheckError < RuntimeError
	def initialize(check_no)
		@check_no = check_no
	end

	def to_s
		"Check ##{@check_no} has duplicates!"
	end
end

class ExpenditureNotFoundError < RuntimeError
end

class DuplicateExpenditureError < RuntimeError
end
