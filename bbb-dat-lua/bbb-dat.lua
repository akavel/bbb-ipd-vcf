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
		
		_ = readn(f, 7) -- drop some data which seems not useful to us {Ver uint8; Rhandle uint16; Ruid uint32}
		recLen = recLen - 7
		rec = parseRec(readn(f, recLen))
		for _, v in ipairs(rec) do
			
			--print(sprintf("0x%02x %q", v.kind, v.value))
		end
		recs[#recs+1] = rec
	end
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

function main()
	if #arg ~= 1 then
		print(("USAGE: %s FILE.dat\n" .. "where FILE.dat is extracted from .bbb BlackBerry backup file"):format(arg[0]))
		os.exit(1)
	end
	
	local f = assert(io.open(arg[1], 'rb'))
	parse(f)
	f:close()
end

main()
