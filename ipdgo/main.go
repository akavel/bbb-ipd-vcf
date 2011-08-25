package main

import (
	"bufio"
	"fmt"
	ipdparser "ipdgo/parser"
	"os"
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

type Dumper struct{}

func (Dumper) Field(kind uint8, data []byte) {
	println("fh.len", len(data))
	dumphex(data)
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
