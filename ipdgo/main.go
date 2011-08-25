package main

import (
	"bufio"
	"fmt"
	ipdparser "ipdgo/parser"
	"os"
)

const (
	FIELD_TYPE        = 2
	FIELD_NAME        = 3
	FIELD_DSID        = 5
	FIELD_USERID      = 6
	FIELD_UID         = 7
	FIELD_CID         = 8
	FIELD_APPDATA     = 9
	FIELD_COMPRESSION = 10
	FIELD_ENCRYPTION  = 11
	FIELD_DESCRIPTION = 15
	FIELD_SOURCE      = 17
	FIELD_HRT         = 22
	FIELD_RUID        = 23
)

func dumphex(buf []byte) {
	for i := 0; i < len(buf); i++ {
		fmt.Printf(" %02x", buf[i])
		if i%17 == 16 {
			fmt.Println()
		}
	}
	fmt.Println()
}

func u32le(buf []byte) uint32 {
	return uint32(buf[0]) + uint32(buf[1])<<8 + uint32(buf[2])<<16 + uint32(buf[3])<<24
}

type Dumper struct{}

func (Dumper) Field(kind uint8, data []byte) {
	println("--fh.len", len(data))
	switch kind {
	case FIELD_SOURCE:
		print("Source: ")
		switch data[0] {
		case 0:
			println("Unkown\n")
		case 1:
			println("Serial\n")
		case 2:
			println("OTA\n")
		case 3, 4:
			println("Code\n")
		case 5:
			println("Editor\n")
		default:
			println(data[0])
		}
	case FIELD_TYPE:
		types := []string{"Active",
			"Pending",
			"Ghost",
			"Obsolete",
			"Unknown",
			"Orphan",
			"Disallowed"}
		x := "?"
		num := u32le(data[0:4])
		if num < uint32(len(types)) {
			x = types[num]
		}
		println("Type:", x)
	case FIELD_UID:
		println("UID:", string(data))
	case FIELD_CID:
		println("CID:", string(data))
	case FIELD_NAME:
		println("Name:", string(data))
	case FIELD_DSID:
		println("DSID:", string(data))
	default:
		dumphex(data)
	}

}

func (Dumper) Record(dbid uint16, ver uint8, rhandle uint16, ruid uint32) {
	println("rh: ver", ver, "handle", rhandle, "uid", fmt.Sprintf("%x", ruid))
}

func (Dumper) Database(i int, name string) {
	println("db:", i, name)
}

func (Dumper) Header(ver uint8, numdb uint16) {
	println("ipd ver", ver, "numdb", numdb)
}

func (Dumper) End() {}

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

	err = ipdparser.Parse(bufio.NewReader(f), Dumper{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %s\n", err.String())
		os.Exit(3)
	}
}
