-- Decode Address Book from .dat files from unzipped (open with 7z) file .bbb
-- Based on code from "Blackberry IPD editor" by a.bittau@cs.ucl.ac.uk, and custom
-- explorations with a hex editor

function bigendian(s)
	if s==nil then
		return nil
	end
	local t = {s:byte(1, #s)}
	local n = 0
	for i = 1, #t do
		n = (n*256) + t[i]
	end
	return n
end
function littleendian(s)
	if s==nil then
		return nil
	end
	local t = {s:byte(1, #s)}
	local n = 0
	for i = 1, #t do
		n = n + t[i]*256^(i-1)
	end
	return n
end
function sprintf(fmt, ...)
	return fmt:format(...)
end

local readn = function(f, n) return f:read(n) end
local read8 = function(f) return bigendian(f:read(1)) end
local read16be = function(f) return bigendian(f:read(2)) end
local read16le = function(f) return littleendian(f:read(2)) end
local read32le = function(f) return littleendian(f:read(4)) end
local readname = function(f) return readn(f, read16le(f)) end
local clearname = function(name, namesep)
	assert(#name>0)
	assert(name:sub(-1):byte() == namesep)
	return name:sub(1, #name-1)
end

function stringreader(s)
	return setmetatable({}, {__index = {
		read = function(self, n)
			if #s==0 then
				return nil
			end
			local head = s:sub(1, n)
			s = s:sub(n+1)
			return head
		end
	}})
end
-- Author: sdonovan
-- License: MIT/X11 
-- [first] begin dump at 16 byte-aligned offset containing 'first' byte
-- [last] end dump at 16 byte-aligned offset containing 'last' byte
function hex_dump(buf,first,last)
	local function align(n) return math.ceil(n/16) * 16 end
	for i=(align((first or 1)-16)+1),align(math.min(last or #buf,#buf)) do
		if (i-1) % 16 == 0 then io.write(string.format('%08X  ', i-1)) end
		io.write( i > #buf and '   ' or string.format('%02X ', buf:byte(i)) )
		if i %  8 == 0 then io.write(' ') end
		if i % 16 == 0 then io.write( buf:sub(i-16+1, i):gsub('%c','.'), '\n' ) end
	end
end

function parse(f)
	-- file header
	local magic = "Inter@ctive Pager Backup/Restore File\n"
	assert(readn(f, #magic) == magic, "incorrect magic ID")
	assert(read8(f) == 2, "incorrect version")
	local numdb = read16be(f)
	assert(numdb == 1, sprintf("incorrect numdb, expected 1, got %d; FIXME", numdb))
	local namesep = read8(f)
	assert(namesep == 0, "incorrect namesep")
	
	local readclearname = function(f) return clearname(readname(f), namesep) end
	
	-- database names
	for i = 1, numdb do
		print(sprintf('DB %d "%s"', i-1, readclearname(f)))
	end
	
	-- database records
	local recs = {}
	while true do
		local dbId = read16le(f)
		local recLen = read32le(f)
		if dbId == nil then
			break
		end
		
		if dbId ~= 0xffff then -- WTF? some empty (?) database record
			_ = readn(f, 7) -- drop some data which seems not useful to us {Ver uint8; Rhandle uint16; Ruid uint32}
			recLen = recLen - 7
			recs[#recs+1] = {value=readn(f, recLen)}
		end
	end
	return recs
end

function parseRec(buf)
	local f = stringreader(buf)
	local t = {}
	while true do
		local fieldlen = read16le(f)
		local kind = read8(f)
		local value = readn(f, fieldlen)
		
		if fieldlen == nil then
			return t
		end
		
		t[#t+1] = {kind=kind, value=value}
	end
end

function decode(recs, indent)
	local indent = indent or ''
	for _, v in ipairs(recs) do
		if v.kind==nil or v.kind==0x0a then
			print(indent .. "RECORD")
			decode(parseRec(v.value), indent .. "  ")
		elseif v.kind==0x20 then
			print(indent .. sprintf("NAME=%q", clearname(v.value, 0)))
		elseif (v.kind>=0x06 and v.kind<=0x09) or v.kind==0x13 or v.kind==0x12 then
			print(indent .. sprintf("PHONE=%q", clearname(v.value, 0)))
		elseif v.kind==0x01 then
			print(indent .. sprintf("EMAIL=%q", clearname(v.value, 0)))
		elseif v.kind==0x23 or v.kind==0x24 or v.kind==0x3d then
			print(indent .. sprintf("ADDRESS=%q", clearname(v.value, 0)))
		elseif v.kind==0x26 or v.kind==0x45 then
			print(indent .. sprintf("CITY=%q", clearname(v.value, 0)))
		elseif v.kind==0x21 then
			print(indent .. sprintf("COMPANY=%q", clearname(v.value, 0)))
		elseif v.kind==0x40 then
			print(indent .. sprintf("COMMENT?=%q", clearname(v.value, 0)))
		elseif v.kind==0x47 or v.kind==0x28 then
			print(indent .. sprintf("AREA_CODE?=%q", clearname(v.value, 0)))
		elseif v.kind==0x48 then
			print(indent .. sprintf("COUNTRY?=%q", clearname(v.value, 0)))
		elseif v.kind==0x52 or v.kind==0x53 then
			print(indent .. sprintf("BIRTHDAY?=%q", clearname(v.value, 0)))
		elseif v.kind==0x37 then
			print(indent .. sprintf("TITLE?=%q", clearname(v.value, 0)))
		elseif (v.kind==0x54 or v.kind==0x02) and
				v.value==string.char(0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff) then
			-- skip
		elseif v.kind==0x51 and v.value==string.char(0, 0, 0, 0) then
			-- skip
		elseif v.kind==0x03 then
			if v.value=='Default' then
				-- skip
			else
				print(indent .. sprintf("PHONE?=%q", clearname(v.value, 0)))
			end
		elseif v.kind==0x05 or v.kind==0x55 or v.kind==0x34 or v.kind==0x35 or v.kind==0x2c then
			-- skip; unknown meaning
		elseif v.kind==0x4d then
			-- skip; image
		elseif v.kind==0xa0 then
			-- WTF? names starting with NUL byte
			assert(v.value:sub(1,1):byte() == 0)
			print(indent .. sprintf("NAME_UTF8?=%q", v.value:sub(2)))
		elseif v.kind==0xa3 then
			-- WTF? address starting with NUL byte
			assert(v.value:sub(1,1):byte() == 0)
			print(indent .. sprintf("ADDRESS_UTF8?=%q", v.value:sub(2)))
		elseif v.kind==0xa1 then
			-- WTF? company starting with NUL byte
			assert(v.value:sub(1,1):byte() == 0)
			print(indent .. sprintf("COMPANY_UTF8?=%q", v.value:sub(2)))
		else
			print(indent .. sprintf("KIND=0x%02x:", v.kind))
			hex_dump(v.value)
		end
	end
end

function main()
	if #arg ~= 1 then
		print(("USAGE: %s FILE.dat\n" .. "where FILE.dat is extracted from .bbb BlackBerry backup file"):format(arg[0]))
		os.exit(1)
	end
	
	local f = assert(io.open(arg[1], 'rb'))
	recs = parse(f)
	f:close()
	
	decode(recs)
end

main()
