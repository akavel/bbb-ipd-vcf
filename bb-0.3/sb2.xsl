<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			      xmlns:bb="http://darkircop.org/bb"
			      exclude-result-prefixes="bb">

  <xsl:template match="//record/server/field[@type='21']">
  	<address><xsl:value-of select="bb:hex2str(text())" /></address>
  </xsl:template>

  <xsl:template match="//record/server/field[@type='20']">
  	<port><xsl:value-of select="bb:hex2le32(text())" /></port>
  </xsl:template>

  <xsl:template match="@*|node()">
  	<xsl:copy>
		<xsl:apply-templates select="@*|node()" />
	</xsl:copy>
  </xsl:template>

</xsl:stylesheet>
