<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			      xmlns:bb="http://darkircop.org/bb"
			      exclude-result-prefixes="bb">

  <xsl:template match="//hrt/field[@type='1']">
  	<username><xsl:value-of select="bb:hex2str(text())" /></username>
  </xsl:template>

  <xsl:template match="//hrt/field[@type='2']">
  	<password><xsl:value-of select="bb:hex2str(text())" /></password>
  </xsl:template>

  <xsl:template match="//hrt/field[@type='9']">
  	<name><xsl:value-of select="bb:hex2str(text())" /></name>
  </xsl:template>

  <xsl:template match="//hrt/field[@type='6']">
  	<npc><xsl:value-of select="bb:hex2le32(text(), 16)" /></npc>
  </xsl:template>

  <xsl:template match="//hrt/field[@type='3']">
  	<apn><xsl:value-of select="bb:hex2str(text())" /></apn>
  </xsl:template>

  <xsl:template match="//hrt/field[@type='16']">
  	<ip><xsl:value-of select="bb:hex2ip(text())" /></ip>
  </xsl:template>

  <xsl:template match="//hrt/field[@type='17']">
  	<ports><xsl:value-of select="bb:hex2ports(text())" /></ports>
  </xsl:template>

  <xsl:template match="@*|node()">
  	<xsl:copy>
		<xsl:apply-templates select="@*|node()" />
	</xsl:copy>
  </xsl:template>

</xsl:stylesheet>
