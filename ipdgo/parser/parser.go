package parser

import (
	bin "encoding/binary"
	"fmt"
	"io"
	"os"
	"reflect"
)

// http://na.blackberry.com/eng/devjournals/resources/journals/jan_2006/ipd_file_format.jsp
const (
	MAGIC = "Inter@ctive Pager Backup/Restore File\n"
)

type Processor interface {
	Header(version uint8, numdb uint16)
	Database(i int, name string)
	Field(kind uint8, data []byte)
	Record(dbid uint16, ver uint8, rhandle uint16, ruid uint32)
	End()
}

type parser struct {
	r    io.Reader
	proc Processor
}

type filehdr struct {
	Magic   [len(MAGIC)]byte
	Ver     uint8
	Numdb   uint16 // big endian
	Namesep uint8  // 0x00
}

type dbhdr struct {
	Dbid uint16
	Rlen uint32
}

type recordhdr struct {
	Ver     uint8
	Rhandle uint16
	Ruid    uint32
}

type fieldhdr struct {
	Len  uint16
	Type uint8
}

func readname(r io.Reader) (string, os.Error) {
	var length uint16
	err := bin.Read(r, bin.LittleEndian, &length)
	if err != nil {
		return "", err
	}

	buf := make([]byte, length)
	err = bin.Read(r, nil, buf)
	if err != nil {
		return "", err
	}

	return string(buf), nil
}

func errf(s string, args ...interface{}) os.Error {
	return os.NewError(fmt.Sprintf(s, args...))
}

func sizeof(x interface{}) int {
	return bin.TotalSize(reflect.ValueOf(x))
}

func (p parser) parsefield(left uint32) (uint32, os.Error) {
	var fh fieldhdr
	size := uint32(sizeof(fh))
	if left < size {
		return 0, errf("field header underflow (is %d, need %d)", left, size)
	}
	err := bin.Read(p.r, bin.LittleEndian, &fh)
	if err != nil {
		return 0, err
	}
	left -= size

	if left < uint32(fh.Len) {
		return 0, errf("field data underflow (is %d, need %d)", left, fh.Len)
	}
	// TODO: must we check for fh.Len == 0  =>  return 0 ?
	buf := make([]byte, fh.Len)
	err = bin.Read(p.r, nil, buf)
	if err != nil {
		return 0, err
	}
	left -= uint32(fh.Len)

	p.proc.Field(fh.Type, buf)

	return left, nil
}

func (p parser) run() os.Error {
	// parse header
	var h filehdr
	err := bin.Read(p.r, bin.BigEndian, &h)
	if err != nil {
		return err
	}
	if string(h.Magic[:]) != MAGIC {
		return errf("bad magic string")
	}
	if h.Ver != 2 {
		return errf("bad version: %d", h.Ver)
	}
	// XXX what about 0 dbs?
	if h.Namesep != 0 {
		return errf("bad sep")
	}

	p.proc.Header(h.Ver, h.Numdb)

	// read database names
	for i := uint16(0); i < h.Numdb; i++ {
		s, err := readname(p.r)
		if err != nil {
			return err
		}
		p.proc.Database(int(i), s)
	}

	for {
		var dh dbhdr
		err := bin.Read(p.r, bin.LittleEndian, &dh)
		if err == os.EOF { //TODO: check if read < sizeof(dh)
			break
		}
		if err != nil {
			return err
		}

		var rh recordhdr
		rest := dh.Rlen
		if rest < uint32(sizeof(rh)) {
			return errf("rlen too small")
		}
		rest -= uint32(sizeof(rh))
		err = bin.Read(p.r, bin.LittleEndian, &rh)

		p.proc.Record(dh.Dbid, rh.Ver, rh.Rhandle, rh.Ruid)

		for rest > 0 {
			rest, err = p.parsefield(rest)
			if err != nil {
				return err
			}
		}
	}

	p.proc.End()

	return nil
}

func Parse(r io.Reader, proc Processor) os.Error {
	return parser{r, proc}.run()
}
