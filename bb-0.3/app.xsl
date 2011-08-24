<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			      xmlns:bb="http://darkircop.org/bb"
			      exclude-result-prefixes="bb">

  <xsl:template match="//record[cid/text()='BrowserConfig']/appdata">
  	<appdata>
		<xsl:attribute name="type">
			<xsl:value-of select="bb:hex2apptype(text())" />
		</xsl:attribute>

		<xsl:copy-of select="bb:hex2befield(text())" />
	</appdata>
  </xsl:template>

  <xsl:template match="//record[cid/text()='WAPPushConfig']/appdata">
  	<appdata>
		<xsl:attribute name="type">
			<xsl:value-of select="bb:hex2apptype(text())" />
		</xsl:attribute>

		<xsl:copy-of select="bb:hex2befield(text())" />
	</appdata>
  </xsl:template>

  <xsl:template match="//record[cid/text()='CICAL']/appdata">
  	<appdata>
		<xsl:attribute name="type">
			<xsl:value-of select="bb:hex2apptype(text())" />
		</xsl:attribute>

		<xsl:copy-of select="bb:hex2befield(text(), 1, 2)" />
	</appdata>
  </xsl:template>

  <xsl:template match="//record[cid/text()='WPTCP' or cid/text()='SYNC' or cid/text()='CMIME']/appdata">
  	<appdata>
		<xsl:attribute name="type">
			<xsl:value-of select="bb:hex2apptype(text())" />
		</xsl:attribute>

		<xsl:copy-of select="bb:hex2tlv(text())" />
	</appdata>
  </xsl:template>

  <xsl:template match="//record[cid/text()='BBIM']/appdata">
  	<appdata>
		<xsl:copy-of select="bb:hex2tlv(text(), 0)" />
	</appdata>
  </xsl:template>

  <xsl:template match="//record[cid/text()='MDS' or cid/text()='IPPP']/appdata">
  	<appdata>
		<xsl:copy-of select="bb:hex2befield(text(), 0)" />
	</appdata>
  </xsl:template>

  <xsl:template match="//record[cid/text()='OTASL']/appdata">
  	<appdata>
		<xsl:copy-of select="bb:hex2tlv(text(), 0)" />
	</appdata>
  </xsl:template>

  <xsl:template match="@*|node()">
  	<xsl:copy>
		<xsl:apply-templates select="@*|node()" />
	</xsl:copy>
  </xsl:template>

</xsl:stylesheet>
