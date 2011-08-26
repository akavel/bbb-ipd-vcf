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
			fmt.Printf("  | %s\n", string(buf[i-16:i+1]))
		}
	}
	tail := len(buf) % 17
	if tail != 0 {
		for i := tail; i < 17; i++ {
			fmt.Printf("   ")
		}
		fmt.Printf("  | %s\n", string(buf[len(buf)-tail:]))
	}
}

func u32le(buf []byte) uint32 {
	return uint32(buf[0]) + uint32(buf[1])<<8 + uint32(buf[2])<<16 + uint32(buf[3])<<24
}

type Dumper struct{}

func (Dumper) Field(kind uint8, data []byte) {
	println("--fh.len", len(data))
	if len(data) == 0 {
		println(" ZERO len, type", kind)
		return
	}
	switch kind {
	case FIELD_SOURCE:
		fmt.Printf("Source: ")
		switch data[0] {
		case 0:
			fmt.Println("Unkown")
		case 1:
			fmt.Println("Serial")
		case 2:
			fmt.Println("OTA")
		case 3, 4:
			fmt.Println("Code")
		case 5:
			fmt.Println("Editor")
		default:
			fmt.Printf("? 0x%x\n", data)
		}
		if len(data) > 1 {
			dumphex(data)
		}
	case FIELD_TYPE:
		types := []string{"Active",
			"Pending",
			"Ghost",
			"Obsolete",
			"Unknown",
			"Orphan",
			"Disallowed"}
		if len(data) < 4 {
			println("Type: ??")
			dumphex(data)
			break
		}
		num := u32le(data)
		if num >= uint32(len(types)) {
			println("Type: ?")
		} else {
			println("Type:", types[num])
		}
		if len(data) > 4 {
			dumphex(data)
		}
	case FIELD_UID:
		println("UID:", string(data))
	case FIELD_CID:
		println("CID:", string(data))
	case FIELD_NAME:
		println("Name:", string(data))
	case 4:
		println("SMS text (?):", string(data))
	case FIELD_DSID:
		println("DSID:", string(data))
	case FIELD_DESCRIPTION:
		println("Description:", string(data))
	case FIELD_RUID:
		fmt.Printf("RUID: %x\n", u32le(data))
	case FIELD_USERID:
		if len(data) < 4 {
			fmt.Printf("User ID: ?? 0x%x", data)
			break
		}
		fmt.Printf("User ID: %d\n", int32(u32le(data)))
	case FIELD_COMPRESSION:
		print("Compression: ")
		if len(data) < 4 {
			println("none?")
			break
		}
		println(int32(u32le(data)))
	case FIELD_ENCRYPTION:
		print("Encryption: ")
		if len(data) < 4 {
			println("none?")
			break
		}
		switch x := int32(u32le(data)); x {
		case 6:
			println("RIM BIS")
		case 2:
			println("RIM")
		case 1:
			println("none")
		default:
			println(x)
		}
	case FIELD_APPDATA:
		println("App data")
		dumphex(data)
	case FIELD_HRT:
		println("HRT")
		dumphex(data)
	default:
		println("Field type", kind, "len", len(data))
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
