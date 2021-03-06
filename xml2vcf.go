package main

// vCard 3.0 RFC: http://tools.ietf.org/html/rfc2426

import (
	"bitbucket.org/akavel/vcard"
	"encoding/xml"
	"fmt"
	"io/ioutil"
	"os"
)

type RECORD struct {
	XMLName xml.Name `xml:"RECORD"`
	EMAIL   string   //

	WORK_FAX      string //
	PHONE_WORK    string //
	PHONE_HOME    string //
	PHONE_MOBILE  string //
	PHONE_PAGER   string //
	PHONE_OTHER   string //
	PHONE_MOBILE2 string // NOTE: added identical as MOBILE

	NAME []string //

	COMPANY string //

	WORK_ADDRESS1 string //
	WORK_ADDRESS2 string //
	WORK_CITY     string //
	WORK_POSTCODE string //

	TITLE string //

	HOME_ADDRESS1 string //

	NOTES string //

	HOME_CITY     string //
	HOME_POSTCODE string //
	HOME_COUNTRY  string //

	BIRTHDAY    string //
	ANNIVERSARY string /* TODO: only vCard 4.0+ */
}

type IPD struct {
	XMLName xml.Name `xml:"IPD"`
	Records []RECORD `xml:"RECORD>RECORD"`
}

func addphone(v *vcard.VCard, number string, kind ...string) {
	if number == "" {
		return
	}
	v.Telephones = append(v.Telephones, vcard.Telephone{
		Type:   kind,
		Number: number,
	})
}

func main() {
	// read STDIN as IPD-XML file generated by bbb-dat.lua
	buf, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		panic(err)
	}
	var ipd IPD
	err = xml.Unmarshal(buf, &ipd)
	if err != nil {
		panic(err)
	}

	//fmt.Printf("%#v\n", ipd)
	_ = fmt.Printf

	var book vcard.AddressBook
	for _, r := range ipd.Records {
		var v vcard.VCard

		if r.EMAIL != "" {
			v.Emails = []vcard.Email{{Address: r.EMAIL}}
		}

		addphone(&v, r.WORK_FAX, "fax", "work")
		addphone(&v, r.PHONE_WORK, "work")
		addphone(&v, r.PHONE_HOME, "home")
		addphone(&v, r.PHONE_MOBILE, "cell")
		addphone(&v, r.PHONE_PAGER, "pager")
		addphone(&v, r.PHONE_OTHER)
		addphone(&v, r.PHONE_MOBILE2, "cell")

		switch len(r.NAME) {
		case 2:
			v.FamilyNames = []string{r.NAME[1]}
			v.FormattedName = " " + r.NAME[1]
			fallthrough
		case 1:
			v.GivenNames = []string{r.NAME[0]}
			v.FormattedName = r.NAME[0] + v.FormattedName
		}

		if r.COMPANY != "" {
			v.Org = []string{r.COMPANY}
		}

		v.Title = r.TITLE
		v.Note = r.NOTES
		v.Birthday = r.BIRTHDAY

		if r.ANNIVERSARY != "" {
			if v.Note != "" {
				v.Note += "\n"
			}
			v.Note += "Anniversary: " + r.ANNIVERSARY
		}

		if r.WORK_ADDRESS1+
			r.WORK_ADDRESS2+
			r.WORK_CITY+
			r.WORK_POSTCODE != "" {
			v.Addresses = append(v.Addresses, vcard.Address{
				Type:            []string{"work"},
				Street:          r.WORK_ADDRESS1,
				ExtendedAddress: r.WORK_ADDRESS2,
				Locality:        r.WORK_CITY,
				PostalCode:      r.WORK_POSTCODE,
			})
		}
		if r.HOME_ADDRESS1+
			r.HOME_CITY+
			r.HOME_POSTCODE+
			r.HOME_COUNTRY != "" {
			v.Addresses = append(v.Addresses, vcard.Address{
				Type:        []string{"home"},
				Street:      r.HOME_ADDRESS1,
				Locality:    r.HOME_CITY,
				PostalCode:  r.HOME_POSTCODE,
				CountryName: r.HOME_COUNTRY,
			})
		}

		book.Contacts = append(book.Contacts, v)
	}

	book.WriteTo(vcard.NewDirectoryInfoWriter(os.Stdout))
}
