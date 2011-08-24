<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			      xmlns:bb="http://darkircop.org/bb"
			      exclude-result-prefixes="bb">

  <xsl:template match="//record[cid/text()='WAPPushConfig']/appdata/field[@type='7']">
  	<unknown datatype="str">
		<xsl:attribute name="type">
			<xsl:value-of select="@type" />
		</xsl:attribute>

		<xsl:value-of select="bb:hex2str(text())" />
	</unknown>
  </xsl:template>

  <xsl:template match="//record[cid/text()='WPTCP']/appdata/field[@type='1' or @type='8' or @type='4' or @type='19']">
  	<unknown datatype="str">
		<xsl:attribute name="type">
			<xsl:value-of select="@type" />
		</xsl:attribute>

		<xsl:value-of select="bb:hex2str(text())" />
	</unknown>
  </xsl:template>

  <xsl:template match="//record[cid/text()='BrowserConfig']/appdata/field[@type='1' or @type='3' or @type='4' or @type='56' or @type='24' or @type='42' or @type='11' or @type='60' or @type='54']">
  	<unknown datatype="str">
		<xsl:attribute name="type">
			<xsl:value-of select="@type" />
		</xsl:attribute>

		<xsl:value-of select="bb:hex2str(text())" />
	</unknown>
  </xsl:template>

  <xsl:template match="//record[cid/text()='BrowserConfig']/appdata/field[@type='139']">
  	<unknown datatype="str" skip="1">
		<xsl:attribute name="type">
			<xsl:value-of select="@type" />
		</xsl:attribute>

		<xsl:value-of select="bb:hex2str(text(), 1)" />
	</unknown>
  </xsl:template>

  <xsl:template match="//record[cid/text()='CMIME']/appdata/field[@type='16']">
  	<unknown datatype="str">
		<xsl:attribute name="type">
			<xsl:value-of select="@type" />
		</xsl:attribute>

		<xsl:value-of select="bb:hex2str(text())" />
	</unknown>
  </xsl:template>

  <xsl:template match="//record[cid/text()='CMIME']/appdata/field[@type='128']">
  	<unknown datatype="str">
		<xsl:attribute name="type">
			<xsl:value-of select="@type" />
		</xsl:attribute>

		<xsl:value-of select="bb:hex2str(text(), 1)" />
	</unknown>
  </xsl:template>

  <xsl:template match="//record[cid/text()='MDS']/appdata/field[@type='3']">
  	<unknown datatype="str">
		<xsl:attribute name="type">
			<xsl:value-of select="@type" />
		</xsl:attribute>

		<xsl:value-of select="bb:hex2str(text())" />
	</unknown>
  </xsl:template>

  <xsl:template match="//record[cid/text()='OTASL']/appdata/field[@type='3' or @type='2']">
  	<unknown datatype="str">
		<xsl:attribute name="type">
			<xsl:value-of select="@type" />
		</xsl:attribute>

		<xsl:value-of select="bb:hex2str(text())" />
	</unknown>
  </xsl:template>

  <xsl:template match="@*|node()">
  	<xsl:copy>
		<xsl:apply-templates select="@*|node()" />
	</xsl:copy>
  </xsl:template>

</xsl:stylesheet>
