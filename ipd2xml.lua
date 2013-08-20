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

-- http://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1252.TXT
-- https://gist.github.com/akavel/6285490
local _tab_win1252_to_utf8 = {
[0x80]= {0xe2, 0x82, 0xac},
[0x81]= nil,
[0x82]= {0xe2, 0x80, 0x9a},
[0x83]= {0xc6, 0x92},
[0x84]= {0xe2, 0x80, 0x9e},
[0x85]= {0xe2, 0x80, 0xa6},
[0x86]= {0xe2, 0x80, 0xa0},
[0x87]= {0xe2, 0x80, 0xa1},
[0x88]= {0xcb, 0x86},
[0x89]= {0xe2, 0x80, 0xb0},
[0x8a]= {0xc5, 0xa0},
[0x8b]= {0xe2, 0x80, 0xb9},
[0x8c]= {0xc5, 0x92},
[0x8d]= nil,
[0x8e]= {0xc5, 0xbd},
[0x8f]= nil,
[0x90]= nil,
[0x91]= {0xe2, 0x80, 0x98},
[0x92]= {0xe2, 0x80, 0x99},
[0x93]= {0xe2, 0x80, 0x9c},
[0x94]= {0xe2, 0x80, 0x9d},
[0x95]= {0xe2, 0x80, 0xa2},
[0x96]= {0xe2, 0x80, 0x93},
[0x97]= {0xe2, 0x80, 0x94},
[0x98]= {0xcb, 0x9c},
[0x99]= {0xe2, 0x84, 0xa2},
[0x9a]= {0xc5, 0xa1},
[0x9b]= {0xe2, 0x80, 0xba},
[0x9c]= {0xc5, 0x93},
[0x9d]= nil,
[0x9e]= {0xc5, 0xbe},
[0x9f]= {0xc5, 0xb8},
[0xa0]= {0xc2, 0xa0},
[0xa1]= {0xc2, 0xa1},
[0xa2]= {0xc2, 0xa2},
[0xa3]= {0xc2, 0xa3},
[0xa4]= {0xc2, 0xa4},
[0xa5]= {0xc2, 0xa5},
[0xa6]= {0xc2, 0xa6},
[0xa7]= {0xc2, 0xa7},
[0xa8]= {0xc2, 0xa8},
[0xa9]= {0xc2, 0xa9},
[0xaa]= {0xc2, 0xaa},
[0xab]= {0xc2, 0xab},
[0xac]= {0xc2, 0xac},
[0xad]= {0xc2, 0xad},
[0xae]= {0xc2, 0xae},
[0xaf]= {0xc2, 0xaf},
[0xb0]= {0xc2, 0xb0},
[0xb1]= {0xc2, 0xb1},
[0xb2]= {0xc2, 0xb2},
[0xb3]= {0xc2, 0xb3},
[0xb4]= {0xc2, 0xb4},
[0xb5]= {0xc2, 0xb5},
[0xb6]= {0xc2, 0xb6},
[0xb7]= {0xc2, 0xb7},
[0xb8]= {0xc2, 0xb8},
[0xb9]= {0xc2, 0xb9},
[0xba]= {0xc2, 0xba},
[0xbb]= {0xc2, 0xbb},
[0xbc]= {0xc2, 0xbc},
[0xbd]= {0xc2, 0xbd},
[0xbe]= {0xc2, 0xbe},
[0xbf]= {0xc2, 0xbf},
[0xc0]= {0xc3, 0x80},
[0xc1]= {0xc3, 0x81},
[0xc2]= {0xc3, 0x82},
[0xc3]= {0xc3, 0x83},
[0xc4]= {0xc3, 0x84},
[0xc5]= {0xc3, 0x85},
[0xc6]= {0xc3, 0x86},
[0xc7]= {0xc3, 0x87},
[0xc8]= {0xc3, 0x88},
[0xc9]= {0xc3, 0x89},
[0xca]= {0xc3, 0x8a},
[0xcb]= {0xc3, 0x8b},
[0xcc]= {0xc3, 0x8c},
[0xcd]= {0xc3, 0x8d},
[0xce]= {0xc3, 0x8e},
[0xcf]= {0xc3, 0x8f},
[0xd0]= {0xc3, 0x90},
[0xd1]= {0xc3, 0x91},
[0xd2]= {0xc3, 0x92},
[0xd3]= {0xc3, 0x93},
[0xd4]= {0xc3, 0x94},
[0xd5]= {0xc3, 0x95},
[0xd6]= {0xc3, 0x96},
[0xd7]= {0xc3, 0x97},
[0xd8]= {0xc3, 0x98},
[0xd9]= {0xc3, 0x99},
[0xda]= {0xc3, 0x9a},
[0xdb]= {0xc3, 0x9b},
[0xdc]= {0xc3, 0x9c},
[0xdd]= {0xc3, 0x9d},
[0xde]= {0xc3, 0x9e},
[0xdf]= {0xc3, 0x9f},
[0xe0]= {0xc3, 0xa0},
[0xe1]= {0xc3, 0xa1},
[0xe2]= {0xc3, 0xa2},
[0xe3]= {0xc3, 0xa3},
[0xe4]= {0xc3, 0xa4},
[0xe5]= {0xc3, 0xa5},
[0xe6]= {0xc3, 0xa6},
[0xe7]= {0xc3, 0xa7},
[0xe8]= {0xc3, 0xa8},
[0xe9]= {0xc3, 0xa9},
[0xea]= {0xc3, 0xaa},
[0xeb]= {0xc3, 0xab},
[0xec]= {0xc3, 0xac},
[0xed]= {0xc3, 0xad},
[0xee]= {0xc3, 0xae},
[0xef]= {0xc3, 0xaf},
[0xf0]= {0xc3, 0xb0},
[0xf1]= {0xc3, 0xb1},
[0xf2]= {0xc3, 0xb2},
[0xf3]= {0xc3, 0xb3},
[0xf4]= {0xc3, 0xb4},
[0xf5]= {0xc3, 0xb5},
[0xf6]= {0xc3, 0xb6},
[0xf7]= {0xc3, 0xb7},
[0xf8]= {0xc3, 0xb8},
[0xf9]= {0xc3, 0xb9},
[0xfa]= {0xc3, 0xba},
[0xfb]= {0xc3, 0xbb},
[0xfc]= {0xc3, 0xbc},
[0xfd]= {0xc3, 0xbd},
[0xfe]= {0xc3, 0xbe},
[0xff]= {0xc3, 0xbf},
}
-- try to replace characters over 0x7f with some unicode replacement or something;
-- problem is that I'm not sure what's the codepage in IPD files; assuming win-1252 for now.
function ipd_to_utf8(s)
	return s:gsub('[\128-\255]', function(c)
		local c = string.byte(c)
		local utf8 = assert(_tab_win1252_to_utf8[c], sprintf("unknown win1252 char 0x%02x in '%s'", c, s))
		return string.char(unpack(utf8))
	end)
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
function xmlnode(name, value)
	return ("<%s>%s</%s>"):format(
		name,
		value:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('\'', '&apos;'):gsub('"', '&quot;'),
		name
	)
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
			print(indent .. "<RECORD>")
			v.value = parseRec(v.value)
			decode(v.value, indent .. "  ")
			print(indent .. "</RECORD>")
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
			print(indent .. xmlnode(kind, ipd_to_utf8(clearname(v.value, 0))))
		elseif kinds[-v.kind] ~= nil then
			-- UTF-8 encoded, starts with a NUL byte
			assert(v.value:sub(1,1):byte() == 0)
			local kind = kinds[-v.kind]
			kind = kind:sub(1, #kind-5) -- strip _UTF8
			print(indent .. xmlnode(kind, v.value:sub(2)))
		else
			print(indent .. xmlnode(("KIND_0x%02x"):format(v.kind), v.value:gsub('.', function(x)
				return ("%02x"):format(x)
			end)))
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
	
	print('<IPD>')
	
	local f = assert(io.open(arg[1], 'rb'))
	recs = parse(f)
	f:close()
	
	decode(recs)
	
	print('</IPD>')
end

main()
