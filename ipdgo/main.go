package main

import (
	bin "encoding/binary"
	"bufio"
	"fmt"
	"io"
	"os"
	"unsafe"
)

// http://na.blackberry.com/eng/devjournals/resources/journals/jan_2006/ipd_file_format.jsp
const (
	MAGIC = "Inter@ctive Pager Backup/Restore File\n"
)

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

func ipd2xml(f io.Reader) os.Error {
	// parse header
	var h filehdr
	err := bin.Read(f, bin.BigEndian, &h)
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

	// print header
	fmt.Printf(`<?xml version="1.0" encoding="UTF-8"?>`+
		"\n<ipd version=\"%d\">\n",
		h.Ver)

	// read database names
	db := make([]string, 0)
	for i := uint16(0); i < h.Numdb; i++ {
		s, err := readname(f)
		if err != nil {
			return err
		}
		db = append(db, s)
	}

	for {
		var dh dbhdr
		err := bin.Read(f, bin.LittleEndian, &dh)
		if err == os.EOF { //TODO: check if read < sizeof(dh)
			break
		}
		if err != nil {
			return err
		}

		var rh recordhdr
		if dh.Rlen < uint32(unsafe.Sizeof(rh)) {
			return errf("rlen too small")
		}

		dh.Rlen -= uint32(unsafe.Sizeof(rh))
		data := make([]byte, dh.Rlen)
		err = bin.Read(f, nil, &data)
		if err != nil {
			return err
		}
		//TODO: save data
		println("data[", len(data), "]")

	}

	fmt.Printf("</ipd>\n")
	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: bb FILE.ipd\n")
		os.Exit(1)
	}

	fn := os.Args[1]
	f, err := os.Open(fn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: Cannot open file \"%s\"!\n", fn)
		os.Exit(2)
	}
	//defer f.Close()

	err = ipd2xml(bufio.NewReader(f))
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %s\n", err.String())
		os.Exit(3)
	}
}
