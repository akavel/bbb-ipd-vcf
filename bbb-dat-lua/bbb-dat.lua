-- Decode Address Book from .dat files from unzipped (open with 7z) file .bbb
-- Based on code from "Blackberry IPD editor" by a.bittau@cs.ucl.ac.uk, and custom
-- explorations with a hex editor

function bigendian(s)
	local t = {s:byte(1, #s)}
	local n = 0
	for i = 1, #t do
		n = (n*256) + t[i]
	end
	return n
end
function littleendian(s)
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

function parse(f)
	local readn = function(n) return f:read(n) end
	local read8 = function() return f:read(1):byte() end
	local read16be = function() return bigendian(f:read(2)) end
	local read16le = function() return littleendian(f:read(2)) end
	local read32le = function() return littleendian(f:read(4)) end
	local readname = function() return readn(read16le()) end
	local clearname = function(name, namesep)
		assert(#name>0)
		assert(name:sub(-1):byte() == namesep)
		return name:sub(1, #name-1)
	end

	-- file header
	local magic = "Inter@ctive Pager Backup/Restore File\n"
	assert(readn(#magic) == magic, "incorrect magic ID")
	assert(read8() == 2, "incorrect version")
	local numdb = read16be()
	assert(numdb == 1, sprintf("incorrect numdb, expected 1, got %d; FIXME", numdb))
	local namesep = read8()
	assert(namesep == 0, "incorrect namesep")
	
	local readclearname = function() return clearname(readname(), namesep) end
	
	-- database names
	for i = 1, numdb do
		print(sprintf('DB %d "%s"', i-1, readclearname()))
	end
	--[[
	-- database records
	while true do
		local dbId = read16le()
		local recLen = read32le()
		
		_ = readn(7) -- drop some data which seems not useful to us {Ver uint8; Rhandle uint16; Ruid uint32}
		recLen = recLen - 7
		while recLen > 0 do
			
		end
	end
	]]
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
