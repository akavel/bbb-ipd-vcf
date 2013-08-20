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
	local kinds_rev = {
		EMAIL=0x01,
		WORK_FAX=0x03, -- note: special handling
		PHONE_WORK=0x06,
		PHONE_HOME=0x07, -- ?
		PHONE_MOBILE=0x08,
		PHONE_PAGER=0x09,
		--PHONE_WORK2=0x10,
		PHONE_OTHER=0x12,
		PHONE_MOBILE2=0x13,
		NAME=0x20,
		COMPANY=0x21,
		WORK_ADDRESS1=0x23,
		WORK_ADDRESS2=0x24,
		WORK_CITY=0x26,
		WORK_POSTCODE=0x28,
		TITLE=0x37,
		HOME_ADDRESS1=0x3d,
		NOTES=0x40,
		HOME_CITY=0x45,
		HOME_POSTCODE=0x47,
		HOME_COUNTRY=0x48,
		BIRTHDAY=0x52,
		ANNIVERSARY=0x53,
		
		-- UTF-8 encoded
		NAME_UTF8= -0xa0,
		COMPANY_UTF8= -0xa1,
		WORK_ADDRESS1_UTF8= -0xa3,
	}
	local kinds = {}
	for k, v in pairs(kinds_rev) do
		kinds[v]=k
	end

	local indent = indent or ''
	for _, v in ipairs(recs) do
		if v.kind==nil or v.kind==0x0a then
			--print(indent .. "RECORD")
			v.value = parseRec(v.value)
			decode(v.value, indent .. "  ")
		elseif (v.kind==0x54 or v.kind==0x02) and v.value==string.char(0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff) then
			-- skip
		elseif v.kind==0x51 and v.value==string.char(0, 0, 0, 0) then
			-- skip
		elseif v.kind==0x03 and v.value=='Default' then
			-- skip
		elseif v.kind==0x05 or v.kind==0x55 or v.kind==0x34 or v.kind==0x35 or v.kind==0x2c then
			-- skip; unknown meaning
		elseif v.kind==0x4d then
			-- skip; image
		elseif kinds[v.kind] ~= nil then
			local kind = kinds[v.kind]
			v[kind] = v[kind] or {}
			table.insert(v[kind], clearname(v.value, 0))
			--print(indent .. sprintf("%s=%q", kind, v[kind]))
		elseif kinds[-v.kind] ~= nil then
			-- UTF-8 encoded, starts with a NUL byte
			assert(v.value:sub(1,1):byte() == 0)
			local kind = kinds[-v.kind]
			kind = kind:sub(1, #kind-5) -- strip _UTF8
			v[kind] = v[kind] or {}
			table.insert(v[kind], v.value:sub(2))
			--print(indent .. sprintf("%s=%q", kind, v[kind]))
		else
			print(indent .. sprintf("KIND=0x%02x:", v.kind))
			hex_dump(v.value)
		end
	end
end

function vcardif(record, code, vcard)
	if record[code]==nil then
		return
	end
	for _, v in ipairs(record[code]) do
		print(sprintf('%s:%s', vcard, v))
	end
end
function phoneif(record, code, vcard)
	vcardif(record, code, 'TEL;TYPE='..vcard)
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
	
	for _, r in ipairs(recs) do
		r = r.value[4].value
		for k,v in pairs(r) do 
			for kk,vv in pairs(v) do print(kk,vv) end
		end
		--r = r.value
		print('BEGIN:VCARD')
		print('VERSION:3.0')
		print(sprintf('N:%s;%s;;%s;',
			r.NAME[2] or '', r.NAME[1] or '', r.TITLE[1] or ''))
		print(sprintf('FN:%s', table.concat(r.NAME, ' ')))
		phoneif(r, 'WORK_FAX', 'FAX')
		phoneif(r, 'PHONE_MOBILE', 'CELL')
		phoneif(r, 'PHONE_MOBILE2', 'CELL')
		phoneif(r, 'PHONE_WORK', 'WORK')
		phoneif(r, 'PHONE_HOME', 'HOME')
		phoneif(r, 'PHONE_PAGER', 'PAGER')
		phoneif(r, 'PHONE_OTHER', 'OTHER')
		vcardif(r, 'COMPANY', 'ORG')
		vcardif(r, 'EMAIL', 'EMAIL')
		
		local t = {}
		if r.WORK_ADDRESS1 then table.insert(t, table.concat(r.WORK_ADDRESS1, ' ')) end
		if r.WORK_ADDRESS2 then table.insert(t, table.concat(r.WORK_ADDRESS2, ' ')) end
		local adr = sprintf(';;%s;%s;;%s;%s',
			table.concat(t, ' '),
			table.concat(r.WORK_CITY, ' '),
			table.concat(r.WORK_POSTCODE, ' '),
			table.concat(r.WORK_COUNTRY, ' '))
		if adr ~= ';;;;;;' then
			print('ADR;TYPE=WORK:', adr)
		end
		
		local t = {}
		if r.HOME_ADDRESS1 then table.insert(t, table.concat(r.HOME_ADDRESS1, ' ')) end
		if r.HOME_ADDRESS2 then table.insert(t, table.concat(r.HOME_ADDRESS2, ' ')) end
		local adr = sprintf(';;%s;%s;;%s;%s',
			table.concat(t, ' '),
			table.concat(r.HOME_CITY, ' '),
			table.concat(r.HOME_POSTCODE, ' '),
			table.concat(r.HOME_COUNTRY, ' '))
		if adr ~= ';;;;;;' then
			print('ADR;TYPE=HOME:', adr)
		end
		
		if r.NOTES then
			print('NOTE:', table.concat(r.NOTES, ' '):gsub('[\r\n]', '\\n'))
		end
		
		print('END:VCARD')
	end
end

main()
