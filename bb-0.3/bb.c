#ifdef WINDOWS
#include <windows.h>
#include <winsock.h>
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <err.h>
#endif /* ! WINDOWS */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xpathInternals.h>
#include <libxslt/xslt.h>
#include <libxslt/xsltInternals.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>
#include <libxslt/extensions.h>

#define VERSION "0.3"

#ifdef WINDOWS
static void err(int code, char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	printf(" %s\n", strerror(errno));
	exit(code);
}

static void errx(int code, char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	printf("\n");
	exit(code);
	
}

#define htole32(x) (x)
#define htole16(x) (x)
#define le16toh(x) (x)
#define le32toh(x) (x)
#define htobe16(x) htons(x)
#define be16toh(x) ntohs(x)
#endif

#define NS_BB "http://darkircop.org/bb"

#define DEFAULT_ZEROLEN (2 + 1)

#define __packed __attribute__((packed))

/* http://na.blackberry.com/eng/devjournals/resources/journals/jan_2006/ipd_file_format.jsp */
static const char IH_MAGIC[] = "Inter@ctive Pager Backup/Restore File\n";

struct ipd_hdr {
	char		ih_magic[sizeof(IH_MAGIC) - 1];
	uint8_t		ih_ver;
	uint16_t	ih_numdb; /* BE */
	uint8_t		ih_namesep; /* 0x00 */
} __packed;

struct ipd_name {
	uint16_t	in_len; /* LE */
	char		in_name[0];
} __packed;

struct ipd_field {
	uint16_t	if_len;
	uint8_t		if_type;
	uint8_t		if_data[0];
} __packed;

struct ipd_record {
	uint8_t			ir_ver;
	uint16_t		ir_rhandle;
	uint32_t		ir_ruid;
	struct ipd_field	ir_fields[0];
} __packed;

struct ipd_data {
	uint16_t		id_dbid;
	uint32_t		id_rlen;
	struct ipd_record	id_record;
} __packed;

#define FIELD_TYPE		 2
#define FIELD_NAME		 3
#define FIELD_DSID		 5
#define FIELD_USERID		 6
#define FIELD_UID		 7
#define FIELD_CID		 8
#define FIELD_APPDATA		 9
#define FIELD_COMPRESSION	10
#define FIELD_ENCRYPTION	11
#define FIELD_DESCRIPTION	15
#define FIELD_SOURCE		17
#define FIELD_HRT		22
#define FIELD_RUID		23

static struct state {
	FILE		*s_in;
	FILE		*s_out;
	int		s_numdb;
	int		s_ver;
	int		s_be;
	int		s_zerolen;
	xmlDocPtr	s_doc;
	xmlNodePtr	s_db[256];
	char		*s_xsl[256];
	int		s_handle;
} _s;

struct buf {
	void	*b_data;
	int	b_len;
};

static void *alloc_buf(struct buf *buf, int len)
{
	if (buf->b_len >= len)
		return buf->b_data;

	buf->b_len  = len;
	buf->b_data = realloc(buf->b_data, buf->b_len);

	if (!buf->b_data)
		err(1, "realloc()");

	return buf->b_data;
}

static void hexdump(void *p, int len)
{
	unsigned char *x = p;
	int did = 0;

	while (len--) {
		printf("%.2X ", *x++);
		if (did++ >= 16) {
			printf("\n");
			did = 0;
		}
	}

	if (did != 0)
		printf("\n");
}

static void readx(FILE *f, void *buf, int len)
{
	int rd = fread(buf, 1, len, f);

	if (rd == -1)
		err(1, "read()");

	if (rd != len)
		errx(1, "readx %d/%d", rd, len);
}

static void writex(FILE *f, void *buf, int len)
{
	int rd = fwrite(buf, 1, len, f);

	if (rd == -1)
		err(1, "write()");

	if (rd != len)
		errx(1, "writex()");
}

static void add_int_prop(xmlNodePtr node, char *label, int num)
{
	char tmp[16];

	snprintf(tmp, sizeof(tmp), "%d", num);
	xmlNewProp(node, BAD_CAST label, BAD_CAST tmp);
}

static int get_int_prop(xmlNodePtr node, char *label)
{
	char *val = (char*) xmlGetNoNsProp(node, BAD_CAST label);

	if (!val)
		errx(1, "can't get attribute %s", label);

	return atoi(val);
}

static void parse_header(void)
{
	struct ipd_hdr hdr;
        xmlNodePtr head;

	readx(_s.s_in, &hdr, sizeof(hdr));

	if (strncmp(hdr.ih_magic, IH_MAGIC, sizeof(IH_MAGIC) - 1) != 0)
		errx(1, "bad magic");

	if (hdr.ih_ver != 2)
		errx(1, "vad version");

	/* XXX what about 0 dbs? */
	if (hdr.ih_namesep != 0)
		errx(1, "bad sep");

	_s.s_numdb = be16toh(hdr.ih_numdb);
	_s.s_ver   = hdr.ih_ver;
#if 0
	head = xmlNewChild(xmlDocGetRootElement(_s.s_doc), 
			   NULL, BAD_CAST "header", NULL);

	hdr.ih_magic[sizeof(IH_MAGIC) - 2] = 0;
	xmlNewChild(head, NULL, BAD_CAST "magic", BAD_CAST hdr.ih_magic);
#endif
	head = xmlDocGetRootElement(_s.s_doc);
	add_int_prop(head, "version", hdr.ih_ver);
}

static void parse_db_name(unsigned int num)
{
	struct ipd_name name;
	char n[1024];
	int len;

	readx(_s.s_in, &name, sizeof(name));

	len = le16toh(name.in_len);
	assert(len < sizeof(n));

	readx(_s.s_in, n, len);

	printf("Name %d [%s]\n", num, n);

	assert(num < (sizeof(_s.s_db) / sizeof(*_s.s_db)));
	assert(_s.s_db[num] == 0);

	_s.s_db[num] = xmlNewChild(xmlDocGetRootElement(_s.s_doc), 
			   	   NULL, BAD_CAST "database", NULL);

	xmlNewProp(_s.s_db[num], BAD_CAST "name", BAD_CAST n);
}

static void print_label(char *label, char *data, int len)
{
	printf("%s", label);
	fflush(stdout);
	write(1, data, len);
	printf("\n");
}

static int parse_db_field(void *data, int len, xmlNodePtr record)
{
	struct ipd_field *field = data;
	int totlen;
	uint32_t num;
	xmlNodePtr fieldn;
	static char hex[131072];

	assert(len >= sizeof(*field));

	field->if_len = _s.s_be ? be16toh(field->if_len) 
				: le16toh(field->if_len);

	printf("LEN [%d]\n", field->if_len);

	totlen = (sizeof(*field) + field->if_len);
	assert(len >= totlen);

	hex[0] = 0;
	for (num = 0; num < field->if_len; num++)
		snprintf(&hex[num * 2], 3, "%.2x", field->if_data[num]);

	fieldn = xmlNewChild(record, NULL, BAD_CAST "field", BAD_CAST hex);

	if (field->if_len == 0 && _s.s_zerolen == 2)
		return _s.s_zerolen;

	add_int_prop(fieldn, "type", field->if_type);

	if (field->if_len == 0)
		return _s.s_zerolen;

	if (field->if_len >= sizeof(num))
		num = le32toh(*((int32_t*) field->if_data));

	switch (field->if_type) {
	case FIELD_SOURCE:
		printf("Source: ");
		switch (*((uint8_t*) field->if_data)) {
		case 0:
			printf("Unkown\n");
			break;

		case 1:
			printf("Serial\n");
			break;

		case 2:
			printf("OTA\n");
			break;

		case 3:
		case 4:
			printf("Code\n");
			break;

		case 5:
			printf("Editor\n");
			break;

		default:
			printf("%d\n", *((uint8_t*) field->if_data));
			break;
		}
		break;

	case FIELD_TYPE:
		do {
			const char *types[] = { "Active",
					        "Pending",
					        "Ghost",
					        "Obsolete",
					        "Unknown",
					        "Orphan",
					        "Disallowed"
					       };

			const char *x = "Unkown";
			uint32_t num = le32toh(*((uint32_t*) field->if_data));

			if (num < (sizeof(types) / sizeof(*types)))
				x = types[num];

			printf("Type: %s\n", x);
		} while (0);
		break;

	case FIELD_UID:
		print_label("UID: ", (char*) field->if_data, field->if_len);
		break;

	case FIELD_CID:
		print_label("CID: ", (char*) field->if_data, field->if_len);
		break;

	case FIELD_NAME:
		printf("Name: %s\n", field->if_data);
		break;

	case FIELD_DSID:
		printf("DSID: %s\n", field->if_data);
		break;

	case FIELD_DESCRIPTION:
		printf("Description: %s\n", field->if_data);
		break;

	case FIELD_RUID:
		printf("RUID: %x\n", le32toh(*((uint32_t*) field->if_data)));
		break;

	case FIELD_USERID:
		printf("User ID: %d\n", le32toh(*((int32_t*) field->if_data)));
		break;

	case FIELD_COMPRESSION:
		printf("Compression: %d\n", num == 2 ? 1 : 0);
		break;

	case FIELD_ENCRYPTION:
		/* Flags: 0x02 RIM Encryption.  0x04 RIM (BIS) Encryption. */
		printf("Encryption:");
		if (num & 0x02)
			printf(" RIM");

		if (num & 0x04)
			printf(" BIS");

		if (num & 0x01)
			printf(" none");

		printf("\n");
		break;

	case FIELD_APPDATA:
		printf("App data\n");
		hexdump(field->if_data, field->if_len);
		break;

	case FIELD_HRT:
		printf("HRT\n");
		hexdump(field->if_data, field->if_len);
		break;

	default:
		printf("Field type %d len %d\n", field->if_type, field->if_len);
		hexdump(field->if_data, field->if_len);
		break;
	}

	return totlen;
}

static void parse_db_fields(void *data, int len, xmlNodePtr record)
{
	int did;
	unsigned char *p = data;

	while (len > 0) {
		did  = parse_db_field(p, len, record);
		p   += did;
		len -= did;
	}

	assert(len == 0);
}

static int parse_db_data()
{
	static struct buf buf = { NULL, 0 };
	struct ipd_data dh;
	unsigned char *p, *data;
	int len;
	int rc;
	xmlNodePtr record;
	char tmp[16];

	rc = fread(&dh, 1, sizeof(dh), _s.s_in);
	if (rc == -1)
		err(1, "read()");

	if (rc == 0)
		return 0;

	if (rc != sizeof(dh))
		errx(1, "readx()");

	dh.id_dbid    		= le16toh(dh.id_dbid);
	dh.id_rlen    		= le32toh(dh.id_rlen);
	dh.id_record.ir_ruid    = le32toh(dh.id_record.ir_ruid);
	dh.id_record.ir_rhandle = le16toh(dh.id_record.ir_rhandle);

	printf("Data [%d] rlen %u ver %d handle %d id %x\n",
	       dh.id_dbid,
	       dh.id_rlen,
	       dh.id_record.ir_ver,
	       dh.id_record.ir_rhandle,
	       dh.id_record.ir_ruid);

	len = dh.id_rlen;
	assert(len >= sizeof(dh.id_record));
	len -= sizeof(dh.id_record); /* i think this format sux */

	data = p = alloc_buf(&buf, len);

	readx(_s.s_in, data, len);

	assert(dh.id_dbid < (sizeof(_s.s_db) / sizeof(*_s.s_db)));
	assert(_s.s_db[dh.id_dbid]);
	record = xmlNewChild(_s.s_db[dh.id_dbid], NULL, BAD_CAST "record",
			     NULL);

	if (dh.id_record.ir_ver != _s.s_ver)
		add_int_prop(record, "version", dh.id_record.ir_ver);

	if (dh.id_record.ir_rhandle != _s.s_handle)
		add_int_prop(record, "handle", dh.id_record.ir_rhandle);

	snprintf(tmp, sizeof(tmp), "0x%x", dh.id_record.ir_ruid);
	xmlNewProp(record, BAD_CAST "uid", BAD_CAST tmp);

	parse_db_fields(p, len, record);

	_s.s_handle++;

	return 1;
}

static void write_header(void)
{
	xmlNodePtr root;
	struct ipd_hdr hdr;

	root = xmlDocGetRootElement(_s.s_doc);

	_s.s_numdb = xmlChildElementCount(root);
	_s.s_ver   = get_int_prop(root, "version");

	printf("Db ver %d num %d\n", _s.s_ver, _s.s_numdb);

	memset(&hdr, 0, sizeof(hdr));
	memcpy(hdr.ih_magic, IH_MAGIC, sizeof(hdr.ih_magic));

	hdr.ih_ver     = _s.s_ver;
	hdr.ih_numdb   = htobe16(_s.s_numdb);
	hdr.ih_namesep = 0;

	writex(_s.s_out, &hdr, sizeof(hdr));
}

static void write_db_name(xmlNodePtr db)
{
	char *name = (char*) xmlGetNoNsProp(db, BAD_CAST "name");
	int len = strlen(name);
	struct ipd_name n;

	printf("DB %s\n", name);

	n.in_len = htole16(len + 1);
	writex(_s.s_out, &n, sizeof(n));
	writex(_s.s_out, name, len + 1);
}

static int hex2bin(char *hex, void *out, int max)
{
	int i;
	char tmp[3];
	int tmp2;
	int len;
	unsigned char *x = out;

	len = strlen(hex);
	assert((len % 2) == 0);
	len /= 2;

	if (len > max)
		errx(1, "too much stuff");

	for (i = 0; i < len; i++) {
		tmp[0] = hex[0];
		tmp[1] = hex[1];
		tmp[2] = 0;

		if (sscanf(tmp, "%x", &tmp2) != 1)
			errx(1, "parse error");

		*x++ = (uint8_t) tmp2;

		hex += 2;
	}

	return len;
}

static int write_field(xmlNodePtr field, uint8_t *data, int len)
{
	int totlen = 0;
	int type   = get_int_prop(field, "type");
	char *hex  = (char*) xmlNodeGetContent(field);
	struct ipd_field *f = (struct ipd_field*) data;

	totlen = hex2bin(hex, f->if_data, len - sizeof(*f));

	printf("Field type %d len %d\n", type, totlen);

	f->if_len  = htole16(totlen);
	f->if_type = type;

	totlen += sizeof(*f);

	return totlen;
}

static void write_record(xmlNodePtr record, int dbid)
{
	static uint8_t data[409600];
	unsigned char *p = data;
	xmlNodePtr field;
	int len = sizeof(data), did;
	struct ipd_data ipd;
	uint32_t uid;
	char *uida;
	int ver = _s.s_ver;
	int handle = _s.s_handle++;

	uida = (char*) xmlGetNoNsProp(record, BAD_CAST "uid");
	if (sscanf(uida, "%x", &uid) != 1)
		errx(1, "error parsing uid");

	if ((uida = (char*) xmlGetNoNsProp(record, BAD_CAST "version")))
		ver = atoi(uida);

	if ((uida = (char*) xmlGetNoNsProp(record, BAD_CAST "handle")))
		handle = atoi(uida);

	printf("Record DBID %d handle %d uid %x ver %d\n",
	       dbid, handle, uid, ver);

	for (field = record->children; field; field = field->next) {
		if (field->type != XML_ELEMENT_NODE)
			continue;

		did = write_field(field, p, len);
		len -= did;
		p   += did;
		assert(len > 0);
	}

	did = p - data;
	assert(did <= sizeof(data));

	memset(&ipd, 0, sizeof(ipd));
	ipd.id_dbid	         = htole16(dbid);
	ipd.id_rlen	         = htole32(sizeof(ipd.id_record) + did);
	ipd.id_record.ir_ver     = ver;
	ipd.id_record.ir_rhandle = htole16(handle);
	ipd.id_record.ir_ruid    = htole32(uid);

	writex(_s.s_out, &ipd, sizeof(ipd));
	writex(_s.s_out, data, did);
}

static void write_db_data(xmlNodePtr db, int id)
{
	xmlNodePtr record;

	printf("Data for db %d\n", id);
	for (record = db->children; record; record = record->next) {
		if (record->type != XML_ELEMENT_NODE)
			continue;

		write_record(record, id);
	}
}

static xmlXPathObjectPtr xsl_str_param(xmlXPathParserContextPtr ctx, int nargs)
{
	xmlXPathObjectPtr obj;

	if (nargs < 1)
		errx(1, "need arg");

	obj = valuePop(ctx);

	if (obj->type != XPATH_STRING) {
		valuePush(ctx, obj);
		xmlXPathStringFunction(ctx, 1);
		obj = valuePop(ctx);
	}

	return obj;
}

static int get_int_arg(xmlXPathParserContextPtr ctx, int nargs)
{
	int ret;
	xmlXPathObjectPtr obj;

	obj = xsl_str_param(ctx, nargs);
	assert(obj->type == XPATH_STRING);

	ret = atoi((char*) obj->stringval);
	xmlXPathFreeObject(obj);

	return ret;
}

static void xsl_hex2str(xmlXPathParserContextPtr ctx, int nargs)
{
	xmlXPathObjectPtr obj;
	static char bin[1024];
	int len;
	int skip = 0;

	if (nargs > 1)
		skip = get_int_arg(ctx, nargs);

	obj = xsl_str_param(ctx, nargs);

	len = hex2bin((char*) obj->stringval, bin, sizeof(bin) - 1);
	bin[len] = 0;

	xmlXPathFreeObject(obj);

	obj = xmlXPathNewCString(bin + skip);
	valuePush(ctx, obj);
}

static void do_hex2field(xmlXPathParserContextPtr ctx, int nargs, int skip)
{
	xmlXPathObjectPtr obj;
	static unsigned char bin[102400];
	int len;
	xmlNodePtr record, field;

	if (nargs > 2)
		_s.s_zerolen = get_int_arg(ctx, nargs);

	if (nargs > 1)
		skip = get_int_arg(ctx, nargs);

	obj = xsl_str_param(ctx, nargs);

	len = hex2bin((char*) obj->stringval, bin, sizeof(bin));

	xmlXPathFreeObject(obj);

	obj = NULL;

	assert(len - skip >= 0);

	record = xmlNewNode(NULL, BAD_CAST "record");
	parse_db_fields(bin + skip, len - skip, record);

	for (field = record->children; field; field = field->next) {
		if (field->type != XML_ELEMENT_NODE)
			continue;

		if (obj == NULL)
			obj = xmlXPathNewNodeSet(field);
		else
			xmlXPathNodeSetAdd(obj->nodesetval, field);
	}

	/* XXX record is leaked */

	valuePush(ctx, obj);

	_s.s_zerolen = DEFAULT_ZEROLEN;
}

static void xsl_hex2field(xmlXPathParserContextPtr ctx, int nargs)
{
	do_hex2field(ctx, nargs, 0);
}

static void xsl_hex2befield(xmlXPathParserContextPtr ctx, int nargs)
{
	_s.s_be = 1;
	do_hex2field(ctx, nargs, 1);
	_s.s_be = 0;
}

static void xsl_hex2le(xmlXPathParserContextPtr ctx, int nargs, int bytes)
{
	uint32_t bla = 0;
	int len;
	int base = 10;
	xmlXPathObjectPtr obj;
	char tmp[16];
	char *fmt = "%d";

	if (nargs == 2) {
		obj = xsl_str_param(ctx, nargs);
		assert(obj->type == XPATH_STRING);

		base = atoi((char*) obj->stringval);
		xmlXPathFreeObject(obj);
	}

	obj = xsl_str_param(ctx, nargs);

	assert(sizeof(bla) >= bytes);
	len = hex2bin((char*) obj->stringval, &bla, bytes);
	assert(len == bytes);

	bla = le32toh(bla);

	xmlXPathFreeObject(obj);

	if (base == 16)
		fmt = "0x%x";

	snprintf(tmp, sizeof(tmp), fmt, bla);
	valuePush(ctx, xmlXPathNewCString(tmp));
}

static void xsl_hex2le32(xmlXPathParserContextPtr ctx, int nargs)
{
	xsl_hex2le(ctx, nargs, 4);
}

static void xsl_hex2le8(xmlXPathParserContextPtr ctx, int nargs)
{
	xsl_hex2le(ctx, nargs, 1);
}

static void xsl_hex2ip(xmlXPathParserContextPtr ctx, int nargs)
{
	struct in_addr ip;
	xmlXPathObjectPtr obj;
	int len;

	obj = xsl_str_param(ctx, nargs);

	len = hex2bin((char*) obj->stringval, &ip, sizeof(ip));
	assert(len == sizeof(ip));

	xmlXPathFreeObject(obj);

	valuePush(ctx, xmlXPathNewCString(inet_ntoa(ip)));
}

static void xsl_get_stuff(xmlXPathParserContextPtr ctx, int nargs,
			  void *stuff, int len)
{
	xmlXPathObjectPtr obj;
	int x;

	obj = xsl_str_param(ctx, nargs);

	x = hex2bin((char*) obj->stringval, stuff, len);
	assert(x == len);
	xmlXPathFreeObject(obj);
}

static void xsl_hex2ports(xmlXPathParserContextPtr ctx, int nargs)
{
	unsigned char stuff[4];
	uint16_t *porta = (uint16_t*) stuff;
	uint16_t *portb = porta + 1;
	char buf[64];

	xsl_get_stuff(ctx, nargs, stuff, sizeof(stuff));

	*porta = ntohs(*porta);
	*portb = ntohs(*portb);

	snprintf(buf, sizeof(buf), "%d:%d", *porta, *portb);

	valuePush(ctx, xmlXPathNewCString(buf));
}

static void xsl_hex2apptype(xmlXPathParserContextPtr ctx, int nargs)
{
	xmlXPathObjectPtr obj = xsl_str_param(ctx, nargs);
	char tmp[3];
	char *p = (char*) obj->stringval;
	int x;

	printf("p %s\n", p);
	assert(strlen(p) >= 2);

	tmp[0] = p[0];
	tmp[1] = p[1];
	tmp[2] = 0;

	sscanf(tmp, "%x", &x);

	xmlXPathFreeObject(obj);

	valuePush(ctx, xmlXPathNewFloat(x));
}

static void xsl_hex2tlv(xmlXPathParserContextPtr ctx, int nargs)
{
	xmlXPathObjectPtr obj, objr = NULL;
	static unsigned char bin[4096];
	unsigned char tmp[1024];
	int len;
	xmlNodePtr field;
	unsigned char *p = bin;
	char *hex;
	int skip = 1;

	if (nargs == 2) {
		obj = xsl_str_param(ctx, nargs);
		assert(obj->type == XPATH_STRING);

		skip = atoi((char*) obj->stringval);
		xmlXPathFreeObject(obj);
	}

	obj = xsl_str_param(ctx, nargs);
	hex = (char*) (obj->stringval);

	len = hex2bin(hex, bin, sizeof(bin));

	hex += 2 * skip;
	p   += skip;
	len -= skip;

	while (len > 0) {
		int t, l;

		field = xmlNewNode(NULL, BAD_CAST "field");

		assert(len >= 1);

		t = *p++;
		len--;
		hex += 2;

		/* XXX ??? */
		if (t == 0)
			goto __next;

		assert(len >= 1);

		l = *p++;
		len--;

		hex += 2;
		assert(sizeof(tmp) > (l * 2));
		memcpy(tmp, hex, l * 2);
		tmp[l * 2] = 0;

		p += l;
		hex += l * 2;
		len -= l;

		add_int_prop(field, "type", t);
		xmlNodeAddContent(field, BAD_CAST tmp);

__next:
		if (objr == NULL)
			objr = xmlXPathNewNodeSet(field);
		else
			xmlXPathNodeSetAdd(objr->nodesetval, field);

	}
	assert(len == 0);

	/* XXX leaks */
	xmlXPathFreeObject(obj);

	valuePush(ctx, objr);
}

static void do_xsl(char *xsl)
{
	xsltTransformContextPtr ctx;
	xsltStylesheetPtr style;
	xmlDocPtr doc;
	const char *params[] = { NULL };

	xmlKeepBlanksDefault(0);

	assert(_s.s_doc);

	style = xsltParseStylesheetFile((const xmlChar *) xsl);
	doc   = _s.s_doc;
	ctx   = xsltNewTransformContext(style, doc);

	/* XXX use array */
	xsltRegisterExtFunction(ctx, BAD_CAST "hex2str",
				BAD_CAST NS_BB, xsl_hex2str);

	xsltRegisterExtFunction(ctx, BAD_CAST "hex2le32",
				BAD_CAST NS_BB, xsl_hex2le32);

	xsltRegisterExtFunction(ctx, BAD_CAST "hex2le8",
				BAD_CAST NS_BB, xsl_hex2le8);

	xsltRegisterExtFunction(ctx, BAD_CAST "hex2field",
				BAD_CAST NS_BB, xsl_hex2field);

	xsltRegisterExtFunction(ctx, BAD_CAST "hex2befield",
				BAD_CAST NS_BB, xsl_hex2befield);

	xsltRegisterExtFunction(ctx, BAD_CAST "hex2ip",
				BAD_CAST NS_BB, xsl_hex2ip);

	xsltRegisterExtFunction(ctx, BAD_CAST "hex2ports",
				BAD_CAST NS_BB, xsl_hex2ports);

	xsltRegisterExtFunction(ctx, BAD_CAST "hex2apptype",
				BAD_CAST NS_BB, xsl_hex2apptype);

	xsltRegisterExtFunction(ctx, BAD_CAST "hex2tlv",
				BAD_CAST NS_BB, xsl_hex2tlv);

	_s.s_doc = xsltApplyStylesheetUser(style, doc, params, NULL, NULL, ctx);

	xsltFreeStylesheet(style);
	xmlFreeDoc(doc);
	xsltFreeTransformContext(ctx);
	xsltCleanupGlobals();
	xmlCleanupParser();
}

static void do_xsls()
{
	int i;
	char *xsl;

	for (i = 0; (xsl = _s.s_xsl[i]) ; i++)
		do_xsl(xsl);
}

static xmlDocPtr get_xml(char *in)
{
	LIBXML_TEST_VERSION;

	xmlKeepBlanksDefault(0);
	_s.s_doc = xmlReadFile(in, NULL, 0);
	do_xsls();

	return _s.s_doc;
}

static void xml2ipd(char *inname, char *outname)
{

	int i, id;
	xmlDocPtr doc;
	xmlNodePtr root, db;

	doc = get_xml(inname);

	_s.s_out = fopen(outname, "wb");
	if (!_s.s_out)
		err(1, "open(%s)", outname);

	root = xmlDocGetRootElement(doc);

	write_header();

	_s.s_handle = 1;

	/* i don't think that having a separate index was such as good idea */
	for (i = 0; i < 2; i++) {
		for (db = root->children, id = 0; db; db = db->next) {
			if (db->type != XML_ELEMENT_NODE)
				continue;

			if (i == 0)
				write_db_name(db);
			else
				write_db_data(db, id++);
		}
	}

	fclose(_s.s_out);

	xmlFreeDoc(doc);
	xmlCleanupParser();
}

static void put_xml(char *name)
{
	xmlKeepBlanksDefault(0);
	xmlSaveFormatFileEnc(name, _s.s_doc, "UTF-8", 1);
	xmlFreeDoc(_s.s_doc);
	xmlCleanupParser();
}

static void ipd2xml(char *inname, char *outname)
{
	int i;
	xmlNodePtr root;

	LIBXML_TEST_VERSION;

	if (!(_s.s_in = fopen(inname, "rb")))
		err(1, "open(%s)", inname);

	_s.s_doc = xmlNewDoc(BAD_CAST "1.0");
	root = xmlNewNode(NULL, BAD_CAST "ipd");
	xmlDocSetRootElement(_s.s_doc, root);

	parse_header();

	printf("%d dbs\n", _s.s_numdb);

	for (i = 0; i < _s.s_numdb; i++)
		parse_db_name(i);

	_s.s_handle = 1;
	while (parse_db_data());

	fclose(_s.s_in);

	do_xsls();

	put_xml(outname);
}

static void xml2xml(char *in, char *out)
{
	xmlDocPtr doc;

	doc = get_xml(in);

	put_xml(out);
}

static void usage(char *argv)
{
	printf("Usage: %s <opts>\n"
	       "-h\thelp\n"
	       "-i\t<input file>\n"
	       "-o\t<output file>\n"
	       "-x\t<xsl file>\n"
	       "-v\tversion\n"
	       , argv);
	exit(1);
}

int main(int argc, char *argv[])
{
	char *in = NULL, *out = NULL;
	char *ext, *extout;
	int ch;
	int xsl = 0;

	memset(&_s, 0, sizeof(_s));

	_s.s_zerolen = DEFAULT_ZEROLEN;

	while ((ch = getopt(argc, argv, "hi:o:x:v")) != -1) {
		switch (ch) {
		case 'v':
			printf("%s\n", VERSION);
			exit(0);
			break;

		case 'i':
			in = optarg;
			break;

		case 'o':
			out = optarg;
			break;

		case 'x':
			assert(xsl < (sizeof(_s.s_xsl) / sizeof(*_s.s_xsl)));
			_s.s_xsl[xsl++] = optarg;
			break;

		default:
		case 'h':
			usage(argv[0]);
			exit(1);
		}
	}

	if (!in || !out)
		errx(1, "specify in/out file");

	ext    = in + strlen(in) - 3;
	extout = out + strlen(out) - 3;

	if (ext < in || extout < out)
		errx(1, "need extensions");

	if (strcasecmp(ext, "ipd") == 0)
		ipd2xml(in, out);
	else if (strcasecmp(ext, "xml") == 0) {
		if (strcasecmp(extout, "xml") == 0)
			xml2xml(in, out);
		else
			xml2ipd(in, out);
	} else
		errx(1, "unknown extension %s", ext);

	exit(0);
}
